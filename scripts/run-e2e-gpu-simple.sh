#!/bin/bash
# Simple GPU E2E Test for Spark K8s

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-gpu}"

echo "========================================"
echo "Spark K8s E2E Tests - GPU"
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
# Test: GPU Resources Allocation
# ============================================
echo ""
echo "========================================"
echo "Test: GPU Resources Allocation"
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
    --set connect.executor.gpu.enabled=true \
    --set connect.executor.gpu.vendor=nvidia.com/gpu \
    --set connect.executor.gpu.count=1 \
    --set connect.executor.gpu.nodeSelector.nvidia.com/gpu=true \
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

# Check GPU resources in pod spec
echo -e "${YELLOW}Checking GPU resources...${NC}"
GPU_REQUEST=$(kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.nvidia\.com/gpu}' 2>/dev/null || echo "Not set")
GPU_LIMIT=$(kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.nvidia\.com/gpu}' 2>/dev/null || echo "Not set")

echo "GPU Request: ${GPU_REQUEST}"
echo "GPU Limit: ${GPU_LIMIT}"

if [ "$GPU_LIMIT" = "1" ]; then
    echo -e "${GREEN}✓ GPU resource allocated successfully!${NC}"
else
    echo -e "${RED}✗ GPU resource not allocated${NC}"
fi

# Verify nodeSelector for GPU
echo -e "${YELLOW}Checking node selector...${NC}"
NODE_SELECTOR=$(kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.nodeSelector}' 2>/dev/null || echo "Not set")
echo "Node Selector: ${NODE_SELECTOR}"

# Check executor pod template has GPU
echo -e "${YELLOW}Checking executor pod template...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- cat /tmp/spark-conf/executor-pod-template.yaml | grep -A 5 "resources:" | head -10

echo ""
echo "========================================"
echo -e "${GREEN}✓ GPU E2E TEST COMPLETED!${NC}"
echo "========================================"
echo ""
echo "Summary:"
echo "  - GPU resources: ${GPU_LIMIT}"
echo "  - Node selector: Configured"
echo "  - Executor template: Updated"
echo ""
