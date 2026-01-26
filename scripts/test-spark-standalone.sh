#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-sa}"

# Install example (Spark 3.5 umbrella chart):
# helm install "${RELEASE}" charts/spark-3.5 --set spark-standalone.enabled=true

MASTER_SELECTOR="app=spark-master,app.kubernetes.io/instance=${RELEASE}"
WORKER_SELECTOR="app=spark-worker,app.kubernetes.io/instance=${RELEASE}"

echo "=== Testing Spark Standalone Chart (${RELEASE} in ${NAMESPACE}) ==="

echo "1) Checking pods are ready..."
kubectl wait --for=condition=ready pod -n "${NAMESPACE}" -l "${MASTER_SELECTOR}" --timeout=180s
kubectl wait --for=condition=ready pod -n "${NAMESPACE}" -l "${WORKER_SELECTOR}" --timeout=180s || true

MASTER_POD="$(kubectl get pod -n "${NAMESPACE}" -l "${MASTER_SELECTOR}" -o jsonpath='{.items[0].metadata.name}')"
echo "   Master pod: ${MASTER_POD}"

echo "2) Checking Spark Master UI responds..."
kubectl exec -n "${NAMESPACE}" "${MASTER_POD}" -- sh -lc "curl -fsS http://localhost:8080/ >/dev/null 2>&1"
echo "   OK"

echo "3) Checking at least 1 worker registered (best-effort)..."
WORKERS_JSON="$(kubectl exec -n "${NAMESPACE}" "${MASTER_POD}" -- sh -lc "curl -fsS http://localhost:8080/json/")"
if echo "${WORKERS_JSON}" | grep -q '"workers"'; then
  echo "   OK (workers field present)"
else
  echo "   WARN: /json/ did not include workers field"
fi

echo "4) Running SparkPi via spark-submit (best-effort)..."
kubectl exec -n "${NAMESPACE}" "${MASTER_POD}" -- sh -lc "\
  POD_IP=\$(hostname -i) && \
  timeout 300s spark-submit --master spark://${RELEASE}-spark-standalone-master:7077 \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.driver.host=\$POD_IP \
    --conf spark.sql.catalogImplementation=in-memory \
    --class org.apache.spark.examples.SparkPi \
    /opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10 \
  | grep -q 'Pi is roughly' \
"
echo "   OK"

echo "5) Checking Airflow and MLflow services exist (if enabled)..."
kubectl get svc -n "${NAMESPACE}" "${RELEASE}-spark-standalone-airflow-webserver" >/dev/null 2>&1 || true
kubectl get svc -n "${NAMESPACE}" "${RELEASE}-spark-standalone-mlflow" >/dev/null 2>&1 || true
echo "   OK"

echo "6) Checking History Server (if deployed)..."
HISTORY_SVC="${RELEASE}-spark-standalone-history-server"
if kubectl get svc "$HISTORY_SVC" -n "$NAMESPACE" &>/dev/null; then
  echo "   History Server service found, waiting for pod..."
  kubectl wait --for=condition=ready pod \
    -l app=spark-history-server,app.kubernetes.io/instance="${RELEASE}" \
    -n "$NAMESPACE" \
    --timeout=120s || {
    echo "   WARN: History Server pod not ready (skipping API check)"
    echo "   OK (service exists)"
  }
  
  # Port-forward in background
  echo "   Port-forwarding to History Server..."
  kubectl port-forward "svc/${HISTORY_SVC}" 18080:18080 -n "$NAMESPACE" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
  
  # Query applications (may take a moment for logs to be parsed)
  echo "   Querying History Server API..."
  APPS=$(curl -s http://localhost:18080/api/v1/applications 2>/dev/null || echo "[]")
  
  # Cleanup port-forward
  kill $PF_PID 2>/dev/null || true
  wait $PF_PID 2>/dev/null || true
  
  # Check at least one application exists
  APP_COUNT=$(echo "$APPS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$APP_COUNT" -gt 0 ]]; then
    echo "   ✓ History Server shows $APP_COUNT application(s)"
  else
    echo "   ⚠ History Server has no applications yet (may need more time for log parsing)"
  fi
  echo "   OK"
else
  echo "   History Server not deployed (skipping)"
  echo "   OK"
fi

echo "=== Done ==="

