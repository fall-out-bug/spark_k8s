#!/bin/bash
# E2E Test Template for Lego-Spark
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
#   TEST_TIMEOUT     - Test timeout in seconds (default: 120)

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
TIMEOUT="${TEST_TIMEOUT:-120}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"
SCENARIO_ID="e2e-${SPARK_VERSION}-${PLATFORM}-${DEPLOYMENT_MODE}-connect-${CONNECT_ENABLED}"

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
    echo "[$(date)] $SCENARIO_ID: $1" >> "$RESULTS_DIR/e2e-failed.log"
    ((FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++)) || true
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

get_chart_path() {
    case $SPARK_VERSION in
        3.5.7|3.5.8)
            echo "$PROJECT_ROOT/charts/spark-3.5"
            ;;
        4.0.2)
            echo "$PROJECT_ROOT/charts/spark-4.0"
            ;;
        4.1.1)
            echo "$PROJECT_ROOT/charts/spark-4.1"
            ;;
        *)
            echo "$PROJECT_ROOT/charts/spark-3.5"
            ;;
    esac
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

run_spark_job() {
    local script="$1"
    local name="$2"
    local timeout="${3:-$TIMEOUT}"
    local expected="${4:-E2E_RESULT}"

    local MASTER_POD=$(get_master_pod)

    if [[ -z "$MASTER_POD" ]]; then
        log_skip "$name (no spark pod)"
        return 0
    fi

    echo -n "Running: $name... "

    kubectl cp "$script" $NAMESPACE/$MASTER_POD:/tmp/test.py 2>/dev/null

    local master_url="local[*]"
    if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
        master_url="spark://$(get_master_service):7077"
    fi

    local output
    output=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c 'DRIVER_HOST=$(hostname -i) && timeout '$timeout' spark-submit --master '$master_url' --conf spark.driver.host=$DRIVER_HOST --conf spark.driver.bindAddress=0.0.0.0 /tmp/test.py' 2>&1) || true

    if echo "$output" | grep -q "$expected"; then
        log_pass "$name"
        return 0
    else
        log_fail "$name"
        echo "$output" | tail -30 >> "$RESULTS_DIR/${name// /_}-$SCENARIO_ID.log"
        return 1
    fi
}

run_connect_job() {
    local script="$1"
    local name="$2"
    local timeout="${3:-$TIMEOUT}"
    local expected="${4:-CONNECT_RESULT}"

    if [[ "$CONNECT_ENABLED" != "true" ]]; then
        log_skip "$name (connect not enabled)"
        return 0
    fi

    local CONNECT_POD=$(kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-connect' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$CONNECT_POD" ]]; then
        log_skip "$name (no connect pod)"
        return 0
    fi

    echo -n "Running: $name... "

    kubectl cp "$script" $NAMESPACE/$CONNECT_POD:/tmp/test.py 2>/dev/null

    local output
    output=$(kubectl exec -n $NAMESPACE $CONNECT_POD -- timeout $timeout python3 /tmp/test.py 2>&1) || true

    if echo "$output" | grep -q "$expected"; then
        log_pass "$name"
        return 0
    else
        log_fail "$name"
        echo "$output" | tail -30 >> "$RESULTS_DIR/${name// /_}-$SCENARIO_ID.log"
        return 1
    fi
}

# === Header ===
echo "=============================================="
echo "E2E TEST - Scenario: $SCENARIO_ID"
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
echo "Time:             $(date)"
echo ""

CHART_PATH=$(get_chart_path)

# === 1. CHART VALIDATION ===
log_section "1. CHART VALIDATION"

if [[ -d "$CHART_PATH" ]]; then
    echo -n "Linting chart... "
    if helm lint "$CHART_PATH" > /dev/null 2>&1; then
        log_pass "chart-lint"
    else
        log_fail "chart-lint"
    fi

    echo -n "Templating chart... "
    if helm template test "$CHART_PATH" > /dev/null 2>&1; then
        log_pass "chart-template"
    else
        log_fail "chart-template"
    fi
else
    log_skip "chart-validation (chart not found: $CHART_PATH)"
fi

# === 2. SPARK SQL E2E ===
log_section "2. SPARK SQL E2E"

MASTER_URL="local[*]"
if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
    MASTER_URL="spark://$(get_master_service):7077"
fi

cat > /tmp/e2e-sql-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum

spark = SparkSession.builder \\
    .appName("E2E-SQL-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.shuffle.partitions", "4") \\
    .getOrCreate()

df = spark.range(1000).withColumn("group", col("id") % 10)

result = df.groupBy("group").agg(
    count("*").alias("count"),
    spark_sum("id").alias("sum_id")
).orderBy("group")

row_count = result.count()
spark.stop()
print(f"E2E_SQL_RESULT: {row_count}")
PYEOF

run_spark_job /tmp/e2e-sql-test-$SCENARIO_ID.py "spark-sql-e2e" 120 "E2E_SQL_RESULT: 10"

# === 3. DATAFRAME OPERATIONS E2E ===
log_section "3. DATAFRAME OPERATIONS E2E"

cat > /tmp/e2e-df-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

spark = SparkSession.builder \\
    .appName("E2E-DF-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .getOrCreate()

df1 = spark.range(1000).withColumn("key", col("id")).withColumnRenamed("id", "id1")
df2 = spark.range(500).withColumn("key", col("id") * 2).withColumnRenamed("id", "id2")

joined = df1.join(df2, "key", "left").filter(col("id1").isNotNull())
filtered = joined.filter(col("key") > 100)
aggregated = filtered.groupBy((col("key") % 100).alias("bucket")).count()

result_count = aggregated.count()
spark.stop()
print(f"E2E_DF_RESULT: {result_count}")
PYEOF

run_spark_job /tmp/e2e-df-test-$SCENARIO_ID.py "dataframe-e2e" 120 "E2E_DF_RESULT:"

# === 4. ML PIPELINE E2E ===
log_section "4. ML PIPELINE E2E"

cat > /tmp/e2e-ml-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.classification import LogisticRegression
from pyspark.sql.functions import col

spark = SparkSession.builder \\
    .appName("E2E-ML-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .getOrCreate()

df = spark.range(1000).select(
    col("id").alias("feature1"),
    (col("id") * 2).alias("feature2"),
    (col("id") % 2).alias("label")
)

assembler = VectorAssembler(
    inputCols=["feature1", "feature2"],
    outputCol="features"
)
data = assembler.transform(df)

lr = LogisticRegression(maxIter=10)
model = lr.fit(data)

predictions = model.transform(data)
from pyspark.ml.evaluation import BinaryClassificationEvaluator
evaluator = BinaryClassificationEvaluator()
auc = evaluator.evaluate(predictions)

spark.stop()
print(f"E2E_ML_RESULT: {auc:.4f}")
PYEOF

run_spark_job /tmp/e2e-ml-test-$SCENARIO_ID.py "ml-pipeline-e2e" 180 "E2E_ML_RESULT:"

# === 5. SPARK CONNECT E2E (if enabled) ===
if [[ "$CONNECT_ENABLED" == "true" ]]; then
    log_section "5. SPARK CONNECT E2E"

    CONNECT_SVC=$(kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component=spark-connect' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$CONNECT_SVC" ]]; then
        cat > /tmp/e2e-connect-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder.remote("sc://localhost:15002").getOrCreate()

df = spark.range(100)
count = df.count()

spark.stop()
print(f"CONNECT_RESULT: {count}")
PYEOF

        run_connect_job /tmp/e2e-connect-test-$SCENARIO_ID.py "connect-e2e" 60 "CONNECT_RESULT: 100"
    else
        log_skip "connect-e2e (service not found)"
    fi
fi

# === 6. GPU E2E (if enabled) ===
if [[ "$GPU_ENABLED" == "true" ]]; then
    log_section "6. GPU E2E"

    cat > /tmp/e2e-gpu-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("E2E-GPU-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \\
    .config("spark.rapids.sql.enabled", "true") \\
    .getOrCreate()

# Check if RAPIDS is available
try:
    df = spark.range(100)
    count = df.count()
    result = "GPU_RESULT: SUCCESS"
except Exception as e:
    result = f"GPU_RESULT: ERROR - {e}"

spark.stop()
print(result)
PYEOF

    run_spark_job /tmp/e2e-gpu-test-$SCENARIO_ID.py "gpu-e2e" 120 "GPU_RESULT: SUCCESS"
fi

# === 7. ICEBERG E2E (if enabled) ===
if [[ "$ICEBERG_ENABLED" == "true" ]]; then
    log_section "7. ICEBERG E2E"

    MINIO_SVC=$(kubectl get svc -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$MINIO_SVC" ]]; then
        cat > /tmp/e2e-iceberg-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("E2E-Iceberg-$SCENARIO_ID") \\
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

try:
    # Create database and table
    spark.sql("CREATE DATABASE IF NOT EXISTS my_catalog.e2e_test")
    spark.sql("CREATE TABLE IF NOT EXISTS my_catalog.e2e_test.test_table (id LONG, name STRING) USING iceberg")

    # Insert
    spark.sql("INSERT INTO my_catalog.e2e_test.test_table VALUES (1, 'test')")

    # Select
    count = spark.sql("SELECT COUNT(*) as cnt FROM my_catalog.e2e_test.test_table").collect()[0]["cnt"]

    spark.stop()
    print(f"ICEBERG_RESULT: {count}")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_ERROR: {e}")
PYEOF

        run_spark_job /tmp/e2e-iceberg-test-$SCENARIO_ID.py "iceberg-e2e" 180 "ICEBERG_RESULT:"
    else
        log_skip "iceberg-e2e (MinIO not deployed)"
    fi
fi

# === 8. SHUFFLE SERVICE E2E (if enabled) ===
if [[ "$SHUFFLE_ENABLED" == "true" ]]; then
    log_section "8. SHUFFLE SERVICE E2E"

    SHUFFLE_SVC=$(kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component=shuffle-service' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$SHUFFLE_SVC" ]]; then
        cat > /tmp/e2e-shuffle-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count

spark = SparkSession.builder \\
    .appName("E2E-Shuffle-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .config("spark.shuffle.service.enabled", "true") \\
    .config("spark.shuffle.service.port", "7337") \\
    .config("spark.sql.shuffle.partitions", "50") \\
    .getOrCreate()

# Heavy shuffle operation
df = spark.range(10000).withColumn("key", col("id") % 100)
result = df.groupBy("key").agg(count("*").alias("cnt")).count()

spark.stop()
print(f"SHUFFLE_RESULT: {result}")
PYEOF

        run_spark_job /tmp/e2e-shuffle-test-$SCENARIO_ID.py "shuffle-e2e" 180 "SHUFFLE_RESULT:"
    else
        log_skip "shuffle-e2e (shuffle service not deployed)"
    fi
fi

# === 9. OPENLINEAGE E2E (if enabled) ===
if [[ "$OPENLINEAGE_ENABLED" == "true" ]]; then
    log_section "9. OPENLINEAGE E2E"

    cat > /tmp/e2e-openlineage-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder \\
    .appName("E2E-OpenLineage-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .config("spark.extraListeners", "io.openlineage.spark.OpenLineageSparkListener") \\
    .config("spark.openlineage.transport.type", "http") \\
    .config("spark.openlineage.transport.url", os.environ.get("OPENLINEAGE_URL", "http://marquez:5000")) \\
    .getOrCreate()

df = spark.range(100)
count = df.count()

spark.stop()
print(f"OPENLINEAGE_RESULT: {count}")
PYEOF

    run_spark_job /tmp/e2e-openlineage-test-$SCENARIO_ID.py "openlineage-e2e" 120 "OPENLINEAGE_RESULT:"
fi

# === Cleanup ===
rm -f /tmp/e2e-*-$SCENARIO_ID.py

# === Summary ===
echo ""
echo "=============================================="
echo "E2E TEST SUMMARY - $SCENARIO_ID"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

# Record results
echo "$SCENARIO_ID,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/e2e-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/e2e-failed.log"
    exit 1
else
    echo "All E2E tests passed for scenario: $SCENARIO_ID"
    exit 0
fi
