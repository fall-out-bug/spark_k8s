#!/bin/bash
# Simple Jupyter Deployment Test

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-jupyter}"

echo "========================================"
echo "Jupyter Deployment Test"
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

echo -e "${YELLOW}Deploying Spark with Jupyter (no --wait)...${NC}"

# Deploy without --wait to avoid timeout
helm install spark-e2e charts/spark-4.1 \
    --namespace "$TEST_NAMESPACE" \
    --set rbac.create=false \
    --set rbac.serviceAccountName=default \
    --set connect.enabled=true \
    --set jupyter.enabled=true \
    --set jupyter.image.repository=jupyter/base-notebook \
    --set jupyter.image.tag=python-3.11 \
    --set jupyter.resources.requests.memory=256Mi \
    --set jupyter.resources.requests.cpu=100m \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set global.s3.enabled=false \
    --set connect.eventLog.enabled=false \
    --timeout 10m 2>&1 | tail -10

echo -e "${YELLOW}Waiting for Spark Connect pod...${NC}"
kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s

echo -e "${YELLOW}Waiting for Jupyter pod...${NC}"
kubectl wait --for=condition=ready pod -l app=jupyter -n "$TEST_NAMESPACE" --timeout=300s || {
    echo -e "${RED}Jupyter pod not ready${NC}"
    kubectl get pods -n "$TEST_NAMESPACE"
    exit 1
}

POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=jupyter -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "========================================"
echo "Jupyter Verification"
echo "========================================"

echo -e "${YELLOW}1. Pod status:${NC}"
kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE"

echo -e "${YELLOW}2. Environment:${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- env | grep -E "JUPYTER|SPARK|HOME" | head -5

echo -e "${YELLOW}3. Python version:${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- python3 --version

echo -e "${YELLOW}4. Jupyter service:${NC}"
kubectl get svc -n "$TEST_NAMESPACE" -l app=jupyter

echo ""
echo "========================================"
echo -e "${GREEN}✓ Jupyter Deployment Successful${NC}"
echo "========================================"
echo ""
echo "To access:"
echo "  kubectl port-forward -n $TEST_NAMESPACE svc/spark-e2e-spark-41-jupyter 8888:8888"
echo "  Open http://localhost:8888"
echo ""
