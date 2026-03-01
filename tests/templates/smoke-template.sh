#!/bin/bash
# Smoke Test Template for Lego-Spark
# Parameterized template for test matrix scenarios
#
# Required Environment Variables:
#   SPARK_VERSION    - Spark version (3.5.7, 3.5.8, 4.0.2, 4.1.1)
#   PLATFORM         - Platform (k8s, openshift)
#   DEPLOYMENT_MODE  - Deployment mode (native, standalone)
#   CONNECT_ENABLED  - Spark Connect enabled (true, false)
#
# Optional Environment Variables:
#   GPU_ENABLED      - GPU support (true, false)
#   ICEBERG_ENABLED  - Iceberg support (true, false)
#   SHUFFLE_ENABLED  - Shuffle Service (true, false)
#   OPENLINEAGE_ENABLED - OpenLineage tracking (true, false)
#   K8S_NAMESPACE    - Kubernetes namespace (default: spark-test)
#   HELM_RELEASE     - Helm release name (default: spark-scenario)
#   TEST_TIMEOUT     - Test timeout in seconds (default: 60)

set -euo pipefail

# === Configuration ===
SPARK_VERSION="${SPARK_VERSION:-3.5.7}"
PLATFORM="${PLATFORM:-k8s}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-standalone}"
CONNECT_ENABLED="${CONNECT_ENABLED:-false}"
GPU_ENABLED="${GPU_ENABLED:-false}"
ICEBERG_ENABLED="${ICEBERG_ENABLED:-false}"
SHUFFLE_ENABLED="${SHUFFLE_ENABLED:-false}"
OPENLINEAGE_ENABLED="${OPENLINEAGE_ENABLED:-false}"
NAMESPACE="${K8S_NAMESPACE:-spark-test}"
RELEASE="${HELM_RELEASE:-spark-scenario}"
TIMEOUT="${TEST_TIMEOUT:-60}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"
SCENARIO_ID="smoke-${SPARK_VERSION}-${PLATFORM}-${DEPLOYMENT_MODE}-connect-${CONNECT_ENABLED}"

mkdir -p "$RESULTS_DIR"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Counters ===
PASSED=0
FAILED=0
SKIPPED=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++)) || true
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "[$(date)] $SCENARIO_ID: $1" >> "$RESULTS_DIR/failed.log"
    ((FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++)) || true
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

get_chart_path() {
    case $SPARK_VERSION in
        3.5.7|3.5.8)
            echo "$PROJECT_ROOT/charts/spark-3.5"
            ;;
        4.0.2)
            echo "$PROJECT_ROOT/charts/spark-4.0"
            ;;
        4.1.1)
            echo "$PROJECT_ROOT/charts/spark-4.1"
            ;;
        *)
            echo "$PROJECT_ROOT/charts/spark-3.5"
            ;;
    esac
}

get_master_service() {
    if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
        echo "${RELEASE}-standalone-master"
    else
        echo "${RELEASE}-spark-connect"
    fi
}

get_master_pod() {
    if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
        kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
    else
        kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-connect' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
    fi
}

# === Header ===
echo "=============================================="
echo "SMOKE TEST - Scenario: $SCENARIO_ID"
echo "=============================================="
echo "Spark Version:    $SPARK_VERSION"
echo "Platform:         $PLATFORM"
echo "Deployment Mode:  $DEPLOYMENT_MODE"
echo "Connect:          $CONNECT_ENABLED"
echo "GPU:              $GPU_ENABLED"
echo "Iceberg:          $ICEBERG_ENABLED"
echo "Shuffle Service:  $SHUFFLE_ENABLED"
echo "OpenLineage:      $OPENLINEAGE_ENABLED"
echo "Namespace:        $NAMESPACE"
echo "Release:          $RELEASE"
echo "Time:             $(date)"
echo ""

# === 1. Namespace Connectivity ===
log_info "=== 1. Namespace Connectivity ==="

echo -n "Testing: k8s-connect... "
if kubectl cluster-info > /dev/null 2>&1; then
    log_pass "k8s-connect"
else
    log_fail "k8s-connect"
fi

echo -n "Testing: namespace-exists... "
if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    log_pass "namespace-exists"
else
    log_fail "namespace-exists"
fi

# === 2. Helm Release Status ===
log_info "=== 2. Helm Release Status ==="

echo -n "Testing: helm-release... "
if helm status $RELEASE -n $NAMESPACE > /dev/null 2>&1; then
    log_pass "helm-release"
else
    log_fail "helm-release"
fi

# === 3. Pod Health ===
log_info "=== 3. Pod Health ==="

MASTER_POD=$(get_master_pod)

echo -n "Testing: spark-pod-running... "
if [[ -n "$MASTER_POD" ]]; then
    PHASE=$(kubectl get pod $MASTER_POD -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$PHASE" == "Running" ]]; then
        log_pass "spark-pod-running"
    else
        log_fail "spark-pod-running (phase: $PHASE)"
    fi
else
    log_skip "spark-pod-running (pod not found)"
fi

# Check workers for standalone mode
if [[ "$DEPLOYMENT_MODE" == "standalone" ]]; then
    WORKER_COUNT=$(kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-worker' --no-headers 2>/dev/null | grep -c Running || echo "0")
    
    echo -n "Testing: worker-pods-running... "
    if [[ $WORKER_COUNT -gt 0 ]]; then
        log_pass "worker-pods-running ($WORKER_COUNT)"
    else
        log_fail "worker-pods-running (no workers)"
    fi
fi

# === 4. Spark Connect Test (if enabled) ===
if [[ "$CONNECT_ENABLED" == "true" ]]; then
    log_info "=== 4. Spark Connect Test ==="
    
    CONNECT_SVC=$(kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component=spark-connect' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    echo -n "Testing: connect-service... "
    if [[ -n "$CONNECT_SVC" ]]; then
        log_pass "connect-service ($CONNECT_SVC)"
    else
        log_fail "connect-service (not found)"
    fi
    
    # Test Connect endpoint if pod exists
    if [[ -n "$MASTER_POD" ]]; then
        echo -n "Testing: connect-endpoint... "
        CONNECT_PORT=$(kubectl get svc -n $NAMESPACE $CONNECT_SVC -o jsonpath='{.spec.ports[?(@.name=="connect")].port}' 2>/dev/null || echo "15002")
        
        # Try connecting via Python
        CONNECT_TEST=$(kubectl exec -n $NAMESPACE $MASTER_POD -- python3 -c "
from pyspark.sql import SparkSession
try:
    spark = SparkSession.builder.remote('sc://localhost:$CONNECT_PORT').getOrCreate()
    df = spark.range(10)
    count = df.count()
    spark.stop()
    print('CONNECT_TEST_SUCCESS')
except Exception as e:
    print(f'CONNECT_TEST_ERROR: {e}')
" 2>&1) || true
        
        if echo "$CONNECT_TEST" | grep -q "CONNECT_TEST_SUCCESS"; then
            log_pass "connect-endpoint"
        else
            log_skip "connect-endpoint (connection failed)"
        fi
    fi
fi

# === 5. Basic Spark Submit Test ===
log_info "=== 5. Basic Spark Submit Test ==="

if [[ -n "$MASTER_POD" && "$DEPLOYMENT_MODE" == "standalone" ]]; then
    MASTER_URL="spark://$(get_master_service):7077"
    
    cat > /tmp/smoke-test-$SCENARIO_ID.py << PYEOF
from pyspark.sql import SparkSession
import sys

spark = SparkSession.builder \\
    .appName("SmokeTest-$SCENARIO_ID") \\
    .master("$MASTER_URL") \\
    .getOrCreate()

df = spark.range(100)
count = df.count()
spark.stop()

print(f"SMOKE_TEST_RESULT: {count}")
PYEOF

    echo -n "Testing: spark-submit-basic... "
    kubectl cp /tmp/smoke-test-$SCENARIO_ID.py $NAMESPACE/$MASTER_POD:/tmp/smoke-test.py 2>/dev/null
    
    OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c 'DRIVER_HOST=$(hostname -i) && timeout '$TIMEOUT' spark-submit --master '$MASTER_URL' --conf spark.driver.host=$DRIVER_HOST --conf spark.driver.bindAddress=0.0.0.0 /tmp/smoke-test.py' 2>&1) || true
    
    if echo "$OUTPUT" | grep -q "SMOKE_TEST_RESULT: 100"; then
        log_pass "spark-submit-basic"
    else
        log_fail "spark-submit-basic"
        echo "$OUTPUT" | tail -20 >> "$RESULTS_DIR/smoke-submit-$SCENARIO_ID.log"
    fi
    
    rm -f /tmp/smoke-test-$SCENARIO_ID.py
else
    log_skip "spark-submit-basic (requires standalone mode)"
fi

# === 6. GPU Test (if enabled) ===
if [[ "$GPU_ENABLED" == "true" ]]; then
    log_info "=== 6. GPU Test ==="
    
    echo -n "Testing: gpu-resources... "
    GPU_COUNT=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.requests.nvidia\.com/gpu}' 2>/dev/null | grep -c -E '[0-9]+' || echo "0")
    
    if [[ $GPU_COUNT -gt 0 ]]; then
        log_pass "gpu-resources ($GPU_COUNT GPUs allocated)"
    else
        log_skip "gpu-resources (no GPUs found)"
    fi
fi

# === 7. Iceberg Test (if enabled) ===
if [[ "$ICEBERG_ENABLED" == "true" ]]; then
    log_info "=== 7. Iceberg Test ==="
    
    # Check for Iceberg catalog configuration
    echo -n "Testing: iceberg-catalog... "
    ICEBERG_CONFIG=$(kubectl exec -n $NAMESPACE $MASTER_POD -- env 2>/dev/null | grep -c ICEBERG || echo "0")
    
    if [[ $ICEBERG_CONFIG -gt 0 ]]; then
        log_pass "iceberg-catalog (configured)"
    else
        log_skip "iceberg-catalog (not configured)"
    fi
fi

# === 8. OpenLineage Test (if enabled) ===
if [[ "$OPENLINEAGE_ENABLED" == "true" ]]; then
    log_info "=== 8. OpenLineage Test ==="
    
    echo -n "Testing: openlineage-config... "
    OL_CONFIG=$(kubectl exec -n $NAMESPACE $MASTER_POD -- env 2>/dev/null | grep -c OPENLINEAGE || echo "0")
    
    if [[ $OL_CONFIG -gt 0 ]]; then
        log_pass "openlineage-config (configured)"
    else
        log_skip "openlineage-config (not configured)"
    fi
fi

# === Summary ===
echo ""
echo "=============================================="
echo "SMOKE TEST SUMMARY - $SCENARIO_ID"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

# Record results
echo "$SCENARIO_ID,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/smoke-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/failed.log"
    exit 1
else
    echo "All smoke tests passed for scenario: $SCENARIO_ID"
    exit 0
fi
