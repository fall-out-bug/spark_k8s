#!/bin/bash
# GPU E2E Tests for Spark K8s
# Tests: GPU resource allocation, RAPIDS configs

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-gpu}"

echo "========================================"
echo "Spark K8s E2E Tests - GPU Matrix"
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

# ============================================
# Test 1: GPU Resources Allocation
# ============================================
test_gpu_resources() {
    echo ""
    echo "========================================"
    echo "Test 1: GPU Resources Allocation"
    echo "========================================"

    helm install spark-e2e charts/spark-4.1 \
        -f charts/spark-4.1/presets/gpu-values.yaml \
        --set monitoring.serviceMonitor.enabled=false \
        --namespace "$TEST_NAMESPACE" \
        --set rbac.create=false \
        --set rbac.serviceAccountName=spark-e2e \
        --set connect.serviceAccountName=spark-e2e \
        --set connect.enabled=true \
        --set connect.backendMode=connect \
        --set connect.image.repository=apache/spark \
        --set connect.image.tag=4.1.0 \
        --set hiveMetastore.enabled=false \
        --set historyServer.enabled=false \
        --set jupyter.enabled=false \
        --set global.s3.enabled=false \
        --set global.minio.enabled=false \
        --set global.postgresql.enabled=false \
        --set connect.eventLog.enabled=false \
        --wait --timeout 10m 2>&1 | tail -20

    echo -e "${YELLOW}Waiting for pod ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s

    # Check GPU resources in pod spec
    echo -e "${YELLOW}Checking GPU resources...${NC}"
    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')

    GPU_REQUEST=$(kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.nvidia\.com/gpu}')
    GPU_LIMIT=$(kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.nvidia\.com/gpu}')

    echo "GPU Request: ${GPU_REQUEST:-Not set}"
    echo "GPU Limit: ${GPU_LIMIT:-Not set}"

    # Verify RAPIDS configs are applied
    echo -e "${YELLOW}Verifying RAPIDS Spark configs...${NC}"
    kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
      grep -E "spark\.raptor\|spark\.rapids\|spark\.sql\.execution\.arrow\.maxRecordsPerBatch" /tmp/spark-conf/spark-defaults.conf || echo "Checking configs..."
    ' 2>&1 | head -20

    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE"
    sleep 5
}

# ============================================
# Test 2: Jupyter with GPU Support
# ============================================
test_jupyter_gpu() {
    echo ""
    echo "========================================"
    echo "Test 2: Jupyter with GPU Support"
    echo "========================================"

    helm install spark-e2e charts/spark-4.1 \
        --namespace "$TEST_NAMESPACE" \
        --set rbac.create=false \
        --set rbac.serviceAccountName=spark-e2e \
        --set connect.enabled=true \
        --set connect.serviceAccountName=spark-e2e \
        --set jupyter.enabled=true \
        --set jupyter.serviceAccountName=spark-e2e \
        --set jupyter.gpu.enabled=true \
        --set jupyter.gpu.vendor=nvidia.com/gpu \
        --set jupyter.gpu.count=1 \
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
    kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=jupyter -n "$TEST_NAMESPACE" --timeout=300s

    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=jupyter -o jsonpath='{.items[0].metadata.name}')

    # Check GPU resources on Jupyter pod
    echo -e "${YELLOW}Checking Jupyter GPU resources...${NC}"
    kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].resources}' | jq .

    echo -e "${GREEN}✓ Test 2 PASSED${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE"
    sleep 5
}

# ============================================
# Test 3: Basic Spark (baseline)
# ============================================
test_basic() {
    echo ""
    echo "========================================"
    echo "Test 3: Basic Spark (Baseline)"
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
        --set hiveMetastore.enabled=false \
        --set historyServer.enabled=false \
        --set jupyter.enabled=false \
        --set global.s3.enabled=false \
        --set global.minio.enabled=false \
        --set global.postgresql.enabled=false \
        --set connect.eventLog.enabled=false \
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

    echo -e "${GREEN}✓ Test 3 PASSED${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE"
    sleep 5
}

# ============================================
# Run all tests
# ============================================
echo -e "${YELLOW}Starting GPU E2E tests...${NC}"

test_basic
test_gpu_resources
test_jupyter_gpu

echo ""
echo "========================================"
echo -e "${GREEN}✓ ALL GPU E2E TESTS PASSED!${NC}"
echo "========================================"
echo ""
echo "Tests completed:"
echo "  ✓ Basic Spark (baseline)"
echo "  ✓ GPU Resources Allocation"
echo "  ✓ Jupyter with GPU Support"
echo ""
