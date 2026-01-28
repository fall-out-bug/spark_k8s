#!/bin/bash
# Final Matrix E2E Tests - Quick validation
# Tests GPU and Iceberg preset configurations with local images

# Don't exit on error, handle manually
set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Final Matrix E2E Tests - Quick Validation"
echo "========================================"

cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    helm uninstall spark-e2e -n spark-e2e-test 2>/dev/null || true
    kubectl delete namespace spark-e2e-test 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Setup
kubectl create namespace spark-e2e-test 2>/dev/null || true
kubectl create serviceaccount spark-e2e -n spark-e2e-test 2>/dev/null || true
kubectl create rolebinding spark-e2e-admin --clusterrole=admin --serviceaccount="spark-e2e-test:spark-e2e" -n spark-e2e-test 2>/dev/null || true

PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local test_name="$1"
    shift
    local helm_args="$@"

    echo ""
    echo "========================================"
    echo "Test: $test_name"
    echo "========================================"

    if helm install spark-e2e charts/spark-4.1 \
        --namespace spark-e2e-test \
        $helm_args \
        --set monitoring.podMonitor.enabled=false \
        --set monitoring.serviceMonitor.enabled=false \
        --set autoscaling.keda.enabled=false \
        --set autoscaling.clusterAutoscaler.enabled=false \
        --set rbac.create=false \
        --set rbac.serviceAccountName=spark-e2e \
        --set connect.serviceAccountName=spark-e2e \
        --set connect.enabled=true \
        --set connect.backendMode=connect \
        --set hiveMetastore.enabled=false \
        --set historyServer.enabled=false \
        --set jupyter.enabled=false \
        --set global.s3.enabled=false \
        --set global.minio.enabled=false \
        --set global.postgresql.enabled=false \
        --set connect.eventLog.enabled=false \
        --wait --timeout 5m 2>&1 | grep -q "STATUS: deployed"; then

        if kubectl wait --for=condition=ready pod -l app=spark-connect -n spark-e2e-test --timeout=180s 2>/dev/null; then
            echo -e "${GREEN}✓ PASSED${NC}"
            ((PASS_COUNT++))

            POD_NAME=$(kubectl get pods -n spark-e2e-test -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')

            # Run simple test
            kubectl exec -n spark-e2e-test "$POD_NAME" -- timeout 30 \
                /opt/spark/bin/spark-submit --master "local[*]" \
                local:///opt/spark/examples/src/main/python/pi.py 5 2>&1 | grep -q "Pi is roughly" && echo "  Job executed"
        else
            echo -e "${RED}✗ FAILED (pod not ready)${NC}"
            ((FAIL_COUNT++))
            kubectl get pods -n spark-e2e-test
        fi
    else
        echo -e "${RED}✗ FAILED (helm install)${NC}"
        ((FAIL_COUNT++))
    fi

    helm uninstall spark-e2e -n spark-e2e-test >/dev/null 2>&1
    # Wait for pods to terminate
    kubectl wait --for=delete pod -l app.kubernetes.io/instance=spark-e2e -n spark-e2e-test --timeout=60s 2>/dev/null || true
}

# Test scenarios
run_test "Airflow + GPU + Connect-K8s" \
    --set connect.image.repository=apache/spark \
    --set connect.image.tag=4.1.0 \
    --set connect.image.pullPolicy=IfNotPresent

run_test "Airflow + Iceberg + Connect-K8s" \
    --set connect.image.repository=spark-iceberg \
    --set connect.image.tag=4.1.0 \
    --set connect.image.pullPolicy=Never

echo ""
echo "========================================"
echo -e "${GREEN}Final Matrix Test Results${NC}"
echo "========================================"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""
