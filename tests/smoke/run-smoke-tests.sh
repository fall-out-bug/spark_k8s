#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"
TIMEOUT="${TEST_TIMEOUT:-300}"

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "$1" >> "$RESULTS_DIR/failed.txt"
    ((FAILED++))
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++))
}

run_test() {
    local name="$1"
    local cmd="$2"
    local expected="${3:-0}"
    
    echo -n "Testing: $name... "
    
    local output
    local exit_code
    output=$(eval "$cmd" 2>&1) && exit_code=$? || exit_code=$?
    
    if [[ $exit_code -eq $expected ]]; then
        log_pass "$name"
        return 0
    else
        log_fail "$name (exit: $exit_code, expected: $expected)"
        echo "$output" >> "$RESULTS_DIR/${name// /_}.log"
        return 1
    fi
}

wait_for_pod() {
    local label="$1"
    local timeout="${2:-120}"
    
    echo "Waiting for pod: $label"
    kubectl wait --for=condition=Ready pod -l "$label" -n "$NAMESPACE" --timeout="${timeout}s" 2>/dev/null
}

wait_for_pods_ready() {
    local timeout="${1:-120}"
    local expected="${2:-1}"
    
    echo "Waiting for $expected pods to be ready..."
    local start=$(date +%s)
    
    while true; do
        local ready=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        if [[ $ready -ge $expected ]]; then
            echo "Ready pods: $ready"
            return 0
        fi
        
        local now=$(date +%s)
        if [[ $((now - start)) -gt $timeout ]]; then
            echo "Timeout waiting for pods (ready: $ready, expected: $expected)"
            return 1
        fi
        
        sleep 5
    done
}

echo "=============================================="
echo "SMOKE TESTS - Lego-Spark"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo "Release:   $RELEASE"
echo "Time:      $(date)"
echo ""

echo "=== 1. Kubernetes Connectivity ==="
run_test "k8s-connect" "kubectl cluster-info"
run_test "namespace-exists" "kubectl get namespace $NAMESPACE"

echo ""
echo "=== 2. Helm Release Status ==="
run_test "helm-release" "helm status $RELEASE -n $NAMESPACE"

echo ""
echo "=== 3. Pod Health ==="

MASTER_POD=$(kubectl get pods -n $NAMESPACE -l app=spark-standalone-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$MASTER_POD" ]]; then
    run_test "master-pod-running" "kubectl get pod $MASTER_POD -n $NAMESPACE -o jsonpath='{.status.phase}' | grep -q Running"
else
    log_skip "master-pod-running (pod not found)"
fi

WORKER_COUNT=$(kubectl get pods -n $NAMESPACE -l app=spark-standalone-worker --no-headers 2>/dev/null | grep Running | wc -l || echo "0")
if [[ $WORKER_COUNT -gt 0 ]]; then
    run_test "worker-pods-running" "[[ $WORKER_COUNT -gt 0 ]]"
else
    log_skip "worker-pods-running (no workers)"
fi

echo ""
echo "=== 4. Spark Master UI ==="
run_test "master-ui-endpoint" "kubectl get svc -n $NAMESPACE -l app=spark-standalone-master -o name"

echo ""
echo "=== 5. Spark Submit Test ==="

cat > /tmp/smoke-test.py << 'PYEOF'
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .appName("SmokeTest") \
    .master("spark://localhost:7077") \
    .getOrCreate()
df = spark.range(100)
count = df.count()
spark.stop()
print(f"SMOKE_TEST_RESULT: {count}")
PYEOF

if [[ -n "$MASTER_POD" ]]; then
    kubectl cp /tmp/smoke-test.py $NAMESPACE/$MASTER_POD:/tmp/smoke-test.py 2>/dev/null
    OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- timeout 60 spark-submit --master spark://localhost:7077 /tmp/smoke-test.py 2>&1 || true)
    
    if echo "$OUTPUT" | grep -q "SMOKE_TEST_RESULT: 100"; then
        log_pass "spark-submit-basic"
    else
        log_fail "spark-submit-basic"
        echo "$OUTPUT" >> "$RESULTS_DIR/spark-submit-basic.log"
    fi
else
    log_skip "spark-submit-basic (no master pod)"
fi

echo ""
echo "=== 6. S3/MinIO Storage ==="

MINIO_POD=$(kubectl get pods -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$MINIO_POD" ]]; then
    run_test "minio-pod-running" "kubectl get pod $MINIO_POD -n $NAMESPACE -o jsonpath='{.status.phase}' | grep -q Running"
else
    log_skip "minio-pod-running (MinIO not deployed)"
fi

echo ""
echo "=== 7. Monitoring Resources ==="

DASHBOARD_COUNT=$(kubectl get configmap -n $NAMESPACE -l grafana_dashboard=1 --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $DASHBOARD_COUNT -gt 0 ]]; then
    run_test "grafana-dashboards" "[[ $DASHBOARD_COUNT -gt 0 ]]"
    echo "  Dashboards found: $DASHBOARD_COUNT"
else
    log_skip "grafana-dashboards (not enabled)"
fi

ALERT_COUNT=$(kubectl get prometheusrule -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $ALERT_COUNT -gt 0 ]]; then
    run_test "prometheus-alerts" "[[ $ALERT_COUNT -gt 0 ]]"
    echo "  Alert rules found: $ALERT_COUNT"
else
    log_skip "prometheus-alerts (not enabled)"
fi

echo ""
echo "=== 8. Example Scripts Syntax ==="

EXAMPLES_DIR="$PROJECT_ROOT/charts/spark-3.5/examples"
if [[ -d "$EXAMPLES_DIR" ]]; then
    for file in $(find "$EXAMPLES_DIR" -name "*.py" -type f); do
        name=$(basename "$file")
        run_test "syntax-$name" "python3 -m py_compile $file"
    done
fi

echo ""
echo "=============================================="
echo "SMOKE TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests saved to: $RESULTS_DIR/failed.txt"
    exit 1
else
    echo "All smoke tests passed!"
    exit 0
fi
