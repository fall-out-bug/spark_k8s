#!/bin/bash
# Load Test Template for Lego-Spark
# Parameterized template for test matrix scenarios
#
# Required Environment Variables:
#   SPARK_VERSION    - Spark version (3.5.7, 3.5.8, 4.0.2, 4.1.1)
#   PLATFORM         - Platform (k8s, openshift)
#   DEPLOYMENT_MODE  - Deployment mode (native, standalone)
#   CONNECT_ENABLED  - Spark Connect enabled (true, false)
#
# Optional Environment Variables:
#   GPU_ENABLED      - GPU support (true, false)
#   ICEBERG_ENABLED  - Iceberg support (true, false)
#   SHUFFLE_ENABLED  - Shuffle Service (true, false)
#   OPENLINEAGE_ENABLED - OpenLineage tracking (true, false)
#   K8S_NAMESPACE    - Kubernetes namespace (default: spark-test)
#   HELM_RELEASE     - Helm release name (default: spark-scenario)
#   TEST_TIMEOUT     - Test timeout in seconds (default: 300)
#   DATA_SIZE        - Data size for load tests (default: 100000)
#   PARTITIONS       - Number of partitions (default: 10)

set -euo pipefail

# === Configuration ===
SPARK_VERSION="${SPARK_VERSION:-3.5.7}"
PLATFORM="${PLATFORM:-k8s}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-standalone}"
CONNECT_ENABLED="${CONNECT_ENABLED:-false}"
GPU_ENABLED="${GPU_ENABLED:-false}"
ICEBERG_ENABLED="${ICEBERG_ENABLED:-false}"
SHUFFLE_ENABLED="${SHUFFLE_ENABLED:-false}"
OPENLINEAGE_ENABLED="${OPENLINEAGE_ENABLED:-false}"
NAMESPACE="${K8S_NAMESPACE:-spark-test}"
RELEASE="${HELM_RELEASE:-spark-scenario}"
TIMEOUT="${TEST_TIMEOUT:-300}"
DATA_SIZE="${DATA_SIZE:-100000}"
PARTITIONS="${PARTITIONS:-10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"
SCENARIO_ID="load-${SPARK_VERSION}-${PLATFORM}-${DEPLOYMENT_MODE}-connect-${CONNECT_ENABLED}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/load-test-$SCENARIO_ID-$TIMESTAMP.csv"

mkdir -p "$RESULTS_DIR"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Counters ===
PASSED=0
FAILED=0
SKIPPED=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++)) || true
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++)) || true
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

get_master_service() {
    if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
        echo "${RELEASE}-standalone-master"
    else
        echo "${RELEASE}-spark-connect"
    fi
}

get_master_pod() {
    if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
        kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
    else
        kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-connect' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
    fi
}

run_load_test() {
    local test_name="$1"
    local script="$2"
    local data_size="${3:-$DATA_SIZE}"
    local partitions="${4:-$PARTITIONS}"
    local timeout="${5:-$TIMEOUT}"

    log_info "Running load test: $test_name (rows=$data_size, partitions=$partitions)"

    local MASTER_POD=$(get_master_pod)

    if [[ -z "$MASTER_POD" ]]; then
        log_skip "$test_name (no spark pod)"
        echo "$SCENARIO_ID,$test_name,$data_size,$partitions,0,0,0,SKIP" >> "$RESULTS_FILE"
        return 0
    fi

    kubectl cp "$script" $NAMESPACE/$MASTER_POD:/tmp/load-test.py 2>/dev/null

    local master_url="local[*]"
    if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
        master_url="spark://$(get_master_service):7077"
    fi

    local start_time=$(date +%s%3N)

    local output
    output=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c 'DRIVER_HOST=$(hostname -i) && timeout '$timeout' spark-submit --master '$master_url' --conf spark.driver.host=$DRIVER_HOST --conf spark.driver.bindAddress=0.0.0.0 --conf spark.sql.shuffle.partitions='$partitions' /tmp/load-test.py '$data_size' '$partitions 2>&1) || true

    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    local status="FAIL"
    local throughput="0"
    local rows_per_sec="0"

    if echo "$output" | grep -q "LOAD_TEST_SUCCESS"; then
        status="PASS"
        rows_per_sec=$(echo "$data_size * 1000 / $duration" | bc 2>/dev/null || echo "0")
        throughput=$(echo "$rows_per_sec" | awk '{printf "%.2f", $1 / 1024}')
        log_pass "$test_name completed in ${duration}ms (${rows_per_sec} rows/s)"
    else
        log_fail "$test_name failed"
        echo "$output" >> "$RESULTS_DIR/${test_name}-$SCENARIO_ID.log"
    fi

    echo "$SCENARIO_ID,$test_name,$data_size,$partitions,$duration,$throughput,$rows_per_sec,$status" >> "$RESULTS_FILE"
}

# Initialize CSV header
echo "scenario,test,data_size,partitions,duration_ms,throughput_mb_s,rows_per_sec,status" > "$RESULTS_FILE"

# === Header ===
echo "=============================================="
echo "LOAD TEST - Scenario: $SCENARIO_ID"
echo "=============================================="
echo "Spark Version:    $SPARK_VERSION"
echo "Platform:         $PLATFORM"
echo "Deployment Mode:  $DEPLOYMENT_MODE"
echo "Connect:          $CONNECT_ENABLED"
echo "GPU:              $GPU_ENABLED"
echo "Iceberg:          $ICEBERG_ENABLED"
echo "Shuffle Service:  $SHUFFLE_ENABLED"
echo "OpenLineage:      $OPENLINEAGE_ENABLED"
echo "Namespace:        $NAMESPACE"
echo "Release:          $RELEASE"
echo "Data Size:        $DATA_SIZE"
echo "Partitions:       $PARTITIONS"
echo "Time:             $(date)"
echo ""

MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
    echo "Error: Spark pod not found"
    exit 1
fi

log_info "Spark pod: $MASTER_POD"

MASTER_URL="local[*]"
if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
    MASTER_URL="spark://$(get_master_service):7077"
fi

# === 1. THROUGHPUT TEST ===
log_info "=== 1. THROUGHPUT TEST ==="

cat > /tmp/load-throughput-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum, avg, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-Throughput") \
    .master("$MASTER_URL") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .getOrCreate()

import time
start = time.time()

df = spark.range(data_size).withColumn("group", col("id") % 100)
df = df.withColumn("value", rand() * 1000)

result = df.groupBy("group").agg(
    count("*").alias("count"),
    spark_sum("value").alias("sum"),
    avg("value").alias("avg")
).count()

duration = time.time() - start
throughput = data_size / duration

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

run_load_test "throughput-simple" /tmp/load-throughput-$SCENARIO_ID.py $DATA_SIZE $PARTITIONS $TIMEOUT

# === 2. SHUFFLE TEST ===
log_info "=== 2. SHUFFLE TEST ==="

cat > /tmp/load-shuffle-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 20

spark = SparkSession.builder \
    .appName("Load-Shuffle") \
    .master("$MASTER_URL") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .getOrCreate()

import time
start = time.time()

df1 = spark.range(data_size).withColumn("key", col("id") % (data_size // 10))
df2 = spark.range(data_size // 2).withColumn("key", col("id") % (data_size // 10))

result = df1.join(df2, "key").groupBy((col("key") % 100).alias("bucket")).count().count()

duration = time.time() - start
throughput = data_size / duration

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows shuffled in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

run_load_test "shuffle-test" /tmp/load-shuffle-$SCENARIO_ID.py $DATA_SIZE $((PARTITIONS * 2)) $TIMEOUT

# === 3. SORT TEST ===
log_info "=== 3. SORT TEST ==="

cat > /tmp/load-sort-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-Sort") \
    .master("$MASTER_URL") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .getOrCreate()

import time
start = time.time()

df = spark.range(data_size).withColumn("rand", rand())
sorted_df = df.orderBy("rand")

count = sorted_df.count()

duration = time.time() - start
throughput = data_size / duration

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows sorted in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

run_load_test "sort-test" /tmp/load-sort-$SCENARIO_ID.py $DATA_SIZE $PARTITIONS $TIMEOUT

# === 4. CACHE TEST ===
log_info "=== 4. CACHE TEST ==="

cat > /tmp/load-cache-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
iterations = int(sys.argv[2]) if len(sys.argv) > 2 else 5

spark = SparkSession.builder \
    .appName("Load-Cache") \
    .master("$MASTER_URL") \
    .getOrCreate()

import time
start = time.time()

df = spark.range(data_size).withColumn("group", col("id") % 100)
df.cache()

for i in range(iterations):
    df.groupBy("group").count().count()

duration = time.time() - start
df.unpersist()

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows x {iterations} iterations in {duration:.2f}s")
PYEOF

run_load_test "cache-test" /tmp/load-cache-$SCENARIO_ID.py $DATA_SIZE 5 $TIMEOUT

# === 5. WRITE TEST ===
log_info "=== 5. WRITE TEST ==="

cat > /tmp/load-write-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand
import sys
import shutil

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-Write") \
    .master("$MASTER_URL") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .getOrCreate()

df = spark.range(data_size).withColumn("value", rand() * 1000)
df = df.withColumn("partition", col("id") % 10)

import time
start = time.time()

df.write.mode("overwrite").partitionBy("partition").parquet("/tmp/load-test-output")

duration = time.time() - start
throughput = data_size / duration

shutil.rmtree("/tmp/load-test-output", ignore_errors=True)

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows written in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

run_load_test "write-parquet" /tmp/load-write-$SCENARIO_ID.py $DATA_SIZE $PARTITIONS $TIMEOUT

# === 6. ML TRAINING TEST ===
log_info "=== 6. ML TRAINING TEST ==="

cat > /tmp/load-ml-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.classification import LogisticRegression
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

spark = SparkSession.builder \
    .appName("Load-ML") \
    .master("$MASTER_URL") \
    .getOrCreate()

from pyspark.sql.functions import col
df = spark.range(data_size).select(
    col("id").alias("feature1"),
    (col("id") * 2).alias("feature2"),
    (col("id") * 3).alias("feature3"),
    (col("id") % 2).alias("label")
)

assembler = VectorAssembler(
    inputCols=["feature1", "feature2", "feature3"],
    outputCol="features"
)
data = assembler.transform(df)

import time
start = time.time()

lr = LogisticRegression(maxIter=10)
model = lr.fit(data)

duration = time.time() - start

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows trained in {duration:.2f}s")
PYEOF

run_load_test "ml-training" /tmp/load-ml-$SCENARIO_ID.py $((DATA_SIZE / 10)) $PARTITIONS $TIMEOUT

# === 7. GPU LOAD TEST (if enabled) ===
if [[ "$GPU_ENABLED" == "true" ]]; then
    log_info "=== 7. GPU LOAD TEST ==="

    cat > /tmp/load-gpu-$SCENARIO_ID.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-GPU") \
    .master("$MASTER_URL") \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .getOrCreate()

import time
start = time.time()

df = spark.range(data_size).withColumn("value", rand() * 1000)
result = df.groupBy((col("id") % 100).alias("bucket")).count().count()

duration = time.time() - start
throughput = data_size / duration

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows on GPU in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

    run_load_test "gpu-throughput" /tmp/load-gpu-$SCENARIO_ID.py $DATA_SIZE $PARTITIONS $TIMEOUT
fi

# === 8. ICEBERG LOAD TEST (if enabled) ===
if [[ "$ICEBERG_ENABLED" == "true" ]]; then
    log_info "=== 8. ICEBERG LOAD TEST ==="

    MINIO_SVC=$(kubectl get svc -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$MINIO_SVC" ]]; then
        cat > /tmp/load-iceberg-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

spark = SparkSession.builder \\
    .appName("Load-Iceberg") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.my_catalog", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.my_catalog.type", "hadoop") \\
    .config("spark.sql.catalog.my_catalog.warehouse", "s3a://warehouse/") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_SVC}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

import time
start = time.time()

# Create table
spark.sql("CREATE DATABASE IF NOT EXISTS my_catalog.load_test")
spark.sql("DROP TABLE IF EXISTS my_catalog.load_test.load_table")
spark.sql("CREATE TABLE my_catalog.load_test.load_table (id LONG, value DOUBLE) USING iceberg")

# Write data
df = spark.range(data_size).withColumn("value", col("id") * 1.5)
df.writeTo("my_catalog.load_test.load_table").append()

# Read and process
result = spark.sql("SELECT COUNT(*) as cnt FROM my_catalog.load_test.load_table").collect()[0]["cnt"]

duration = time.time() - start
throughput = data_size / duration

spark.stop()
print(f"LOAD_TEST_SUCCESS: {result} Iceberg rows in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

        run_load_test "iceberg-write-read" /tmp/load-iceberg-$SCENARIO_ID.py $((DATA_SIZE / 10)) $PARTITIONS $TIMEOUT
    else
        log_skip "iceberg-load (MinIO not deployed)"
    fi
fi

# === Cleanup ===
rm -f /tmp/load-*-$SCENARIO_ID.py

# === Summary ===
echo ""
echo "=============================================="
echo "LOAD TEST SUMMARY - $SCENARIO_ID"
echo "=============================================="
cat "$RESULTS_FILE" | column -t -s ','
echo ""

echo "Results saved to: $RESULTS_FILE"

PASSED=$(grep -c "PASS" "$RESULTS_FILE" || echo "0")
FAILED=$(grep -c "FAIL" "$RESULTS_FILE" || echo "0")

echo ""
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"

# Append to master results
cat "$RESULTS_FILE" >> "$RESULTS_DIR/load-history.csv"

if [[ $FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
