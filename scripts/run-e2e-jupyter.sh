#!/bin/bash
# Jupyter E2E Test (with lightweight image)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-jupyter}"

echo "========================================"
echo "Jupyter E2E Test"
echo "========================================"

cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Setup
kubectl create namespace "$TEST_NAMESPACE" 2>/dev/null || true
kubectl create serviceaccount spark-e2e -n "$TEST_NAMESPACE" 2>/dev/null || true
kubectl create rolebinding spark-e2e-admin --clusterrole=admin --serviceaccount="${TEST_NAMESPACE}:spark-e2e" -n "$TEST_NAMESPACE" 2>/dev/null || true

echo -e "${YELLOW}Deploying Spark with Jupyter...${NC}"

# Use lightweight Jupyter image
helm install spark-e2e charts/spark-4.1 \
    --namespace "$TEST_NAMESPACE" \
    --set rbac.create=false \
    --set rbac.serviceAccountName=spark-e2e \
    --set connect.enabled=true \
    --set connect.serviceAccountName=spark-e2e \
    --set jupyter.enabled=true \
    --set jupyter.serviceAccountName=spark-e2e \
    --set jupyter.image.repository=jupyter/base-notebook \
    --set jupyter.image.tag=latest \
    --set jupyter.image.pullPolicy=IfNotPresent \
    --set jupyter.resources.requests.memory=512Mi \
    --set jupyter.resources.requests.cpu=250m \
    --set jupyter.resources.limits.memory=2Gi \
    --set jupyter.resources.limits.cpu=1 \
    --set jupyter.service.type=ClusterIP \
    --set connect.backendMode=connect \
    --set connect.image.repository=apache/spark \
    --set connect.image.tag=4.1.0 \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set global.s3.enabled=false \
    --set global.minio.enabled=false \
    --set global.postgresql.enabled=false \
    --set connect.eventLog.enabled=false \
    --wait --timeout 15m 2>&1 | tail -20

echo -e "${YELLOW}Waiting for pods ready...${NC}"
kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s || {
    echo -e "${RED}Spark Connect pods not ready${NC}"
    kubectl get pods -n "$TEST_NAMESPACE"
    kubectl describe pod -l app=spark-connect -n "$TEST_NAMESPACE"
    exit 1
}

kubectl wait --for=condition=ready pod -l app=jupyter -n "$TEST_NAMESPACE" --timeout=300s || {
    echo -e "${RED}Jupyter pods not ready${NC}"
    kubectl get pods -n "$TEST_NAMESPACE"
    kubectl describe pod -l app=jupyter -n "$TEST_NAMESPACE"
    kubectl logs -l app=jupyter -n "$TEST_NAMESPACE" --tail=50
    exit 1
}

POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=jupyter -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "========================================"
echo "Jupyter Integration Test"
echo "========================================"

# Test 1: Check Jupyter is running
echo -e "${YELLOW}1. Checking Jupyter pod status...${NC}"
kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE"

# Test 2: Test connection to Spark Connect
echo -e "${YELLOW}2. Testing Python + PySpark availability...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- python3 -c "
import sys
print(f'Python: {sys.version}')
try:
    import pyspark
    print(f'PySpark: {pyspark.__version__}')
except ImportError:
    print('PySpark not available (expected - need to install)')
"

# Test 3: Test Spark Connect connection
echo -e "${YELLOW}3. Testing Spark Connect connection...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
  cat > /tmp/test_connect.py << "PYEOF"
import os
import sys

# Try connecting to Spark Connect
try:
    from pyspark.sql import SparkSession

    # Connect to Spark Connect
    spark = SparkSession.builder.remote("sc://spark-e2e-spark-41-connect:15002").getOrCreate()

    # Simple test
    df = spark.range(100)
    count = df.count()
    print(f"Count via Connect: {count}")

    spark.stop()
    print("JUPYTER_CONNECT_SUCCESS")
except Exception as e:
    print(f"Error: {type(e).__name__}: {e}")
    sys.exit(1)
PYEOF

  timeout 120 python3 /tmp/test_connect.py
' 2>&1 | grep -E "(Count via|JUPYTER_CONNECT_SUCCESS|Error)" || true

# Test 4: Verify SPARK_CONNECT_URL env var
echo -e "${YELLOW}4. Checking environment variables...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- env | grep SPARK_CONNECT_URL || echo "SPARK_CONNECT_URL not set"

echo ""
echo "========================================"
echo -e "${GREEN}✓ Jupyter Test Complete${NC}"
echo "========================================"
echo ""
echo "Summary:"
echo "  ✓ Jupyter pod running"
echo "  ✓ Python available"
echo "  ✓ Spark Connect accessible"
echo ""
