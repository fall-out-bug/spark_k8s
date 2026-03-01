#!/bin/bash
# Smoke Tests for Lego-Spark
# Quick validation of basic functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"

mkdir -p "$RESULTS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++)) || true
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "$1" >> "$RESULTS_DIR/failed.txt"
    ((FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++)) || true
}

echo "=============================================="
echo "SMOKE TESTS - Lego-Spark"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo "Release:   $RELEASE"
echo "Time:      $(date)"
echo ""

# === 1. Kubernetes Connectivity ===
echo "=== 1. Kubernetes Connectivity ==="

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
echo ""
echo "=== 2. Helm Release Status ==="

echo -n "Testing: helm-release... "
if helm status $RELEASE -n $NAMESPACE > /dev/null 2>&1; then
    log_pass "helm-release"
else
    log_fail "helm-release"
fi

# === 3. Pod Health ===
echo ""
echo "=== 3. Pod Health ==="

MASTER_POD=$(kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo -n "Testing: master-pod-running... "
if [[ -n "$MASTER_POD" ]]; then
    PHASE=$(kubectl get pod $MASTER_POD -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$PHASE" == "Running" ]]; then
        log_pass "master-pod-running"
    else
        log_fail "master-pod-running (phase: $PHASE)"
    fi
else
    log_skip "master-pod-running (pod not found)"
fi

WORKER_COUNT=$(kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-worker' --no-headers 2>/dev/null | grep -c Running || echo "0")

echo -n "Testing: worker-pods-running... "
if [[ $WORKER_COUNT -gt 0 ]]; then
    log_pass "worker-pods-running ($WORKER_COUNT)"
else
    log_skip "worker-pods-running (no workers)"
fi

# === 4. Spark Master UI ===
echo ""
echo "=== 4. Spark Master UI ==="

echo -n "Testing: master-ui-endpoint... "
if kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o name 2>/dev/null | grep -q .; then
    log_pass "master-ui-endpoint"
else
    log_skip "master-ui-endpoint (service not found)"
fi

# === 5. Spark Submit Test ===
echo ""
echo "=== 5. Spark Submit Test ==="

cat > /tmp/smoke-test.py << 'PYEOF'
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .appName("SmokeTest") \
    .master("spark://airflow-sc-standalone-master:7077") \
    .getOrCreate()
df = spark.range(100)
count = df.count()
spark.stop()
print(f"SMOKE_TEST_RESULT: {count}")
PYEOF

echo -n "Testing: spark-submit-basic... "
if [[ -n "$MASTER_POD" ]]; then
    kubectl cp /tmp/smoke-test.py $NAMESPACE/$MASTER_POD:/tmp/smoke-test.py 2>/dev/null
    OUTPUT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- bash -c 'DRIVER_HOST=$(hostname -i) && timeout 60 spark-submit --master spark://airflow-sc-standalone-master:7077 --conf spark.driver.host=$DRIVER_HOST --conf spark.driver.bindAddress=0.0.0.0 /tmp/smoke-test.py' 2>&1) || true
    
    if echo "$OUTPUT" | grep -q "SMOKE_TEST_RESULT: 100"; then
        log_pass "spark-submit-basic"
    else
        log_fail "spark-submit-basic"
        echo "$OUTPUT" | tail -20 >> "$RESULTS_DIR/spark-submit-basic.log"
    fi
else
    log_skip "spark-submit-basic (no master pod)"
fi

# === 6. S3/MinIO Storage ===
echo ""
echo "=== 6. S3/MinIO Storage ==="

MINIO_POD=$(kubectl get pods -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo -n "Testing: minio-pod-running... "
if [[ -n "$MINIO_POD" ]]; then
    PHASE=$(kubectl get pod $MINIO_POD -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$PHASE" == "Running" ]]; then
        log_pass "minio-pod-running"
    else
        log_fail "minio-pod-running (phase: $PHASE)"
    fi
else
    log_skip "minio-pod-running (MinIO not deployed)"
fi

# === 7. Monitoring Resources ===
echo ""
echo "=== 7. Monitoring Resources ==="

DASHBOARD_COUNT=$(kubectl get configmap -n $NAMESPACE -l grafana_dashboard=1 --no-headers 2>/dev/null | wc -l || echo "0")

echo -n "Testing: grafana-dashboards... "
if [[ $DASHBOARD_COUNT -gt 0 ]]; then
    log_pass "grafana-dashboards ($DASHBOARD_COUNT)"
else
    log_skip "grafana-dashboards (not enabled)"
fi

ALERT_COUNT=$(kubectl get prometheusrule -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")

echo -n "Testing: prometheus-alerts... "
if [[ $ALERT_COUNT -gt 0 ]]; then
    log_pass "prometheus-alerts ($ALERT_COUNT)"
else
    log_skip "prometheus-alerts (not enabled)"
fi

# === 8. Example Scripts Syntax ===
echo ""
echo "=== 8. Example Scripts Syntax ==="

EXAMPLES_DIR="$PROJECT_ROOT/charts/spark-3.5/examples"
if [[ -d "$EXAMPLES_DIR" ]]; then
    for file in $(find "$EXAMPLES_DIR" -name "*.py" -type f 2>/dev/null); do
        name=$(basename "$file")
        echo -n "Testing: syntax-$name... "
        if python3 -m py_compile "$file" 2>/dev/null; then
            log_pass "syntax-$name"
        else
            log_fail "syntax-$name"
        fi
    done
fi

# === Summary ===
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
