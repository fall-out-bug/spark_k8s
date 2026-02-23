#!/bin/bash
# Simplified E2E test - manual execution

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="spark-e2e-test"
SA_NAME="spark-dev"

echo "========================================"
echo "Spark K8s E2E Tests - Manual"
echo "========================================"

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found --timeout=5s &> /dev/null || true
sleep 2

# Create namespace
echo -e "${YELLOW}Creating namespace: $TEST_NAMESPACE${NC}"
kubectl create namespace "$TEST_NAMESPACE"

# Create SA
echo -e "${YELLOW}Creating service account...${NC}"
kubectl create serviceaccount "$SA_NAME" -n "$TEST_NAMESPACE" || true

# Deploy Spark
echo -e "${YELLOW}Deploying Spark...${NC}"
helm install spark-e2e charts/spark-4.1 \
    -f charts/spark-4.1/environments/dev/values.yaml \
    --namespace "$TEST_NAMESPACE" \
    --set rbac.create=false \
    --set rbac.serviceAccountName="$SA_NAME" \
    --set connect.serviceAccountName="$SA_NAME" \
    --set connect.image.repository=apache/spark \
    --set connect.image.tag="4.1.0" \
    --debug &> /tmp/helm-debug.log &

# Wait for deployment in background
HELM_PID=$!

echo "Waiting for Helm to complete (up to 20 minutes)..."
for i in {1..120}; do
    if ! kill -HELM_PID 2>/dev/null; then
        echo "Helm process completed"
        break
    fi

    # Check if deployment succeeded
    if kubectl get deployment spark-e2e-spark-41-connect -n "$TEST_NAMESPACE" &> /dev/null; then
        echo "Deployment created successfully!"
        break
    fi

    echo "Waiting... ($i/120)"
    sleep 10
done

# Wait a bit more
if kill -HELM_PID 2>/dev/null; then
    echo "Helm still running, killing..."
    kill $HELM_PID
fi

# Check pods
echo -e "${YELLOW}Checking pods...${NC}"
kubectl get pods -n "$TEST_NAMESPACE"

# Wait for pods ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=600s || {
    echo -e "${RED}Pods not ready${NC}"
    kubectl describe pods -n "$TEST_NAMESPACE"
    exit 1
}

echo -e "${GREEN}✓ Pods ready!${NC}"

# Get pod name
POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_NAME"

# Run simple job
echo -e "${YELLOW}Running Spark job...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- \
    /opt/spark/bin/spark-submit \
    --master local[*] \
    --conf spark.driver.memory=512m \
    local:///opt/spark/examples/src/main/python/pi.py 10

echo ""
echo "========================================"
echo -e "${GREEN}E2E Test PASSED!${NC}"
echo "========================================"

# Cleanup
echo ""
echo "Cleaning up..."
helm uninstall spark-e2e -n "$TEST_NAMESPACE"
kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found
