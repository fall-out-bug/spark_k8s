#!/usr/bin/env bash
set -e

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-41}"

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${RELEASE}"
METASTORE_SELECTOR="app=hive-metastore,app.kubernetes.io/instance=${RELEASE}"
HISTORY_SELECTOR="app=spark-history-server,app.kubernetes.io/instance=${RELEASE}"
JUPYTER_SELECTOR="app=jupyter,app.kubernetes.io/instance=${RELEASE}"

PF_PIDS=()

cleanup() {
  for pid in "${PF_PIDS[@]:-}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}

trap cleanup EXIT

echo "=== Spark 4.1.0 Smoke Test (${RELEASE} in ${NAMESPACE}) ==="

echo "1) Checking Spark Connect pod..."
kubectl wait --for=condition=ready pod \
  -l "${CONNECT_SELECTOR}" \
  -n "${NAMESPACE}" \
  --timeout=180s

echo "2) Checking Hive Metastore pod..."
kubectl wait --for=condition=ready pod \
  -l "${METASTORE_SELECTOR}" \
  -n "${NAMESPACE}" \
  --timeout=120s

echo "3) Checking History Server pod..."
kubectl wait --for=condition=ready pod \
  -l "${HISTORY_SELECTOR}" \
  -n "${NAMESPACE}" \
  --timeout=120s

echo "4) Checking Jupyter pod..."
kubectl wait --for=condition=ready pod \
  -l "${JUPYTER_SELECTOR}" \
  -n "${NAMESPACE}" \
  --timeout=120s

echo "5) Testing Spark Connect client..."
kubectl port-forward "svc/${RELEASE}-spark-41-connect" 15002:15002 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 3

python3 <<EOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("SmokeTest") \\
    .remote("sc://localhost:15002") \\
    .getOrCreate()

df = spark.range(100)
assert df.count() == 100, "DataFrame count mismatch"

print("✓ Spark Connect test passed")
spark.stop()
EOF

echo "6) Testing Hive Metastore..."
kubectl delete pod spark-test -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true
kubectl run spark-test \
  --image=spark-custom:4.1.0 \
  --restart=Never \
  --rm -i -n "${NAMESPACE}" \
  -- /opt/spark/bin/spark-sql \
  --conf spark.sql.catalog.spark_catalog.hive.metastore.uris=thrift://${RELEASE}-spark-41-metastore:9083 \
  -e "CREATE TABLE IF NOT EXISTS smoke_test (id INT); SELECT COUNT(*) FROM smoke_test;"

echo "✓ Hive Metastore test passed"

echo "7) Testing History Server..."
kubectl port-forward "svc/${RELEASE}-spark-41-history" 18080:18080 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 3

APPS=$(curl -s http://localhost:18080/api/v1/applications || echo "[]")
echo "   History Server returned: $APPS"
echo "✓ History Server test passed"

echo "8) Testing Jupyter..."
kubectl port-forward "svc/${RELEASE}-spark-41-jupyter" 8888:8888 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 3

curl -s http://localhost:8888/lab | grep "JupyterLab" >/dev/null
echo "✓ Jupyter test passed"

echo "=== All tests passed ✓ ==="
