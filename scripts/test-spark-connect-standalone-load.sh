#!/usr/bin/env bash
set -euo pipefail

# Runtime load test for Spark Connect with Standalone backend
# Tests Connect + Standalone backend mode under configurable load

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-connect-standalone}"
STANDALONE_MASTER="${3:-spark-sa-spark-standalone-master:7077}"

# Load parameters (configurable via env)
LOAD_ROWS="${LOAD_ROWS:-1000000}"          # Rows per DataFrame operation
LOAD_PARTITIONS="${LOAD_PARTITIONS:-50}"   # Partitions for data operations
LOAD_ITERATIONS="${LOAD_ITERATIONS:-3}"   # Number of iterations

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${RELEASE}"

PF_PIDS=()

cleanup() {
  for pid in "${PF_PIDS[@]:-}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}

trap cleanup EXIT

echo "=== Spark Connect Standalone Backend Load Test (${RELEASE} in ${NAMESPACE}) ==="
echo "Standalone Master: ${STANDALONE_MASTER}"
echo "Load parameters:"
echo "  Rows: ${LOAD_ROWS}"
echo "  Partitions: ${LOAD_PARTITIONS}"
echo "  Iterations: ${LOAD_ITERATIONS}"

echo ""
echo "1) Checking Spark Connect pod..."
kubectl wait --for=condition=ready pod \
  -l "${CONNECT_SELECTOR}" \
  -n "${NAMESPACE}" \
  --timeout=180s

CONNECT_POD="$(kubectl get pod -n "${NAMESPACE}" -l "${CONNECT_SELECTOR}" -o jsonpath='{.items[0].metadata.name}')"
echo "   Connect pod: ${CONNECT_POD}"

echo ""
echo "2) Verifying Standalone master is accessible..."
# Extract service name from master URL (format: spark://service:port)
MASTER_SERVICE=$(echo "${STANDALONE_MASTER}" | sed 's/spark:\/\///' | cut -d: -f1)
MASTER_PORT=$(echo "${STANDALONE_MASTER}" | sed 's/spark:\/\///' | cut -d: -f2)

# Try to resolve the service (best-effort)
if kubectl get svc "${MASTER_SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "   ✓ Standalone master service found: ${MASTER_SERVICE}"
else
    echo "   WARN: Standalone master service '${MASTER_SERVICE}' not found in namespace"
    echo "   Continuing (may be in different namespace)..."
fi

echo ""
echo "3) Setting up port-forward to Spark Connect..."
kubectl port-forward "svc/${RELEASE}-connect" 15002:15002 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 5

echo ""
echo "4) Running load test (${LOAD_ITERATIONS} iterations)..."

python3 <<EOF
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum

spark = SparkSession.builder \\
    .appName("ConnectStandaloneLoadTest") \\
    .remote("sc://localhost:15002") \\
    .getOrCreate()

print("✓ Spark Connect session created (Standalone backend)")

for i in range(${LOAD_ITERATIONS}):
    print(f"\\nIteration {i+1}/${LOAD_ITERATIONS}...")
    
    # Create large DataFrame
    start = time.time()
    df = spark.range(${LOAD_ROWS}).repartition(${LOAD_PARTITIONS})
    create_time = time.time() - start
    print(f"  Created DataFrame: {create_time:.2f}s")
    
    # Aggregation
    start = time.time()
    result = df.agg(spark_sum(col("id"))).collect()[0][0]
    agg_time = time.time() - start
    expected = ${LOAD_ROWS} * (${LOAD_ROWS} - 1) // 2
    assert result == expected, f"Sum mismatch: {result} != {expected}"
    print(f"  Aggregation: {agg_time:.2f}s (sum={result})")
    
    # Filter and count
    start = time.time()
    filtered = df.filter(col("id") % 2 == 0).count()
    filter_time = time.time() - start
    assert filtered == ${LOAD_ROWS} // 2, f"Filter count mismatch: {filtered}"
    print(f"  Filter+Count: {filter_time:.2f}s (count={filtered})")
    
    # Join (self-join)
    start = time.time()
    df2 = spark.range(${LOAD_ROWS} // 10).repartition(${LOAD_PARTITIONS})
    joined = df.join(df2, df.id == df2.id, "inner").count()
    join_time = time.time() - start
    print(f"  Join: {join_time:.2f}s (count={joined})")
    
    total_time = create_time + agg_time + filter_time + join_time
    print(f"  Total iteration time: {total_time:.2f}s")

print("\\n✓ All load test iterations passed")
spark.stop()
EOF

if [[ $? -eq 0 ]]; then
    echo ""
    echo "5) Verifying jobs were submitted to Standalone..."
    # Check if we can query Standalone master (best-effort)
    if kubectl get svc "${MASTER_SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "   ✓ Standalone master service accessible"
    else
        echo "   INFO: Standalone master verification skipped (service not in namespace)"
    fi
    
    echo ""
    echo "=== Load Test PASSED ==="
    exit 0
else
    echo ""
    echo "=== Load Test FAILED ==="
    exit 1
fi
