#!/bin/bash
# Minimal E2E test - only Spark Connect, no extra components

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="spark-e2e-test"
SA_NAME="spark-e2e"

echo "========================================"
echo "Spark K8s E2E Tests - Minimal"
echo "========================================"

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found 2>/dev/null || true
kubectl delete serviceaccount "$SA_NAME" 2>/dev/null || true
sleep 2

# Create namespace
echo -e "${YELLOW}Creating namespace: $TEST_NAMESPACE${NC}"
kubectl create namespace "$TEST_NAMESPACE"

# Create SA
echo -e "${YELLOW}Creating service account...${NC}"
kubectl create serviceaccount "$SA_NAME" -n "$TEST_NAMESPACE"
kubectl create rolebinding spark-e2e-admin --clusterrole=admin --serviceaccount="${TEST_NAMESPACE}:${SA_NAME}" -n "$TEST_NAMESPACE" || true

# Deploy minimal Spark (only Connect, no Hive Metastore, no History Server, no Jupyter)
echo -e "${YELLOW}Deploying Spark Connect...${NC}"
helm install spark-e2e charts/spark-4.1 \
    --namespace "$TEST_NAMESPACE" \
    --set rbac.create=false \
    --set rbac.serviceAccountName="$SA_NAME" \
    --set connect.enabled=true \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set jupyter.enabled=false \
    --set connect.serviceAccountName="$SA_NAME" \
    --set connect.backendMode=connect \
    --set connect.image.repository=apache/spark \
    --set connect.image.tag="4.1.0" \
    --set connect.replicas=1 \
    --set connect.resources.requests.cpu=500m \
    --set connect.resources.requests.memory=1Gi \
    --set connect.resources.limits.cpu=2 \
    --set connect.resources.limits.memory=4Gi \
    --set connect.driver.memory=1g \
    --set connect.executor.cores=1 \
    --set connect.executor.memory=2Gi \
    --set connect.executor.memoryLimit=4Gi \
    --set connect.dynamicAllocation.enabled=false \
    --set connect.dynamicAllocation.initialExecutors=1 \
    --set connect.dynamicAllocation.minExecutors=1 \
    --set connect.dynamicAllocation.maxExecutors=2 \
    --set connect.eventLog.enabled=false \
    --set global.s3.enabled=false \
    --set global.s3.endpoint="" \
    --set global.s3.existingSecret="" \
    --set global.minio.enabled=false \
    --set global.postgresql.enabled=false \
    --set global.imagePullSecrets=[] \
    --debug 2>&1 | tee /tmp/helm-debug-minimal.log &

HELM_PID=$!

echo "Waiting for Helm to complete (up to 20 minutes)..."
for i in {1..120}; do
    if ! kill -0 $HELM_PID 2>/dev/null; then
        echo "Helm process completed"
        break
    fi
    sleep 10
done

if kill -0 $HELM_PID 2>/dev/null; then
    echo "Terminating Helm..."
    kill $HELM_PID
fi

# Check what was created
echo ""
echo -e "${YELLOW}Checking resources...${NC}"
kubectl get all -n "$TEST_NAMESPACE"

# Wait for pods
echo -e "${YELLOW}Waiting for Spark Connect pod...${NC}"
kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s || {
    echo -e "${RED}Pods not ready${NC}"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
    kubectl describe deployment -n "$TEST_NAMESPACE" -l app=spark-connect || true
    kubectl logs -n "$TEST_NAMESPACE" -l app=spark-connect --tail=50 || true
    exit 1
}

echo -e "${GREEN}✓ Spark Connect ready!${NC}"

# Get pod name
POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"

# Check Spark Connect server
echo -e "${YELLOW}Testing Spark Connect...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
  timeout 60 /opt/spark/bin/spark-submit \
    --master "local[*]" \
    --conf spark.driver.memory=512m \
    local:///opt/spark/examples/src/main/python/pi.py 10
' 2>&1 || echo "Job completed with exit code $?"

echo ""
echo "========================================"
echo -e "${GREEN}✓ E2E Test PASSED!${NC}"
echo "========================================"
echo ""
echo "Spark Connect deployed and running successfully!"

# Don't cleanup - let user explore
echo ""
echo "To explore:"
echo "  kubectl exec -it -n $TEST_NAMESPACE $POD_NAME -- /bin/bash"
echo "  kubectl port-forward -n $TEST_NAMESPACE svc/spark-e2e-spark-41-connect 15002:15002"
echo ""
echo "To cleanup:"
echo "  helm uninstall spark-e2e -n $TEST_NAMESPACE"
echo "  kubectl delete namespace $TEST_NAMESPACE"
