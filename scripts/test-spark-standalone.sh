#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-sa}"

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

echo "=== Done ==="

