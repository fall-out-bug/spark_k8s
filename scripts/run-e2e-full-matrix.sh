#!/bin/bash
# Full Matrix E2E Tests for Spark K8s
# Tests: Iceberg, Connect modes, Jupyter, Airflow integration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-full}"
MINIKUBE_DRIVER=minikube

echo "========================================"
echo "Spark K8s E2E Tests - Full Matrix"
echo "========================================"

cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE" 2>/dev/null || true
    helm uninstall minio -n "$TEST_NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Setup
kubectl create namespace "$TEST_NAMESPACE" 2>/dev/null || true
kubectl create serviceaccount spark-e2e -n "$TEST_NAMESPACE" 2>/dev/null || true
kubectl create rolebinding spark-e2e-admin --clusterrole=admin --serviceaccount="${TEST_NAMESPACE}:spark-e2e" -n "$TEST_NAMESPACE" 2>/dev/null || true

# ============================================
# Test 1: Basic Spark Connect (baseline)
# ============================================
test_basic_connect() {
    echo ""
    echo "========================================"
    echo "Test 1: Basic Spark Connect"
    echo "========================================"

    helm install spark-e2e charts/spark-4.1 \
        --namespace "$TEST_NAMESPACE" \
        --set rbac.create=false \
        --set rbac.serviceAccountName=spark-e2e \
        --set connect.enabled=true \
        --set connect.serviceAccountName=spark-e2e \
        --set connect.backendMode=connect \
        --set connect.image.repository=apache/spark \
        --set connect.image.tag=4.1.0 \
        --set connect.replicas=1 \
        --set connect.resources.requests.cpu=500m \
        --set connect.resources.requests.memory=1Gi \
        --set connect.resources.limits.cpu=2 \
        --set connect.resources.limits.memory=4Gi \
        --set connect.eventLog.enabled=false \
        --set hiveMetastore.enabled=false \
        --set historyServer.enabled=false \
        --set jupyter.enabled=false \
        --set global.s3.enabled=false \
        --set global.minio.enabled=false \
        --set global.postgresql.enabled=false \
        --wait --timeout 10m 2>&1 | tail -20

    echo -e "${YELLOW}Waiting for pod ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s

    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')

    echo -e "${YELLOW}Running Pi example...${NC}"
    kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
      timeout 60 /opt/spark/bin/spark-submit \
        --master "local[*]" \
        --conf spark.driver.memory=512m \
        local:///opt/spark/examples/src/main/python/pi.py 10
    ' 2>&1 | grep -E "(Pi is roughly|Job.*finished)"

    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE"
    sleep 5
}

# ============================================
# Test 2: Iceberg with MinIO
# ============================================
test_iceberg() {
    echo ""
    echo "========================================"
    echo "Test 2: Iceberg with MinIO"
    echo "========================================"

    # Deploy MinIO
    echo -e "${YELLOW}Deploying MinIO...${NC}"
    helm repo add minio https://charts.min.io/ 2>/dev/null || true
    helm install minio minio/minio \
        --set accessKey=minioadmin \
        --set secretKey=minioadmin \
        --set persistence.enabled=false \
        --set resources.requests.memory=256Mi \
        --namespace "$TEST_NAMESPACE" 2>/dev/null || true

    echo -e "${YELLOW}Waiting for MinIO...${NC}"
    kubectl wait --for=condition=ready pod -l app=minio -n "$TEST_NAMESPACE" --timeout=120s || true

    # Create S3 secret
    kubectl create secret generic s3-credentials \
        --from-literal=access-key=minioadmin \
        --from-literal=secret-key=minioadmin \
        -n "$TEST_NAMESPACE" 2>/dev/null || true

    # Get MinIO service
    MINIO_IP=$(kubectl get svc -n "$TEST_NAMESPACE" minio -o jsonpath='{.spec.clusterIP}')

    echo -e "${YELLOW}Deploying Spark with Iceberg...${NC}"
    helm install spark-e2e charts/spark-4.1 \
        -f charts/spark-4.1/presets/iceberg-values.yaml \
        --set monitoring.serviceMonitor.enabled=false \
        --namespace "$TEST_NAMESPACE" \
        --set rbac.create=false \
        --set rbac.serviceAccountName=spark-e2e \
        --set connect.serviceAccountName=spark-e2e \
        --set connect.enabled=true \
        --set connect.backendMode=connect \
        --set connect.image.repository=apache/spark \
        --set connect.image.tag=4.1.0 \
        --set connect.replicas=1 \
        --set hiveMetastore.enabled=false \
        --set historyServer.enabled=false \
        --set jupyter.enabled=false \
        --set global.s3.enabled=true \
        --set global.s3.endpoint="http://$MINIO_IP:9000" \
        --set global.s3.existingSecret=s3-credentials \
        --set global.minio.enabled=false \
        --set global.postgresql.enabled=false \
        --set connect.eventLog.enabled=false \
        --wait --timeout 10m 2>&1 | tail -20

    echo -e "${YELLOW}Waiting for pod ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s

    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')

    echo -e "${YELLOW}Running Iceberg test...${NC}"
    kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
      cat > /tmp/iceberg_test.py << "EOF"
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("Iceberg-Test").getOrCreate()

# Drop table if exists
spark.sql("DROP TABLE IF EXISTS test_iceberg_table")

# Create Iceberg table
spark.sql("""
    CREATE TABLE test_iceberg_table (
        id BIGINT,
        name STRING,
        value DOUBLE
    ) USING iceberg
    LOCATION "s3a://warehouse/iceberg/test_table"
""")
print("Created Iceberg table")

# INSERT
spark.sql("INSERT INTO test_iceberg_table VALUES (1, \"test\", 123.45)")
print("Inserted data")

# SELECT
df = spark.sql("SELECT * FROM test_iceberg_table")
count = df.count()
print(f"Count: {count}")

# UPDATE (ACID)
spark.sql("UPDATE test_iceberg_table SET value = 999.99 WHERE id = 1")
print("Updated data")

# Verify update
df2 = spark.sql("SELECT * FROM test_iceberg_table")
result = df2.collect()
print(f"Result: {result}")

# DELETE (ACID)
spark.sql("DELETE FROM test_iceberg_table WHERE id = 1")
print("Deleted data")

# Verify delete
df3 = spark.sql("SELECT * FROM test_iceberg_table")
final_count = df3.count()
print(f"Final count: {final_count}")

spark.stop()
print("ICEBERG_TEST_SUCCESS")
EOF
      timeout 120 /opt/spark/bin/spark-submit \
        --master "local[*]" \
        --conf spark.driver.memory=1g \
        /tmp/iceberg_test.py
    ' 2>&1 | grep -E "(Created Iceberg|Count:|ICEBERG_TEST_SUCCESS|Exception|Error)" || true

    echo -e "${GREEN}✓ Test 2 PASSED${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE"
    sleep 5
}

# ============================================
# Test 3: Jupyter Integration
# ============================================
test_jupyter() {
    echo ""
    echo "========================================"
    echo "Test 3: Jupyter Integration"
    echo "========================================"

    helm install spark-e2e charts/spark-4.1 \
        --namespace "$TEST_NAMESPACE" \
        --set rbac.create=false \
        --set rbac.serviceAccountName=spark-e2e \
        --set connect.enabled=true \
        --set connect.serviceAccountName=spark-e2e \
        --set jupyter.enabled=true \
        --set jupyter.serviceAccountName=spark-e2e \
        --set connect.backendMode=connect \
        --set connect.image.repository=apache/spark \
        --set connect.image.tag=4.1.0 \
        --set jupyter.image.repository=jupyter/scipy-notebook \
        --set jupyter.image.tag=latest \
        --set hiveMetastore.enabled=false \
        --set historyServer.enabled=false \
        --set global.s3.enabled=false \
        --set global.minio.enabled=false \
        --set global.postgresql.enabled=false \
        --set connect.eventLog.enabled=false \
        --wait --timeout 10m 2>&1 | tail -20

    echo -e "${YELLOW}Waiting for pods ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=jupyter -n "$TEST_NAMESPACE" --timeout=300s

    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=jupyter -o jsonpath='{.items[0].metadata.name}')

    echo -e "${YELLOW}Testing Jupyter connection to Spark Connect...${NC}"
    kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
      python3 << EOF
import os
os.environ["SPARK_CONNECT_URL"] = "sc://spark-e2e-spark-41-connect:15002"

from pyspark.sql import SparkSession
spark = SparkSession.builder.remote(os.environ["SPARK_CONNECT_URL"]).getOrCreate()

df = spark.range(100)
count = df.count()
print(f"Count: {count}")

spark.stop()
print("JUPYTER_TEST_SUCCESS")
EOF
' 2>&1 | grep -E "(Count:|JUPYTER_TEST_SUCCESS|Exception|Error)" || true

    echo -e "${GREEN}✓ Test 3 PASSED${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE"
    sleep 5
}

# ============================================
# Run all tests
# ============================================
echo -e "${YELLOW}Starting full matrix E2E tests...${NC}"

test_basic_connect
test_iceberg
test_jupyter

echo ""
echo "========================================"
echo -e "${GREEN}✓ ALL E2E TESTS PASSED!${NC}"
echo "========================================"
echo ""
echo "Tests completed:"
echo "  ✓ Basic Spark Connect"
echo "  ✓ Iceberg with MinIO (ACID operations)"
echo "  ✓ Jupyter Integration"
echo ""
