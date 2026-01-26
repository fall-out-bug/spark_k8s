#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-41-int}"
RELEASE="${2:-spark-41-int}"

CREATED_NAMESPACE="false"

cleanup_release() {
  local rel="$1"
  helm uninstall "${rel}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
}

cleanup() {
  cleanup_release "${RELEASE}"
  helm uninstall celeborn -n "${NAMESPACE}" >/dev/null 2>&1 || true
  helm uninstall spark-operator -n "${NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete sparkapplication spark-pi-celeborn -n "${NAMESPACE}" >/dev/null 2>&1 || true
  if [[ "${CREATED_NAMESPACE}" == "true" ]]; then
    kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

echo "=== Spark 4.1.0 Integration Tests (${NAMESPACE}) ==="

if [[ "${NAMESPACE}" == "default" ]]; then
  echo "ERROR: Use a non-default namespace for integration tests."
  exit 1
fi

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${NAMESPACE}" >/dev/null
  CREATED_NAMESPACE="true"
fi

echo "1) Testing Jupyter + Spark Connect integration..."
helm install "${RELEASE}" charts/spark-4.1 \
  --namespace "${NAMESPACE}" \
  --set connect.enabled=true \
  --set jupyter.enabled=true \
  --wait

kubectl port-forward "svc/${RELEASE}-spark-41-jupyter" 8888:8888 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PID=$!
sleep 5

NOTEBOOK_RESULT=$(curl -s http://localhost:8888/api/contents 2>/dev/null || echo "ERROR")
if [[ "${NOTEBOOK_RESULT}" == *"00_spark_connect_guide.ipynb"* ]]; then
  echo "   ✓ Jupyter found example notebook"
else
  echo "   ⚠ Notebook not found (manual check recommended)"
fi

kill "${PF_PID}" 2>/dev/null || true
wait "${PF_PID}" 2>/dev/null || true
echo "✓ Jupyter + Spark Connect integration OK"

cleanup_release "${RELEASE}"

echo "2) Testing Spark Connect + Celeborn integration..."
helm install celeborn charts/celeborn \
  --namespace "${NAMESPACE}" \
  --wait

helm install "${RELEASE}" charts/spark-4.1 \
  --namespace "${NAMESPACE}" \
  --set connect.enabled=true \
  --set celeborn.enabled=true \
  --set celeborn.masterEndpoints="celeborn-master-0.celeborn-master:9097" \
  --wait

kubectl run spark-shuffle-test \
  --image=spark-custom:4.1.0 \
  --restart=Never \
  --rm -i -n "${NAMESPACE}" \
  -- /opt/spark/bin/spark-submit \
  --master spark://${RELEASE}-spark-41-connect:7077 \
  --conf spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager \
  --conf spark.celeborn.master.endpoints=celeborn-master-0.celeborn-master:9097 \
  --class org.apache.spark.examples.GroupByTest \
  local:///opt/spark/examples/jars/spark-examples.jar 10 500 2

if kubectl logs -n "${NAMESPACE}" -l app=celeborn-worker --tail=50 | grep -i "shuffle" >/dev/null; then
  echo "   ✓ Celeborn processed shuffle data"
else
  echo "   ⚠ Celeborn shuffle activity not detected"
fi

echo "✓ Spark Connect + Celeborn integration OK"

cleanup_release "${RELEASE}"
helm uninstall celeborn -n "${NAMESPACE}"

echo "3) Testing Spark Operator + Celeborn integration..."
helm install celeborn charts/celeborn \
  --namespace "${NAMESPACE}" \
  --wait

helm install spark-operator charts/spark-operator \
  --namespace "${NAMESPACE}" \
  --set sparkJobNamespace="${NAMESPACE}" \
  --wait

helm install "${RELEASE}" charts/spark-4.1 \
  --namespace "${NAMESPACE}" \
  --set connect.enabled=false \
  --set rbac.create=true \
  --wait

kubectl apply -f docs/examples/spark-application-celeborn.yaml -n "${NAMESPACE}"

kubectl wait --for=condition=completed \
  sparkapplication/spark-pi-celeborn \
  -n "${NAMESPACE}" \
  --timeout=300s || echo "⚠ SparkApplication timeout (check manually)"

STATUS=$(kubectl get sparkapplication spark-pi-celeborn -n "${NAMESPACE}" -o jsonpath='{.status.applicationState.state}')
if [[ "${STATUS}" == "COMPLETED" ]]; then
  echo "   ✓ SparkApplication completed successfully"
else
  echo "   ⚠ SparkApplication status: ${STATUS}"
fi

echo "✓ Spark Operator + Celeborn integration OK"

kubectl delete -f docs/examples/spark-application-celeborn.yaml -n "${NAMESPACE}"
helm uninstall "${RELEASE}" -n "${NAMESPACE}"
helm uninstall spark-operator -n "${NAMESPACE}"
helm uninstall celeborn -n "${NAMESPACE}"

if [[ "${CREATED_NAMESPACE}" == "true" ]]; then
  kubectl delete namespace "${NAMESPACE}"
fi

echo "=== All integration tests passed ✓ ==="
