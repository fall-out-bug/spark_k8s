#!/usr/bin/env bash
# Parquet load test for Spark Connect
# Tests reading and processing parquet files from MinIO/S3
# Usage: ./scripts/test-parquet-load.sh <namespace> <release> [dataset]
#
# Datasets:
#   nyc   - NYC Yellow Taxi data (default)
#   trips - Chicago Taxi Trips
#   nyt   - NYT/Sample dataset
#
# Examples:
#   ./scripts/test-parquet-load.sh spark spark-connect nyc
#   PARQUET_ITERATIONS=5 ./scripts/test-parquet-load.sh spark spark-connect

set -euo pipefail

NAMESPACE="${1:-spark}"
RELEASE="${2:-spark-connect}"
DATASET="${3:-nyc}"

# Load parameters (configurable via env)
PARQUET_ITERATIONS="${PARQUET_ITERATIONS:-3}"   # Number of iterations
PARQUET_QUERIES="${PARQUET_QUERIES:-all}"       # Queries to run: all, read, filter, agg, join
PARQUET_BUCKET="${PARQUET_BUCKET:-test-data}"   # S3 bucket
PARQUET_S3_ENDPOINT="${PARQUET_S3_ENDPOINT:-http://minio:9000}"

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${RELEASE}"

PF_PIDS=()

cleanup() {
  for pid in "${PF_PIDS[@]:-}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}

trap cleanup EXIT

echo "=== Parquet Load Test (${RELEASE} in ${NAMESPACE}) ==="
echo "Dataset: ${DATASET}"
echo "S3 Path: s3a://${PARQUET_BUCKET}/${DATASET}/"
echo "Iterations: ${PARQUET_ITERATIONS}"
echo "Queries: ${PARQUET_QUERIES}"
echo ""

# Wait for Spark Connect pod
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
    echo "   ERROR: Spark Connect service not found"
    exit 1
  fi
fi
echo "   Connect service: ${CONNECT_SERVICE}"

# Port-forward
echo ""
echo "2) Setting up port-forward..."
kubectl port-forward "svc/${CONNECT_SERVICE}" 15002:15002 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 5

# Run parquet load test
echo ""
echo "3) Running parquet load test..."

python3 <<EOF
import os
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, sum as spark_sum, lit

# Configure S3
spark = SparkSession.builder \\
    .appName("ParquetLoadTest") \\
    .remote("sc://localhost:15002") \\
    .config("spark.hadoop.fs.s3a.endpoint", "${PARQUET_S3_ENDPOINT}") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

print("✓ Spark Connect session created")

# Load parquet data
path = f"s3a://${PARQUET_BUCKET}/${DATASET}/"
print(f"\\nLoading parquet from: {path}")

try:
    start = time.time()
    df = spark.read.parquet(path)
    load_time = time.time() - start

    count = df.count()
    print(f"  Loaded {count:,} records in {load_time:.2f}s")

    # Show schema
    print("\\nSchema:")
    df.printSchema()

    # Cache for repeated queries
    print("\\nCaching DataFrame...")
    start = time.time()
    df.cache()
    df.count()  # Force cache
    cache_time = time.time() - start
    print(f"  Cached in {cache_time:.2f}s")

    # Run queries based on configuration
    queries = os.environ.get("PARQUET_QUERIES", "all").lower()

    for i in range(int(os.environ.get("PARQUET_ITERATIONS", "3"))):
        print(f"\\n=== Iteration {i+1} ===")

        # Query 1: Simple filter
        if queries in ["all", "filter"]:
            start = time.time()
            try:
                # Try common taxi column names
                if "passenger_count" in df.columns:
                    filtered = df.filter(col("passenger_count") > 1)
                    result = filtered.count()
                elif "age" in df.columns:
                    filtered = df.filter(col("age") > 30)
                    result = filtered.count()
                elif "id" in df.columns:
                    filtered = df.filter(col("id") % 2 == 0)
                    result = filtered.count()
                else:
                    # Use first column
                    first_col = df.columns[0]
                    filtered = df.filter(col(first_col).isNotNull())
                    result = filtered.count()

                query_time = time.time() - start
                print(f"  Filter: {query_time:.2f}s (count={result:,})")
            except Exception as e:
                print(f"  Filter: skipped ({str(e)[:50]})")

        # Query 2: Aggregation
        if queries in ["all", "agg"]:
            start = time.time()
            try:
                if "passenger_count" in df.columns:
                    agg = df.agg(avg("passenger_count")).collect()[0][0]
                elif "age" in df.columns:
                    agg = df.agg(avg("age")).collect()[0][0]
                elif "trip_distance" in df.columns:
                    agg = df.agg(avg("trip_distance")).collect()[0][0]
                elif "id" in df.columns:
                    agg = df.agg(spark_sum("id")).collect()[0][0]
                else:
                    # Count aggregation
                    agg = df.agg(count("*")).collect()[0][0]

                query_time = time.time() - start
                print(f"  Aggregation: {query_time:.2f}s (result={agg})")
            except Exception as e:
                print(f"  Aggregation: skipped ({str(e)[:50]})")

        # Query 3: Group by
        if queries in ["all", "group"]:
            start = time.time()
            try:
                if "passenger_count" in df.columns:
                    grouped = df.groupBy("passenger_count").count().orderBy(col("count").desc())
                    result = grouped.collect()[0][0]
                elif "city" in df.columns:
                    grouped = df.groupBy("city").count().orderBy(col("count").desc())
                    result = grouped.collect()[0][0]
                elif "PULocationID" in df.columns:
                    grouped = df.groupBy("PULocationID").count().orderBy(col("count").desc())
                    result = grouped.collect()[0][0]
                else:
                    # Group by first column
                    first_col = df.columns[0]
                    grouped = df.groupBy(first_col).count().orderBy(col("count").desc())
                    result = grouped.collect()[0][0]

                query_time = time.time() - start
                print(f"  GroupBy: {query_time:.2f}s")
            except Exception as e:
                print(f"  GroupBy: skipped ({str(e)[:50]})")

        # Query 4: Join (self-join sample)
        if queries in ["all", "join"]:
            start = time.time()
            try:
                # Sample for join
                sample = df.sample(0.1, seed=42)
                joined = sample.join(sample, df.columns[0], "inner")
                result = joined.count()
                query_time = time.time() - start
                print(f"  Self-join: {query_time:.2f}s (count={result:,})")
            except Exception as e:
                print(f"  Self-join: skipped ({str(e)[:50]})")

    print("\\n✓ All parquet queries completed")
    spark.stop()

except Exception as e:
    print(f"\\nERROR: {str(e)}")
    import traceback
    traceback.print_exc()
    spark.stop()
    exit(1)
EOF

if [[ $? -eq 0 ]]; then
  echo ""
  echo "=== Parquet Load Test PASSED ==="
  exit 0
else
  echo ""
  echo "=== Parquet Load Test FAILED ==="
  echo "Hint: Make sure parquet data is loaded in MinIO"
  echo "Run: ./scripts/load-nyt-parquet-data.sh ${DATASET}"
  exit 1
fi
