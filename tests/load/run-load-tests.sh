#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/load-test-$TIMESTAMP.csv"

echo "timestamp,test,data_size,partitions,duration_ms,throughput_mb_s,rows_per_sec,status" > "$RESULTS_FILE"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l app=spark-standalone-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

run_load_test() {
    local test_name="$1"
    local script="$2"
    local data_size="${3:-1000000}"
    local partitions="${4:-10}"
    local timeout="${5:-300}"
    
    local MASTER_POD=$(get_master_pod)
    
    if [[ -z "$MASTER_POD" ]]; then
        log_fail "No master pod found"
        return 1
    fi
    
    log_info "Running load test: $test_name (rows=$data_size, partitions=$partitions)"
    
    kubectl cp "$script" $NAMESPACE/$MASTER_POD:/tmp/load-test.py 2>/dev/null
    
    local start_time=$(date +%s%3N)
    
    local output
    output=$(kubectl exec -n $NAMESPACE $MASTER_POD -- timeout $timeout spark-submit \
        --master spark://localhost:7077 \
        --conf spark.sql.shuffle.partitions=$partitions \
        /tmp/load-test.py 2>&1) || true
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    local status="FAIL"
    local throughput="0"
    local rows_per_sec="0"
    
    if echo "$output" | grep -q "LOAD_TEST_SUCCESS"; then
        status="PASS"
        rows_per_sec=$(echo "$data_size * 1000 / $duration" | bc 2>/dev/null || echo "0")
        log_pass "$test_name completed in ${duration}ms (${rows_per_sec} rows/s)"
    else
        log_fail "$test_name failed"
        echo "$output" >> "$RESULTS_DIR/${test_name}.log"
    fi
    
    echo "$TIMESTAMP,$test_name,$data_size,$partitions,$duration,0,$rows_per_sec,$status" >> "$RESULTS_FILE"
}

echo "=============================================="
echo "LOAD TESTS - Lego-Spark"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo "Release:   $RELEASE"
echo "Time:      $(date)"
echo ""

MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
    echo "Error: Spark master pod not found"
    exit 1
fi

log_info "Master pod: $MASTER_POD"

echo ""
log_info "=== 1. THROUGHPUT TEST - Simple Aggregation ==="

cat > /tmp/load-throughput.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum, avg, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 1000000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-Throughput") \
    .master("spark://localhost:7077") \
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

run_load_test "throughput-simple" /tmp/load-throughput.py 100000 10 120
run_load_test "throughput-medium" /tmp/load-throughput.py 500000 20 180
run_load_test "throughput-large" /tmp/load-throughput.py 1000000 50 300

echo ""
log_info "=== 2. SHUFFLE TEST - Heavy Join ==="

cat > /tmp/load-shuffle.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 20

spark = SparkSession.builder \
    .appName("Load-Shuffle") \
    .master("spark://localhost:7077") \
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

run_load_test "shuffle-small" /tmp/load-shuffle.py 10000 10 120
run_load_test "shuffle-medium" /tmp/load-shuffle.py 50000 20 180
run_load_test "shuffle-large" /tmp/load-shuffle.py 100000 50 300

echo ""
log_info "=== 3. SORT TEST - Large Sort ==="

cat > /tmp/load-sort.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-Sort") \
    .master("spark://localhost:7077") \
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

run_load_test "sort-small" /tmp/load-sort.py 10000 10 60
run_load_test "sort-medium" /tmp/load-sort.py 50000 20 120
run_load_test "sort-large" /tmp/load-sort.py 100000 50 180

echo ""
log_info "=== 4. CACHE TEST - Repeated Access ==="

cat > /tmp/load-cache.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
iterations = int(sys.argv[2]) if len(sys.argv) > 2 else 5

spark = SparkSession.builder \
    .appName("Load-Cache") \
    .master("spark://localhost:7077") \
    .getOrCreate()

import time

df = spark.range(data_size).withColumn("group", col("id") % 100)
df.cache()

start = time.time()

for i in range(iterations):
    df.groupBy("group").count().count()

duration = time.time() - start
df.unpersist()

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows x {iterations} iterations in {duration:.2f}s")
PYEOF

run_load_test "cache-test" /tmp/load-cache.py 100000 5 120

echo ""
log_info "=== 5. WRITE TEST - Parquet Write ==="

cat > /tmp/load-write.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 10

spark = SparkSession.builder \
    .appName("Load-Write") \
    .master("spark://localhost:7077") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .getOrCreate()

import time
import os

df = spark.range(data_size).withColumn("value", rand() * 1000)
df = df.withColumn("partition", col("id") % 10)

start = time.time()

df.write.mode("overwrite").partitionBy("partition").parquet("/tmp/load-test-output")

duration = time.time() - start
throughput = data_size / duration

import shutil
shutil.rmtree("/tmp/load-test-output", ignore_errors=True)

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows written in {duration:.2f}s ({throughput:.0f} rows/s)")
PYEOF

run_load_test "write-parquet" /tmp/load-write.py 50000 10 120

echo ""
log_info "=== 6. ML TRAINING TEST ==="

cat > /tmp/load-ml.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.classification import LogisticRegression
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

spark = SparkSession.builder \
    .appName("Load-ML") \
    .master("spark://localhost:7077") \
    .getOrCreate()

import time

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

start = time.time()

lr = LogisticRegression(maxIter=10)
model = lr.fit(data)

duration = time.time() - start

spark.stop()
print(f"LOAD_TEST_SUCCESS: {data_size} rows trained in {duration:.2f}s")
PYEOF

run_load_test "ml-training" /tmp/load-ml.py 10000 10 180

echo ""
echo "=============================================="
echo "LOAD TEST SUMMARY"
echo "=============================================="

cat "$RESULTS_FILE" | column -t -s ','

echo ""
echo "Results saved to: $RESULTS_FILE"

PASSED=$(grep -c "PASS$" "$RESULTS_FILE" || echo "0")
FAILED=$(grep -c "FAIL$" "$RESULTS_FILE" || echo "0")

echo ""
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"

if [[ $FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
