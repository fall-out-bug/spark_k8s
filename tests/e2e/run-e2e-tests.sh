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

PASSED=0
FAILED=0
SKIPPED=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "$1" >> "$RESULTS_DIR/e2e-failed.txt"
    ((FAILED++))
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++))
}

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l app=spark-standalone-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

run_spark_job() {
    local script="$1"
    local name="$2"
    local timeout="${3:-120}"
    local expected="${4:-SMOKE_TEST_RESULT: 100}"
    
    local MASTER_POD=$(get_master_pod)
    
    if [[ -z "$MASTER_POD" ]]; then
        log_skip "$name (no master pod)"
        return 0
    fi
    
    echo -n "Running: $name... "
    
    kubectl cp "$script" $NAMESPACE/$MASTER_POD:/tmp/test.py 2>/dev/null
    
    local output
    output=$(kubectl exec -n $NAMESPACE $MASTER_POD -- timeout $timeout spark-submit --master spark://localhost:7077 /tmp/test.py 2>&1) || true
    
    if echo "$output" | grep -q "$expected"; then
        log_pass "$name"
        return 0
    else
        log_fail "$name"
        echo "$output" >> "$RESULTS_DIR/${name// /_}.log"
        return 1
    fi
}

test_preset_lint() {
    local preset="$1"
    local name="$2"
    
    echo -n "Linting preset: $name... "
    
    if helm lint "$PROJECT_ROOT/charts/spark-3.5" -f "$preset" > /dev/null 2>&1; then
        log_pass "preset-lint-$name"
        return 0
    else
        log_fail "preset-lint-$name"
        return 1
    fi
}

test_preset_template() {
    local preset="$1"
    local name="$2"
    
    echo -n "Templating preset: $name... "
    
    if helm template test "$PROJECT_ROOT/charts/spark-3.5" -f "$preset" > /dev/null 2>&1; then
        log_pass "preset-template-$name"
        return 0
    else
        log_fail "preset-template-$name"
        return 1
    fi
}

echo "=============================================="
echo "E2E TESTS - Lego-Spark"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo "Release:   $RELEASE"
echo "Time:      $(date)"
echo ""

log_section "1. PRESET VALIDATION"

PRESETS_DIR="$PROJECT_ROOT/charts/spark-3.5/presets"

for preset in $(find "$PRESETS_DIR" -name "*.yaml" -type f | sort); do
    name=$(echo "$preset" | sed "s|$PRESETS_DIR/||" | sed 's|.yaml$||' | tr '/' '-')
    test_preset_lint "$preset" "$name"
    test_preset_template "$preset" "$name"
done

log_section "2. EXAMPLE VALIDATION"

EXAMPLES_DIR="$PROJECT_ROOT/charts/spark-3.5/examples"

for file in $(find "$EXAMPLES_DIR" -name "*.py" -type f | sort); do
    name=$(basename "$file" .py)
    echo -n "Validating: $name... "
    
    if python3 -m py_compile "$file" 2>/dev/null; then
        log_pass "example-syntax-$name"
    else
        log_fail "example-syntax-$name"
    fi
done

log_section "3. SPARK SQL E2E"

cat > /tmp/e2e-sql-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum

spark = SparkSession.builder \
    .appName("E2E-SQL-Test") \
    .master("spark://localhost:7077") \
    .config("spark.sql.shuffle.partitions", "4") \
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

run_spark_job /tmp/e2e-sql-test.py "spark-sql-e2e" 120 "E2E_SQL_RESULT: 10"

log_section "4. DATAFRAME OPERATIONS E2E"

cat > /tmp/e2e-df-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, rand

spark = SparkSession.builder \
    .appName("E2E-DF-Test") \
    .master("spark://localhost:7077") \
    .getOrCreate()

df1 = spark.range(1000).withColumn("key", col("id"))
df2 = spark.range(500).withColumn("key", col("id") * 2)

joined = df1.join(df2, "key", "left").filter(col("id").isNotNull())
filtered = joined.filter(col("key") > 100)
aggregated = filtered.groupBy((col("key") % 100).alias("bucket")).count()

result_count = aggregated.count()
spark.stop()
print(f"E2E_DF_RESULT: {result_count}")
PYEOF

run_spark_job /tmp/e2e-df-test.py "dataframe-e2e" 120 "E2E_DF_RESULT:"

log_section "5. ML PIPELINE E2E"

cat > /tmp/e2e-ml-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.classification import LogisticRegression
from pyspark.ml.evaluation import BinaryClassificationEvaluator

spark = SparkSession.builder \
    .appName("E2E-ML-Test") \
    .master("spark://localhost:7077") \
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
evaluator = BinaryClassificationEvaluator()
auc = evaluator.evaluate(predictions)

spark.stop()
print(f"E2E_ML_RESULT: {auc:.4f}")
PYEOF

run_spark_job /tmp/e2e-ml-test.py "ml-pipeline-e2e" 180 "E2E_ML_RESULT:"

log_section "6. STREAMING (FILE SOURCE) E2E"

cat > /tmp/e2e-stream-test.py << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count

spark = SparkSession.builder \
    .appName("E2E-Stream-Test") \
    .master("spark://localhost:7077") \
    .config("spark.sql.shuffle.partitions", "2") \
    .getOrCreate()

rate_df = spark.readStream \
    .format("rate") \
    .option("rowsPerSecond", 100) \
    .load()

query = rate_df.writeStream \
    .format("memory") \
    .queryName("rate_table") \
    .trigger(processingTime="3 seconds") \
    .start()

import time
time.sleep(5)

query.stop()

result = spark.sql("SELECT COUNT(*) as cnt FROM rate_table").collect()
count = result[0]["cnt"]

spark.stop()
print(f"E2E_STREAM_RESULT: {count}")
PYEOF

run_spark_job /tmp/e2e-stream-test.py "streaming-e2e" 60 "E2E_STREAM_RESULT:"

log_section "7. S3/MINIO STORAGE E2E"

MINIO_SVC=$(kubectl get svc -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$MINIO_SVC" ]]; then
    cat > /tmp/e2e-s3-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("E2E-S3-Test") \\
    .master("spark://localhost:7077") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_SVC}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

df = spark.range(100)

try:
    df.write.mode("overwrite").parquet("s3a://test-bucket/e2e-test/")
    read_df = spark.read.parquet("s3a://test-bucket/e2e-test/")
    count = read_df.count()
    result = f"E2E_S3_RESULT: {count}"
except Exception as e:
    result = f"E2E_S3_ERROR: {str(e)}"

spark.stop()
print(result)
PYEOF

    run_spark_job /tmp/e2e-s3-test.py "s3-storage-e2e" 120 "E2E_S3_RESULT: 100"
else
    log_skip "s3-storage-e2e (MinIO not deployed)"
fi

log_section "8. MONITORING E2E"

DASHBOARDS=$(kubectl get configmap -n $NAMESPACE -l grafana_dashboard=1 --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $DASHBOARDS -gt 0 ]]; then
    echo -n "Checking Grafana dashboards... "
    
    DASHBOARD_NAMES=$(kubectl get configmap -n $NAMESPACE -l grafana_dashboard=1 -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    DASHBOARD_COUNT=$(echo $DASHBOARD_NAMES | wc -w)
    
    if [[ $DASHBOARD_COUNT -ge 5 ]]; then
        log_pass "grafana-dashboards-count ($DASHBOARD_COUNT found)"
    else
        log_fail "grafana-dashboards-count (expected >= 5, got $DASHBOARD_COUNT)"
    fi
else
    log_skip "grafana-dashboards-e2e (not enabled)"
fi

ALERTS=$(kubectl get prometheusrule -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $ALERTS -gt 0 ]]; then
    echo -n "Checking Prometheus rules... "
    
    ALERT_COUNT=$(kubectl get prometheusrule -n $NAMESPACE -o jsonpath='{.items[0].spec.groups[*].rules}' 2>/dev/null | grep -c "alert:" || echo "0")
    
    if [[ $ALERT_COUNT -ge 3 ]]; then
        log_pass "prometheus-alerts-count ($ALERT_COUNT rules)"
    else
        log_fail "prometheus-alerts-count (expected >= 3, got $ALERT_COUNT)"
    fi
else
    log_skip "prometheus-alerts-e2e (not enabled)"
fi

echo ""
echo "=============================================="
echo "E2E TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "$PASSED,$FAILED,$SKIPPED,$TIMESTAMP" >> "$RESULTS_DIR/e2e-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests saved to: $RESULTS_DIR/e2e-failed.txt"
    exit 1
else
    echo "All E2E tests passed!"
    exit 0
fi
