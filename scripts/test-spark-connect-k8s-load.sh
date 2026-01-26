#!/usr/bin/env bash
set -euo pipefail

# Runtime load test for Spark Connect with K8s executors backend
# Tests Connect-only mode under configurable load

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-connect-k8s}"

# Load parameters (configurable via env)
LOAD_MODE="${LOAD_MODE:-range}"             # Mode: range or parquet
LOAD_ROWS="${LOAD_ROWS:-1000000}"          # Rows per DataFrame operation (for range mode)
LOAD_PARTITIONS="${LOAD_PARTITIONS:-50}"   # Partitions for data operations
LOAD_ITERATIONS="${LOAD_ITERATIONS:-3}"   # Number of iterations
LOAD_EXECUTORS="${LOAD_EXECUTORS:-3}"     # Number of executors to request
LOAD_DATASET="${LOAD_DATASET:-nyc}"        # Dataset for parquet mode (nyc, trips, nyt)
LOAD_S3_ENDPOINT="${LOAD_S3_ENDPOINT:-http://minio:9000}"

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${RELEASE}"

PF_PIDS=()

cleanup() {
  for pid in "${PF_PIDS[@]:-}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}

trap cleanup EXIT

echo "=== Spark Connect K8s Executors Load Test (${RELEASE} in ${NAMESPACE}) ==="
echo "Load parameters:"
echo "  Rows: ${LOAD_ROWS}"
echo "  Partitions: ${LOAD_PARTITIONS}"
echo "  Iterations: ${LOAD_ITERATIONS}"
echo "  Executors: ${LOAD_EXECUTORS}"

echo ""
echo "1) Checking Spark Connect pod..."
kubectl wait --for=condition=ready pod \
  -l "${CONNECT_SELECTOR}" \
  -n "${NAMESPACE}" \
  --timeout=180s

CONNECT_POD="$(kubectl get pod -n "${NAMESPACE}" -l "${CONNECT_SELECTOR}" -o jsonpath='{.items[0].metadata.name}')"
echo "   Connect pod: ${CONNECT_POD}"

CONNECT_SERVICE="$(kubectl get svc -n "${NAMESPACE}" -l "${CONNECT_SELECTOR}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${CONNECT_SERVICE}" ]]; then
  if kubectl get svc spark-connect -n "${NAMESPACE}" >/dev/null 2>&1; then
    CONNECT_SERVICE="spark-connect"
  else
    echo "   ERROR: Spark Connect service not found for release '${RELEASE}' in namespace '${NAMESPACE}'"
    exit 1
  fi
fi
echo "   Connect service: ${CONNECT_SERVICE}"

echo ""
echo "2) Setting up port-forward to Spark Connect..."
kubectl port-forward "svc/${CONNECT_SERVICE}" 15002:15002 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 5

echo ""
echo "3) Running load test (mode=${LOAD_MODE}, iterations=${LOAD_ITERATIONS})..."

python3 <<EOF
import os
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum

load_mode = os.environ.get("LOAD_MODE", "range")

builder = SparkSession.builder \\
    .appName("ConnectK8sLoadTest") \\
    .remote("sc://localhost:15002") \\
    .config("spark.executor.instances", os.environ.get("LOAD_EXECUTORS", "3"))

# Configure S3 for parquet mode
if load_mode == "parquet":
    builder = builder \\
        .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("LOAD_S3_ENDPOINT", "http://minio:9000")) \\
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

spark = builder.getOrCreate()
print("✓ Spark Connect session created")

if load_mode == "parquet":
    # Parquet mode: read from S3
    dataset = os.environ.get("LOAD_DATASET", "nyc")
    path = f"s3a://test-data/{dataset}/"
    print(f"Loading parquet from: {path}")

    start = time.time()
    df = spark.read.parquet(path)
    load_time = time.time() - start
    count = df.count()
    print(f"  Loaded {count:,} records in {load_time:.2f}s")
    df.cache()
    df.count()  # Force cache

    for i in range(int(os.environ.get("LOAD_ITERATIONS", "3"))):
        print(f"\\nIteration {i+1}/{os.environ.get('LOAD_ITERATIONS', '3')}...")

        # Simple aggregation
        start = time.time()
        if "passenger_count" in df.columns:
            result = df.agg({"passenger_count": "avg"}).collect()[0][0]
        else:
            result = df.count()
        agg_time = time.time() - start
        print(f"  Aggregation: {agg_time:.2f}s")

        # Filter
        start = time.time()
        if "passenger_count" in df.columns:
            filtered = df.filter(col("passenger_count") > 1).count()
        else:
            filtered = df.filter(col(df.columns[0]).isNotNull()).count()
        filter_time = time.time() - start
        print(f"  Filter: {filter_time:.2f}s (count={filtered:,})")

else:
    # Range mode: synthetic data
    for i in range(int(os.environ.get("LOAD_ITERATIONS", "3"))):
        print(f"\\nIteration {i+1}/{os.environ.get('LOAD_ITERATIONS', '3')}...")

        start = time.time()
        df = spark.range(int(os.environ.get("LOAD_ROWS", "1000000"))).repartition(int(os.environ.get("LOAD_PARTITIONS", "50")))
        create_time = time.time() - start
        print(f"  Created DataFrame: {create_time:.2f}s")

        start = time.time()
        result = df.agg(spark_sum(col("id"))).collect()[0][0]
        agg_time = time.time() - start
        expected = int(os.environ.get("LOAD_ROWS", "1000000")) * (int(os.environ.get("LOAD_ROWS", "1000000")) - 1) // 2
        assert result == expected, f"Sum mismatch: {result} != {expected}"
        print(f"  Aggregation: {agg_time:.2f}s (sum={result})")

        start = time.time()
        filtered = df.filter(col("id") % 2 == 0).count()
        filter_time = time.time() - start
        assert filtered == int(os.environ.get("LOAD_ROWS", "1000000")) // 2
        print(f"  Filter+Count: {filter_time:.2f}s")

print("\\n✓ All load test iterations passed")
spark.stop()
EOF

if [[ $? -eq 0 ]]; then
    echo ""
    echo "4) Checking executor pods were created..."
    EXECUTOR_PODS=$(kubectl get pods -n "${NAMESPACE}" -l "spark-role=executor" --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "${EXECUTOR_PODS}" -gt 0 ]]; then
        echo "   ✓ Found ${EXECUTOR_PODS} executor pod(s)"
    else
        echo "   WARN: No executor pods found (may be using dynamic allocation)"
    fi
    
    echo ""
    echo "=== Load Test PASSED ==="
    exit 0
else
    echo ""
    echo "=== Load Test FAILED ==="
    exit 1
fi
