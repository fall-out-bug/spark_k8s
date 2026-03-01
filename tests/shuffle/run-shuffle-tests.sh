#!/bin/bash
# Shuffle Service Tests for Lego-Spark
# Tests shuffle service functionality, performance, and reliability

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"
SHUFFLE_PORT="${SHUFFLE_PORT:-7337}"

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

log_pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)) || true; }
log_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; echo "$1" >> "$RESULTS_DIR/shuffle-failed.log"; ((FAILED++)) || true; }
log_skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((SKIPPED++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

check_shuffle_service() {
    SHUFFLE_SVC=$(kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component=shuffle-service' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$SHUFFLE_SVC" ]]; then
        return 0
    fi
    return 1
}

get_master_service() {
    echo "${RELEASE}-standalone-master"
}

echo "=============================================="
echo "SHUFFLE SERVICE TESTS"
echo "=============================================="
echo "Namespace:     $NAMESPACE"
echo "Release:       $RELEASE"
echo "Shuffle Port:  $SHUFFLE_PORT"
echo "Time:          $(date)"
echo ""

MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
    echo "Error: Spark master pod not found"
    exit 1
fi

log_info "Master pod: $MASTER_POD"

# === 1. Shuffle Service Availability ===
log_info "=== 1. Shuffle Service Availability ==="

echo -n "Testing: shuffle-service-endpoint... "
if check_shuffle_service; then
    log_pass "shuffle-service-endpoint"
else
    log_skip "shuffle-service-endpoint (service not deployed)"
fi

SHUFFLE_SVC=$(kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component=shuffle-service' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo -n "Testing: shuffle-service-port... "
if [[ -n "$SHUFFLE_SVC" ]]; then
    PORT=$(kubectl get svc -n $NAMESPACE $SHUFFLE_SVC -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")
    if [[ "$PORT" == "$SHUFFLE_PORT" ]]; then
        log_pass "shuffle-service-port ($PORT)"
    else
        log_fail "shuffle-service-port (expected $SHUFFLE_PORT, got $PORT)"
    fi
else
    log_skip "shuffle-service-port (service not found)"
fi

# === 2. Shuffle Service Pods ===
log_info "=== 2. Shuffle Service Pods ==="

echo -n "Testing: shuffle-pods-running... "
SHUFFLE_PODS=$(kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=shuffle-service' --no-headers 2>/dev/null | grep -c Running || echo "0")

if [[ $SHUFFLE_PODS -gt 0 ]]; then
    log_pass "shuffle-pods-running ($SHUFFLE_PODS)"
else
    log_skip "shuffle-pods-running (no shuffle pods)"
fi

# === 3. Heavy Shuffle Operations ===
log_info "=== 3. Heavy Shuffle Operations ==="

MASTER_URL="spark://$(get_master_service):7077"

cat > /tmp/shuffle-heavy-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 50

spark = SparkSession.builder \
    .appName("Shuffle-Heavy-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .config("spark.shuffle.service.enabled", "true") \
    .config("spark.shuffle.service.port", "7337") \
    .getOrCreate()

import time
start = time.time()

# Multiple shuffle operations
df1 = spark.range(data_size).withColumn("key1", col("id") % 100)
df2 = spark.range(data_size).withColumn("key2", col("id") % 100)
df3 = spark.range(data_size // 2).withColumn("key1", col("id") % 100)

# Join (shuffle)
joined = df1.join(df2, col("key1") == col("key2"), "inner")

# Group by (shuffle)
aggregated = joined.groupBy("key1").agg(
    count("*").alias("cnt"),
    spark_sum("id").alias("total")
)

# Another join (shuffle)
result = aggregated.join(df3, "key1", "left")

count = result.count()
duration = time.time() - start

spark.stop()
print(f"SHUFFLE_HEAVY_SUCCESS: {count} rows in {duration:.2f}s")
PYEOF

echo -n "Testing: heavy-shuffle-operations... "
kubectl cp /tmp/shuffle-heavy-test.py $NAMESPACE/$MASTER_POD:/tmp/shuffle-heavy-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 180 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.sql.shuffle.partitions=50 \
    --conf spark.shuffle.service.enabled=true \
    --conf spark.shuffle.service.port=7337 \
    /tmp/shuffle-heavy-test.py 10000 50 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "SHUFFLE_HEAVY_SUCCESS"; then
    log_pass "heavy-shuffle-operations"
else
    log_fail "heavy-shuffle-operations"
    echo "$OUTPUT" | tail -20 >> "$RESULTS_DIR/shuffle-heavy.log"
fi

rm -f /tmp/shuffle-heavy-test.py

# === 4. Skewed Shuffle Test ===
log_info "=== 4. Skewed Shuffle Test ==="

cat > /tmp/shuffle-skew-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

spark = SparkSession.builder \
    .appName("Shuffle-Skew-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.sql.shuffle.partitions", "20") \
    .config("spark.shuffle.service.enabled", "true") \
    .getOrCreate()

import time
start = time.time()

# Create skewed data (90% goes to one partition)
df = spark.range(data_size).withColumn(
    "skewed_key",
    when(col("id") < data_size * 0.9, 0).otherwise(col("id"))
)

# Aggregation on skewed key
result = df.groupBy("skewed_key").count()
count = result.count()

duration = time.time() - start

spark.stop()
print(f"SHUFFLE_SKEW_SUCCESS: {count} keys in {duration:.2f}s")
PYEOF

echo -n "Testing: skewed-shuffle... "
kubectl cp /tmp/shuffle-skew-test.py $NAMESPACE/$MASTER_POD:/tmp/shuffle-skew-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/shuffle-skew-test.py 10000 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "SHUFFLE_SKEW_SUCCESS"; then
    log_pass "skewed-shuffle"
else
    log_fail "skewed-shuffle"
fi

rm -f /tmp/shuffle-skew-test.py

# === 5. Large Partition Shuffle ===
log_info "=== 5. Large Partition Shuffle ==="

cat > /tmp/shuffle-partition-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import sys

partitions = int(sys.argv[1]) if len(sys.argv) > 1 else 100

spark = SparkSession.builder \
    .appName("Shuffle-Partition-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.sql.shuffle.partitions", str(partitions)) \
    .config("spark.shuffle.service.enabled", "true") \
    .getOrCreate()

import time
start = time.time()

df = spark.range(10000).withColumn("partition_key", col("id") % partitions)
result = df.repartition(partitions, "partition_key").count()

duration = time.time() - start

spark.stop()
print(f"SHUFFLE_PARTITION_SUCCESS: {partitions} partitions in {duration:.2f}s")
PYEOF

echo -n "Testing: large-partition-shuffle... "
kubectl cp /tmp/shuffle-partition-test.py $NAMESPACE/$MASTER_POD:/tmp/shuffle-partition-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/shuffle-partition-test.py 100 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "SHUFFLE_PARTITION_SUCCESS"; then
    log_pass "large-partition-shuffle"
else
    log_fail "large-partition-shuffle"
fi

rm -f /tmp/shuffle-partition-test.py

# === 6. Shuffle with Sort ===
log_info "=== 6. Shuffle with Sort ==="

cat > /tmp/shuffle-sort-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

spark = SparkSession.builder \
    .appName("Shuffle-Sort-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.shuffle.service.enabled", "true") \
    .getOrCreate()

import time
start = time.time()

df = spark.range(data_size).withColumn("random", rand())
sorted_df = df.orderBy("random")
count = sorted_df.count()

duration = time.time() - start

spark.stop()
print(f"SHUFFLE_SORT_SUCCESS: {count} rows in {duration:.2f}s")
PYEOF

echo -n "Testing: shuffle-with-sort... "
kubectl cp /tmp/shuffle-sort-test.py $NAMESPACE/$MASTER_POD:/tmp/shuffle-sort-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/shuffle-sort-test.py 10000 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "SHUFFLE_SORT_SUCCESS"; then
    log_pass "shuffle-with-sort"
else
    log_fail "shuffle-with-sort"
fi

rm -f /tmp/shuffle-sort-test.py

# === Summary ===
echo ""
echo "=============================================="
echo "SHUFFLE SERVICE TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

echo "shuffle,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/shuffle-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/shuffle-failed.log"
    exit 1
else
    echo "All Shuffle Service tests passed!"
    exit 0
fi
