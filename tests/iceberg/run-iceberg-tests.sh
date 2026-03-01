#!/bin/bash
# Iceberg CRUD Tests for Lego-Spark
# Tests Iceberg table operations: CREATE, INSERT, SELECT, UPDATE, DELETE, MERGE

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"
CATALOG_NAME="${ICEBERG_CATALOG:-my_catalog}"
WAREHOUSE_PATH="${ICEBERG_WAREHOUSE:-s3a://warehouse/}"

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
log_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; echo "$1" >> "$RESULTS_DIR/iceberg-failed.log"; ((FAILED++)) || true; }
log_skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((SKIPPED++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

check_minio() {
    MINIO_SVC=$(kubectl get svc -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$MINIO_SVC" ]]; then
        return 0
    fi
    return 1
}

get_minio_endpoint() {
    kubectl get svc -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "minio"
}

get_master_service() {
    echo "${RELEASE}-standalone-master"
}

echo "=============================================="
echo "ICEBERG CRUD TESTS"
echo "=============================================="
echo "Namespace:  $NAMESPACE"
echo "Release:    $RELEASE"
echo "Catalog:    $CATALOG_NAME"
echo "Warehouse:  $WAREHOUSE_PATH"
echo "Time:       $(date)"
echo ""

MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
    echo "Error: Spark master pod not found"
    exit 1
fi

log_info "Master pod: $MASTER_POD"

# Check MinIO availability
if ! check_minio; then
    log_info "MinIO not deployed - some tests will be skipped"
fi

MINIO_ENDPOINT=$(get_minio_endpoint)
MASTER_URL="spark://$(get_master_service):7077"

# === 1. Iceberg Configuration Check ===
log_info "=== 1. Iceberg Configuration ==="

echo -n "Testing: iceberg-catalog-config... "
ICEBERG_CONFIG=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
    ls /opt/spark/jars/ 2>/dev/null | grep -c iceberg || echo "0"
' 2>/dev/null || echo "0")

if [[ $ICEBERG_CONFIG -gt 0 ]]; then
    log_pass "iceberg-catalog-config ($ICEBERG_CONFIG jars)"
else
    log_skip "iceberg-catalog-config (Iceberg jars not found)"
fi

# === 2. CREATE TABLE ===
log_info "=== 2. CREATE TABLE ==="

cat > /tmp/iceberg-create-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("Iceberg-Create") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    spark.sql("CREATE DATABASE IF NOT EXISTS $CATALOG_NAME.crud_test")
    spark.sql("DROP TABLE IF EXISTS $CATALOG_NAME.crud_test.users")
    spark.sql("""
        CREATE TABLE $CATALOG_NAME.crud_test.users (
            id LONG,
            name STRING,
            age INT,
            created_at TIMESTAMP
        ) USING iceberg
        PARTITIONED BY (age)
    """)
    
    spark.stop()
    print("ICEBERG_CREATE_SUCCESS")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_CREATE_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-create-table... "
kubectl cp /tmp/iceberg-create-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-create-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-create-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_CREATE_SUCCESS"; then
    log_pass "iceberg-create-table"
else
    log_fail "iceberg-create-table"
    echo "$OUTPUT" | tail -20 >> "$RESULTS_DIR/iceberg-create.log"
fi

rm -f /tmp/iceberg-create-test.py

# === 3. INSERT ===
log_info "=== 3. INSERT ==="

cat > /tmp/iceberg-insert-test.py << PYEOF
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp

spark = SparkSession.builder \\
    .appName("Iceberg-Insert") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    from pyspark.sql.functions import col
    
    df = spark.range(100).select(
        col("id"),
        col("id").cast("string").alias("name"),
        (col("id") % 50 + 18).alias("age")
    ).withColumn("created_at", current_timestamp())
    
    df.writeTo("$CATALOG_NAME.crud_test.users").append()
    
    spark.stop()
    print("ICEBERG_INSERT_SUCCESS")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_INSERT_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-insert... "
kubectl cp /tmp/iceberg-insert-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-insert-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-insert-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_INSERT_SUCCESS"; then
    log_pass "iceberg-insert"
else
    log_fail "iceberg-insert"
fi

rm -f /tmp/iceberg-insert-test.py

# === 4. SELECT ===
log_info "=== 4. SELECT ==="

cat > /tmp/iceberg-select-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("Iceberg-Select") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    count = spark.sql("SELECT COUNT(*) as cnt FROM $CATALOG_NAME.crud_test.users").collect()[0]["cnt"]
    
    spark.stop()
    print(f"ICEBERG_SELECT_SUCCESS: {count} rows")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_SELECT_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-select... "
kubectl cp /tmp/iceberg-select-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-select-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-select-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_SELECT_SUCCESS"; then
    log_pass "iceberg-select"
else
    log_fail "iceberg-select"
fi

rm -f /tmp/iceberg-select-test.py

# === 5. UPDATE ===
log_info "=== 5. UPDATE ==="

cat > /tmp/iceberg-update-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("Iceberg-Update") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    spark.sql("UPDATE $CATALOG_NAME.crud_test.users SET name = 'updated' WHERE id < 10")
    
    updated = spark.sql("SELECT COUNT(*) as cnt FROM $CATALOG_NAME.crud_test.users WHERE name = 'updated'").collect()[0]["cnt"]
    
    spark.stop()
    print(f"ICEBERG_UPDATE_SUCCESS: {updated} rows updated")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_UPDATE_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-update... "
kubectl cp /tmp/iceberg-update-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-update-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-update-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_UPDATE_SUCCESS"; then
    log_pass "iceberg-update"
else
    log_fail "iceberg-update"
fi

rm -f /tmp/iceberg-update-test.py

# === 6. DELETE ===
log_info "=== 6. DELETE ==="

cat > /tmp/iceberg-delete-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("Iceberg-Delete") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    before = spark.sql("SELECT COUNT(*) as cnt FROM $CATALOG_NAME.crud_test.users").collect()[0]["cnt"]
    
    spark.sql("DELETE FROM $CATALOG_NAME.crud_test.users WHERE id >= 90")
    
    after = spark.sql("SELECT COUNT(*) as cnt FROM $CATALOG_NAME.crud_test.users").collect()[0]["cnt"]
    
    spark.stop()
    print(f"ICEBERG_DELETE_SUCCESS: {before} -> {after} rows")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_DELETE_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-delete... "
kubectl cp /tmp/iceberg-delete-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-delete-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-delete-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_DELETE_SUCCESS"; then
    log_pass "iceberg-delete"
else
    log_fail "iceberg-delete"
fi

rm -f /tmp/iceberg-delete-test.py

# === 7. MERGE ===
log_info "=== 7. MERGE ==="

cat > /tmp/iceberg-merge-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("Iceberg-Merge") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    spark.sql("DROP TABLE IF EXISTS $CATALOG_NAME.crud_test.updates")
    spark.sql("CREATE TABLE $CATALOG_NAME.crud_test.updates (id LONG, name STRING, age INT) USING iceberg")
    
    spark.sql("INSERT INTO $CATALOG_NAME.crud_test.updates VALUES (1, 'merged_name', 25), (100, 'new_user', 30)")
    
    spark.sql("""
        MERGE INTO $CATALOG_NAME.crud_test.users u
        USING $CATALOG_NAME.crud_test.updates s
        ON u.id = s.id
        WHEN MATCHED THEN UPDATE SET name = s.name, age = s.age
        WHEN NOT MATCHED THEN INSERT *
    """)
    
    spark.stop()
    print("ICEBERG_MERGE_SUCCESS")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_MERGE_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-merge... "
kubectl cp /tmp/iceberg-merge-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-merge-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-merge-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_MERGE_SUCCESS"; then
    log_pass "iceberg-merge"
else
    log_fail "iceberg-merge"
fi

rm -f /tmp/iceberg-merge-test.py

# === 8. Time Travel ===
log_info "=== 8. Time Travel ==="

cat > /tmp/iceberg-timetravel-test.py << PYEOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("Iceberg-TimeTravel") \\
    .master("$MASTER_URL") \\
    .config("spark.sql.catalog.$CATALOG_NAME", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.$CATALOG_NAME.type", "hadoop") \\
    .config("spark.sql.catalog.$CATALOG_NAME.warehouse", "$WAREHOUSE_PATH") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://${MINIO_ENDPOINT}:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .getOrCreate()

try:
    snapshots = spark.sql("SELECT snapshot_id FROM $CATALOG_NAME.crud_test.users.snapshots ORDER BY committed_at").collect()
    
    if len(snapshots) > 1:
        first_snapshot = snapshots[0]["snapshot_id"]
        count_historical = spark.sql(f"SELECT COUNT(*) as cnt FROM $CATALOG_NAME.crud_test.users VERSION AS OF {first_snapshot}").collect()[0]["cnt"]
        spark.stop()
        print(f"ICEBERG_TIMETRAVEL_SUCCESS: {len(snapshots)} snapshots, earliest had {count_historical} rows")
    else:
        spark.stop()
        print("ICEBERG_TIMETRAVEL_SUCCESS: 1 snapshot")
except Exception as e:
    spark.stop()
    print(f"ICEBERG_TIMETRAVEL_ERROR: {e}")
PYEOF

echo -n "Testing: iceberg-time-travel... "
kubectl cp /tmp/iceberg-timetravel-test.py $NAMESPACE/$MASTER_POD:/tmp/iceberg-timetravel-test.py 2>/dev/null

OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c '
DRIVER_HOST=$(hostname -i)
timeout 120 spark-submit --master spark://airflow-sc-standalone-master:7077 \
    --conf spark.driver.host=$DRIVER_HOST \
    --conf spark.driver.bindAddress=0.0.0.0 \
    /tmp/iceberg-timetravel-test.py 2>&1
' 2>&1) || true

if echo "$OUTPUT" | grep -q "ICEBERG_TIMETRAVEL_SUCCESS"; then
    log_pass "iceberg-time-travel"
else
    log_fail "iceberg-time-travel"
fi

rm -f /tmp/iceberg-timetravel-test.py

# === Summary ===
echo ""
echo "=============================================="
echo "ICEBERG CRUD TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

echo "iceberg,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/iceberg-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/iceberg-failed.log"
    exit 1
else
    echo "All Iceberg CRUD tests passed!"
    exit 0
fi
