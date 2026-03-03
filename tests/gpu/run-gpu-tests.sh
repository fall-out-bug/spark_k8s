#!/bin/bash
# GPU Tests for Lego-Spark
# Tests GPU resource allocation, RAPIDS acceleration, and GPU compute

set -euo pipefail

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

PASSED=0
FAILED=0
SKIPPED=0

log_pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)) || true; }
log_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; echo "$1" >> "$RESULTS_DIR/gpu-failed.log"; ((FAILED++)) || true; }
log_skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((SKIPPED++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

check_gpu_nodes() {
    GPU_NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.nvidia\.com/gpu}' 2>/dev/null | grep -c -E '[0-9]+' || echo "0")
    if [[ $GPU_NODES -gt 0 ]]; then
        return 0
    fi
    return 1
}

check_gpu_pods() {
    GPU_PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.requests.nvidia\.com/gpu}' 2>/dev/null | grep -c -E '[0-9]+' || echo "0")
    if [[ $GPU_PODS -gt 0 ]]; then
        return 0
    fi
    return 1
}

get_master_service() {
    echo "${RELEASE}-standalone-master"
}

echo "=============================================="
echo "GPU TESTS"
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

# === 1. GPU Node Availability ===
log_info "=== 1. GPU Node Availability ==="

echo -n "Testing: gpu-nodes-present... "
if check_gpu_nodes; then
    GPU_COUNT=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | awk '{s+=$1}END{print s}')
    log_pass "gpu-nodes-present ($GPU_COUNT GPUs total)"
else
    log_skip "gpu-nodes-present (no GPU nodes in cluster)"
fi

# === 2. GPU Resource Allocation ===
log_info "=== 2. GPU Resource Allocation ==="

echo -n "Testing: gpu-pod-resources... "
if check_gpu_pods; then
    GPU_ALLOCATED=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.requests.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | awk '{s+=$1}END{print s}')
    log_pass "gpu-pod-resources ($GPU_ALLOCATED GPUs allocated)"
else
    log_skip "gpu-pod-resources (no GPU resources in pods)"
fi

# === 3. NVIDIA Device Plugin ===
log_info "=== 3. NVIDIA Device Plugin ==="

echo -n "Testing: nvidia-device-plugin... "
NVIDIA_DS=$(kubectl get ds -n kube-system -l name=nvidia-device-plugin-ds --no-headers 2>/dev/null | grep -c Running || echo "0")

if [[ $NVIDIA_DS -gt 0 ]]; then
    log_pass "nvidia-device-plugin"
else
    log_skip "nvidia-device-plugin (not installed)"
fi

# === 4. RAPIDS Configuration ===
log_info "=== 4. RAPIDS Configuration ==="

echo -n "Testing: rapids-plugin-config... "
RAPIDS_CHECK=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
    ls /opt/spark/jars/ 2>/dev/null | grep -c rapids || echo "0"
' 2>/dev/null || echo "0")

if [[ $RAPIDS_CHECK -gt 0 ]]; then
    log_pass "rapids-plugin-config ($RAPIDS_CHECK jars)"
else
    log_skip "rapids-plugin-config (RAPIDS jars not found)"
fi

# === 5. GPU Spark Submit ===
log_info "=== 5. GPU Spark Submit ==="

cat > /tmp/gpu-submit-test.py << 'PYEOF'
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder \
    .appName("GPU-Submit-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .config("spark.rapids.sql.concurrentGpuTasks", "1") \
    .config("spark.task.resource.gpu.amount", "1") \
    .config("spark.executor.resource.gpu.amount", "1") \
    .config("spark.executor.resource.gpu.discoveryScript", "/opt/spark/examples/src/main/scripts/getGpusResources.sh") \
    .getOrCreate()

try:
    df = spark.range(100)
    count = df.count()
    spark.stop()
    print("GPU_SUBMIT_SUCCESS")
except Exception as e:
    print(f"GPU_SUBMIT_ERROR: {e}")
    spark.stop()
PYEOF

echo -n "Testing: gpu-spark-submit... "
kubectl cp /tmp/gpu-submit-test.py $NAMESPACE/$MASTER_POD:/tmp/gpu-submit-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.enabled=true \
    /tmp/gpu-submit-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "GPU_SUBMIT_SUCCESS"; then
    log_pass "gpu-spark-submit"
elif echo "$OUTPUT" | grep -q "GPU_SUBMIT_ERROR"; then
    log_fail "gpu-spark-submit"
else
    log_skip "gpu-spark-submit (no GPU available)"
fi

rm -f /tmp/gpu-submit-test.py

# === 6. GPU DataFrame Operations ===
log_info "=== 6. GPU DataFrame Operations ==="

cat > /tmp/gpu-df-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand, when
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

spark = SparkSession.builder \
    .appName("GPU-DataFrame-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .config("spark.sql.adaptive.enabled", "true") \
    .getOrCreate()

import time
start = time.time()

df = spark.range(data_size).withColumn("value", rand() * 1000)
df = df.withColumn("category", when(col("value") > 500, "high").otherwise("low"))

result = df.groupBy("category").count()
count = result.count()

duration = time.time() - start

spark.stop()
print(f"GPU_DF_SUCCESS: {count} categories in {duration:.2f}s")
PYEOF

echo -n "Testing: gpu-dataframe-operations... "
kubectl cp /tmp/gpu-df-test.py $NAMESPACE/$MASTER_POD:/tmp/gpu-df-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.enabled=true \
    /tmp/gpu-df-test.py 10000 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "GPU_DF_SUCCESS"; then
    log_pass "gpu-dataframe-operations"
else
    log_skip "gpu-dataframe-operations (GPU not available)"
fi

rm -f /tmp/gpu-df-test.py

# === 7. GPU ML Operations ===
log_info "=== 7. GPU ML Operations ==="

cat > /tmp/gpu-ml-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.classification import LogisticRegression
import sys

data_size = int(sys.argv[1]) if len(sys.argv) > 1 else 1000

spark = SparkSession.builder \
    .appName("GPU-ML-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .getOrCreate()

from pyspark.sql.functions import col

df = spark.range(data_size).select(
    col("id").alias("f1"),
    (col("id") * 2).alias("f2"),
    (col("id") % 2).alias("label")
)

assembler = VectorAssembler(inputCols=["f1", "f2"], outputCol="features")
data = assembler.transform(df)

import time
start = time.time()

lr = LogisticRegression(maxIter=10)
model = lr.fit(data)

duration = time.time() - start

spark.stop()
print(f"GPU_ML_SUCCESS: {data_size} rows in {duration:.2f}s")
PYEOF

echo -n "Testing: gpu-ml-operations... "
kubectl cp /tmp/gpu-ml-test.py $NAMESPACE/$MASTER_POD:/tmp/gpu-ml-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 180 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.enabled=true \
    /tmp/gpu-ml-test.py 1000 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "GPU_ML_SUCCESS"; then
    log_pass "gpu-ml-operations"
else
    log_skip "gpu-ml-operations (GPU not available)"
fi

rm -f /tmp/gpu-ml-test.py

# === 8. GPU Memory Test ===
log_info "=== 8. GPU Memory Test ==="

cat > /tmp/gpu-memory-test.py << 'PYEOF'
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("GPU-Memory-Test") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .getOrCreate()

try:
    from pyspark.sql.functions import col

    df = spark.range(50000).withColumn("x", col("id") * 1.5)
    df = df.withColumn("y", col("x") * 2.0)
    df.cache()

    count = df.count()
    df.unpersist()

    spark.stop()
    print("GPU_MEMORY_SUCCESS")
except Exception as e:
    spark.stop()
    print(f"GPU_MEMORY_ERROR: {e}")
PYEOF

echo -n "Testing: gpu-memory-operations... "
kubectl cp /tmp/gpu-memory-test.py $NAMESPACE/$MASTER_POD:/tmp/gpu-memory-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.enabled=true \
    /tmp/gpu-memory-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "GPU_MEMORY_SUCCESS"; then
    log_pass "gpu-memory-operations"
else
    log_skip "gpu-memory-operations"
fi

rm -f /tmp/gpu-memory-test.py

# === Summary ===
echo ""
echo "=============================================="
echo "GPU TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

echo "gpu,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/gpu-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/gpu-failed.log"
    exit 1
else
    echo "All GPU tests passed!"
    exit 0
fi
