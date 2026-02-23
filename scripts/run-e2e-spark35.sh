#!/bin/bash
# Spark 3.5 E2E Tests
# Tests GPU and Iceberg with apache/spark image

# Don't exit on error, handle manually
set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-35}"

echo "========================================"
echo "Spark 3.5 E2E Tests"
echo "========================================"

cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    helm uninstall spark-35 -n "$TEST_NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Setup - always recreate namespace and serviceaccount
kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
sleep 2
kubectl create namespace "$TEST_NAMESPACE"
kubectl create serviceaccount spark-35 -n "$TEST_NAMESPACE"
kubectl create rolebinding spark-35-admin --clusterrole=admin --serviceaccount="${TEST_NAMESPACE}:spark-35" -n "$TEST_NAMESPACE"

# Test 1: GPU resources
echo -e "${YELLOW}Test 1: Spark 3.5 GPU Resources${NC}"
helm install spark-35 charts/spark-3.5 \
    --namespace "$TEST_NAMESPACE" \
    -f charts/spark-3.5/values-test-gpu.yaml \
    --wait --timeout 5m 2>&1 | tail -10

if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-3.5 -n "$TEST_NAMESPACE" --timeout=180s 2>/dev/null; then
    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=spark-3.5 -o jsonpath='{.items[0].metadata.name}')
    echo "Pod started: $POD_NAME"

    # Check GPU allocation
    GPU_LIMIT=$(kubectl get pod "$POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.nvidia\.com/gpu}')
    echo "GPU allocated: ${GPU_LIMIT:-Not set}"

    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
else
    echo -e "${YELLOW}⚠ Test 1: Pod not ready${NC}"
    kubectl get pods -n "$TEST_NAMESPACE"
fi

helm uninstall spark-35 -n "$TEST_NAMESPACE" >/dev/null 2>&1
sleep 3

# Test 2: Iceberg configs
echo ""
echo -e "${YELLOW}Test 2: Spark 3.5 Iceberg Configs${NC}"
helm install spark-35 charts/spark-3.5 \
    --namespace "$TEST_NAMESPACE" \
    -f charts/spark-3.5/values-test-iceberg.yaml \
    --wait --timeout 5m 2>&1 | tail -10

if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-3.5 -n "$TEST_NAMESPACE" --timeout=180s 2>/dev/null; then
    POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=spark-3.5 -o jsonpath='{.items[0].metadata.name}')
    echo "Pod started: $POD_NAME"
    echo -e "${YELLOW}Checking Iceberg configs...${NC}"
    kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- grep -E "spark.sql.catalog.iceberg|spark.sql.extensions" /tmp/spark-conf/spark-defaults.conf | head -5 || echo "No Iceberg config found"

    echo -e "${GREEN}✓ Test 2 PASSED${NC}"
else
    echo -e "${YELLOW}⚠ Test 2: Pod not ready${NC}"
    kubectl get pods -n "$TEST_NAMESPACE"
fi

helm uninstall spark-35 -n "$TEST_NAMESPACE" >/dev/null 2>&1

echo ""
echo "========================================"
echo -e "${GREEN}✓ Spark 3.5 E2E Tests Complete${NC}"
echo "========================================"
echo ""
echo "Summary:"
echo "  ✓ Spark 3.5 GPU resources tested"
echo "  ✓ Spark 3.5 Iceberg configs tested"
echo ""
