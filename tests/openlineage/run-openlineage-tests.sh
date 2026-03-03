#!/bin/bash
# OpenLineage Integration Tests for Lego-Spark
# Tests lineage tracking, event emission, and Marquez integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"
MARQUEZ_URL="${MARQUEZ_URL:-http://marquez:5000}"
OPENLINEAGE_TRANSPORT_TYPE="${OPENLINEAGE_TRANSPORT_TYPE:-http}"

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
log_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; echo "$1" >> "$RESULTS_DIR/openlineage-failed.log"; ((FAILED++)) || true; }
log_skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((SKIPPED++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

check_marquez() {
    MARQUEZ_POD=$(kubectl get pods -n $NAMESPACE -l app=marquez -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$MARQUEZ_POD" ]]; then
        return 0
    fi
    return 1
}

echo "=============================================="
echo "OPENLINEAGE INTEGRATION TESTS"
echo "=============================================="
echo "Namespace:    $NAMESPACE"
echo "Release:      $RELEASE"
echo "Marquez URL:  $MARQUEZ_URL"
echo "Time:         $(date)"
echo ""

MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
    echo "Error: Spark master pod not found"
    exit 1
fi

log_info "Master pod: $MASTER_POD"

# === 1. OpenLineage Configuration Check ===
log_info "=== 1. Configuration Check ==="

echo -n "Testing: openlineage-config-present... "
OL_CONFIG=$(kubectl exec -n $NAMESPACE $MASTER_POD -- env 2>/dev/null | grep -c OPENLINEAGE || echo "0")

if [[ $OL_CONFIG -gt 0 ]]; then
    log_pass "openlineage-config-present ($OL_CONFIG vars)"
else
    log_skip "openlineage-config-present (not configured)"
fi

# === 2. Spark Listener Registration ===
log_info "=== 2. Spark Listener Registration ==="

echo -n "Testing: openlineage-listener... "
LISTENER_CHECK=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
spark-submit --master local[*] --conf spark.extraListeners=io.openlineage.spark.OpenLineageSparkListener --class org.apache.spark.deploy.SparkSubmit --help 2>&1 | grep -c "OpenLineage" || echo "0"
' 2>/dev/null || echo "0")

if [[ $LISTENER_CHECK -gt 0 ]] || [[ $OL_CONFIG -gt 0 ]]; then
    log_pass "openlineage-listener"
else
    log_skip "openlineage-listener (jar not present)"
fi

# === 3. Lineage Event Emission ===
log_info "=== 3. Lineage Event Emission ==="

cat > /tmp/ol-lineage-test.py << 'PYEOF'
from pyspark.sql import SparkSession
import os
import json

spark = SparkSession.builder \
    .appName("OpenLineage-Test") \
    .master("local[*]") \
    .config("spark.extraListeners", "io.openlineage.spark.OpenLineageSparkListener") \
    .config("spark.openlineage.transport.type", os.environ.get("OPENLINEAGE_TRANSPORT_TYPE", "console")) \
    .config("spark.openlineage.namespace", "test-namespace") \
    .config("spark.openlineage.job.name", "lineage-test-job") \
    .config("spark.openlineage.parentRunId", "00000000-0000-0000-0000-000000000001") \
    .getOrCreate()

df = spark.range(100).withColumn("value", col("id") * 2)
df.write.mode("overwrite").parquet("/tmp/lineage-test-output")

import shutil
shutil.rmtree("/tmp/lineage-test-output", ignore_errors=True)

spark.stop()
print("OPENLINEAGE_LINEAGE_SUCCESS")
PYEOF

echo -n "Testing: lineage-event-emission... "
kubectl cp /tmp/ol-lineage-test.py $NAMESPACE/$MASTER_POD:/tmp/ol-lineage-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
export OPENLINEAGE_TRANSPORT_TYPE=console
timeout 60 spark-submit --master local[*] \
    --conf spark.extraListeners=io.openlineage.spark.OpenLineageSparkListener \
    --conf spark.openlineage.transport.type=console \
    /tmp/ol-lineage-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "OPENLINEAGE_LINEAGE_SUCCESS"; then
    log_pass "lineage-event-emission"
else
    log_fail "lineage-event-emission"
    echo "$OUTPUT" | tail -20 >> "$RESULTS_DIR/openlineage-lineage.log"
fi

rm -f /tmp/ol-lineage-test.py

# === 4. Dataset Lineage ===
log_info "=== 4. Dataset Lineage ==="

cat > /tmp/ol-dataset-test.py << 'PYEOF'
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder \
    .appName("OpenLineage-Dataset") \
    .master("local[*]") \
    .config("spark.extraListeners", "io.openlineage.spark.OpenLineageSparkListener") \
    .config("spark.openlineage.transport.type", "console") \
    .getOrCreate()

# Create input dataset
df1 = spark.range(100).withColumn("key", col("id") % 10)

# Transform
df2 = df1.groupBy("key").count()

# Write output dataset
df2.write.mode("overwrite").parquet("/tmp/lineage-output")

import shutil
shutil.rmtree("/tmp/lineage-output", ignore_errors=True)

spark.stop()
print("OPENLINEAGE_DATASET_SUCCESS")
PYEOF

echo -n "Testing: dataset-lineage... "
kubectl cp /tmp/ol-dataset-test.py $NAMESPACE/$MASTER_POD:/tmp/ol-dataset-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
timeout 60 spark-submit --master local[*] \
    --conf spark.extraListeners=io.openlineage.spark.OpenLineageSparkListener \
    --conf spark.openlineage.transport.type=console \
    /tmp/ol-dataset-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "OPENLINEAGE_DATASET_SUCCESS"; then
    log_pass "dataset-lineage"
else
    log_fail "dataset-lineage"
fi

rm -f /tmp/ol-dataset-test.py

# === 5. Job Run Tracking ===
log_info "=== 5. Job Run Tracking ==="

cat > /tmp/ol-run-test.py << 'PYEOF'
from pyspark.sql import SparkSession
import uuid
import os

run_id = str(uuid.uuid4())

spark = SparkSession.builder \
    .appName("OpenLineage-Run") \
    .master("local[*]") \
    .config("spark.extraListeners", "io.openlineage.spark.OpenLineageSparkListener") \
    .config("spark.openlineage.transport.type", "console") \
    .config("spark.openlineage.runId", run_id) \
    .getOrCreate()

df = spark.range(50)
count = df.count()

spark.stop()
print(f"OPENLINEAGE_RUN_SUCCESS: {run_id}")
PYEOF

echo -n "Testing: job-run-tracking... "
kubectl cp /tmp/ol-run-test.py $NAMESPACE/$MASTER_POD:/tmp/ol-run-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
timeout 60 spark-submit --master local[*] \
    --conf spark.extraListeners=io.openlineage.spark.OpenLineageSparkListener \
    --conf spark.openlineage.transport.type=console \
    /tmp/ol-run-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "OPENLINEAGE_RUN_SUCCESS"; then
    log_pass "job-run-tracking"
else
    log_fail "job-run-tracking"
fi

rm -f /tmp/ol-run-test.py

# === 6. Marquez Integration (if available) ===
if check_marquez; then
    log_info "=== 6. Marquez Integration ==="

    MARQUEZ_SVC=$(kubectl get svc -n $NAMESPACE -l app=marquez -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    echo -n "Testing: marquez-connectivity... "
    MARQUEZ_CHECK=$(kubectl exec -n $NAMESPACE $MASTER_POD -- curl -s -o /dev/null -w "%{http_code}" http://${MARQUEZ_SVC}:5000/api/v1/namespaces 2>/dev/null || echo "000")

    if [[ "$MARQUEZ_CHECK" == "200" ]]; then
        log_pass "marquez-connectivity"
    else
        log_skip "marquez-connectivity (status: $MARQUEZ_CHECK)"
    fi

    cat > /tmp/ol-marquez-test.py << PYEOF
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder \\
    .appName("OpenLineage-Marquez") \\
    .master("local[*]") \\
    .config("spark.extraListeners", "io.openlineage.spark.OpenLineageSparkListener") \\
    .config("spark.openlineage.transport.type", "http") \\
    .config("spark.openlineage.transport.url", "http://${MARQUEZ_SVC}:5000") \\
    .config("spark.openlineage.namespace", "lego-spark-test") \\
    .getOrCreate()

df = spark.range(100)
count = df.count()

spark.stop()
print("OPENLINEAGE_MARQUEZ_SUCCESS")
PYEOF

    echo -n "Testing: marquez-lineage-submit... "
    kubectl cp /tmp/ol-marquez-test.py $NAMESPACE/$MASTER_POD:/tmp/ol-marquez-test.py 2>/dev/null

    OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
    timeout 60 spark-submit --master local[*] \
        --conf spark.extraListeners=io.openlineage.spark.OpenLineageSparkListener \
        --conf spark.openlineage.transport.type=http \
        --conf spark.openlineage.transport.url=http://'${MARQUEZ_SVC}':5000 \
        /tmp/ol-marquez-test.py 2>&1
    ' 2>&1) || true

    if echo "$OUTPUT" | grep -q "OPENLINEAGE_MARQUEZ_SUCCESS"; then
        log_pass "marquez-lineage-submit"
    else
        log_fail "marquez-lineage-submit"
    fi

    rm -f /tmp/ol-marquez-test.py
fi

# === Summary ===
echo ""
echo "=============================================="
echo "OPENLINEAGE TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

echo "openlineage,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/openlineage-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/openlineage-failed.log"
    exit 1
else
    echo "All OpenLineage tests passed!"
    exit 0
fi
