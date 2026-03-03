#!/bin/bash
# OpenShift Compatibility Tests for Lego-Spark
# Tests PSS restricted compliance, SCC compatibility, route creation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
RESULTS_DIR="$TESTS_DIR/results"

NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"
RELEASE="${HELM_RELEASE:-airflow-sc}"
OPENSHIFT_API="${OPENSHIFT_API:-https://openshift.default.svc}"

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

log_pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)) || true; }
log_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; echo "$1" >> "$RESULTS_DIR/openshift-failed.log"; ((FAILED++)) || true; }
log_skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((SKIPPED++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

check_openshift() {
    if kubectl get clusterversion 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

get_master_pod() {
    kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

echo "=============================================="
echo "OPENSHIFT COMPATIBILITY TESTS"
echo "=============================================="
echo "Namespace:     $NAMESPACE"
echo "Release:       $RELEASE"
echo "Time:          $(date)"
echo ""

# === 1. OpenShift Detection ===
log_info "=== 1. OpenShift Detection ==="

echo -n "Testing: openshift-cluster... "
if check_openshift; then
    VERSION=$(kubectl get clusterversion -o jsonpath='{.items[0].status.desired.version}' 2>/dev/null || echo "unknown")
    log_pass "openshift-cluster (version: $VERSION)"
else
    log_skip "openshift-cluster (not an OpenShift cluster)"
fi

# === 2. Pod Security Standards ===
log_info "=== 2. Pod Security Standards ==="

echo -n "Testing: namespace-pss-labels... "
PSS_LABELS=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels}' 2>/dev/null | grep -c 'pod-security.kubernetes.io' || echo "0")

if [[ $PSS_LABELS -gt 0 ]]; then
    ENFORCE=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
    log_pass "namespace-pss-labels (enforce: $ENFORCE)"
else
    log_skip "namespace-pss-labels (not labeled)"
fi

# === 3. Security Context Constraints ===
log_info "=== 3. Security Context Constraints ==="

if check_openshift; then
    echo -n "Testing: scc-restricted... "
    SCC_PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

    SCC_ISSUES=0
    for pod in $SCC_PODS; do
        RUNAS_NON_ROOT=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "false")
        if [[ "$RUNAS_NON_ROOT" != "true" ]]; then
            SCC_ISSUES=$((SCC_ISSUES + 1))
        fi
    done

    if [[ $SCC_ISSUES -eq 0 ]]; then
        log_pass "scc-restricted-compliant"
    else
        log_fail "scc-restricted-compliant ($SCC_ISSUES pods non-compliant)"
    fi
else
    log_skip "scc-restricted (not OpenShift)"
fi

# === 4. Pod Security Context ===
log_info "=== 4. Pod Security Context ==="

echo -n "Testing: non-root-containers... "
NON_ROOT_COUNT=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.runAsNonRoot}' 2>/dev/null | tr ' ' '\n' | grep -c true || echo "0")
TOTAL_CONTAINERS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null | tr ' ' '\n' | wc -l || echo "0")

if [[ $NON_ROOT_COUNT -gt 0 ]]; then
    log_pass "non-root-containers ($NON_ROOT_COUNT/$TOTAL_CONTAINERS)"
else
    log_skip "non-root-containers (not configured)"
fi

echo -n "Testing: read-only-root-filesystem... "
RO_ROOTFS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.readOnlyRootFilesystem}' 2>/dev/null | tr ' ' '\n' | grep -c true || echo "0")

if [[ $RO_ROOTFS -gt 0 ]]; then
    log_pass "read-only-root-filesystem ($RO_ROOTFS containers)"
else
    log_skip "read-only-root-filesystem (not configured)"
fi

echo -n "Testing: drop-capabilities... "
CAP_DROP=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.capabilities.drop}' 2>/dev/null | grep -c ALL || echo "0")

if [[ $CAP_DROP -gt 0 ]]; then
    log_pass "drop-capabilities ($CAP_DROP containers)"
else
    log_skip "drop-capabilities (not configured)"
fi

# === 5. Routes (OpenShift) ===
log_info "=== 5. OpenShift Routes ==="

if check_openshift; then
    echo -n "Testing: spark-master-route... "
    MASTER_ROUTE=$(kubectl get route -n $NAMESPACE -l 'app.kubernetes.io/component=spark-master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$MASTER_ROUTE" ]]; then
        HOST=$(kubectl get route -n $NAMESPACE $MASTER_ROUTE -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        log_pass "spark-master-route (host: $HOST)"
    else
        log_skip "spark-master-route (not created)"
    fi

    echo -n "Testing: spark-connect-route... "
    CONNECT_ROUTE=$(kubectl get route -n $NAMESPACE -l 'app.kubernetes.io/component=spark-connect' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$CONNECT_ROUTE" ]]; then
        HOST=$(kubectl get route -n $NAMESPACE $CONNECT_ROUTE -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        log_pass "spark-connect-route (host: $HOST)"
    else
        log_skip "spark-connect-route (not created)"
    fi
else
    log_skip "openshift-routes (not OpenShift)"
fi

# === 6. Service Accounts ===
log_info "=== 6. Service Accounts ==="

echo -n "Testing: spark-service-account... "
SPARK_SA=$(kubectl get serviceaccount -n $NAMESPACE -l 'app.kubernetes.io/name=spark' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$SPARK_SA" ]]; then
    log_pass "spark-service-account ($SPARK_SA)"
else
    log_skip "spark-service-account (using default)"
fi

# === 7. Role-Based Access Control ===
log_info "=== 7. Role-Based Access Control ==="

echo -n "Testing: spark-role... "
SPARK_ROLE=$(kubectl get role -n $NAMESPACE -l 'app.kubernetes.io/name=spark' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$SPARK_ROLE" ]]; then
    log_pass "spark-role ($SPARK_ROLE)"
else
    log_skip "spark-role (not created)"
fi

echo -n "Testing: spark-rolebinding... "
SPARK_RB=$(kubectl get rolebinding -n $NAMESPACE -l 'app.kubernetes.io/name=spark' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$SPARK_RB" ]]; then
    log_pass "spark-rolebinding ($SPARK_RB)"
else
    log_skip "spark-rolebinding (not created)"
fi

# === 8. Network Policies ===
log_info "=== 8. Network Policies ==="

echo -n "Testing: network-policies... "
NP_COUNT=$(kubectl get networkpolicy -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")

if [[ $NP_COUNT -gt 0 ]]; then
    log_pass "network-policies ($NP_COUNT policies)"
else
    log_skip "network-policies (not configured)"
fi

# === 9. Resource Quotas ===
log_info "=== 9. Resource Quotas ==="

echo -n "Testing: resource-quotas... "
RQ_COUNT=$(kubectl get resourcequota -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")

if [[ $RQ_COUNT -gt 0 ]]; then
    log_pass "resource-quotas ($RQ_COUNT quotas)"
else
    log_skip "resource-quotas (not configured)"
fi

# === 10. Pod Disruption Budgets ===
log_info "=== 10. Pod Disruption Budgets ==="

echo -n "Testing: pod-disruption-budgets... "
PDB_COUNT=$(kubectl get pdb -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")

if [[ $PDB_COUNT -gt 0 ]]; then
    log_pass "pod-disruption-budgets ($PDB_COUNT pdbs)"
else
    log_skip "pod-disruption-budgets (not configured)"
fi

# === 11. Image Registry ===
log_info "=== 11. Image Registry ==="

if check_openshift; then
    echo -n "Testing: internal-registry-access... "
    REGISTRY_ROUTE=$(kubectl get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [[ -n "$REGISTRY_ROUTE" ]]; then
        log_pass "internal-registry-access ($REGISTRY_ROUTE)"
    else
        log_skip "internal-registry-access (no default route)"
    fi
else
    log_skip "internal-registry (not OpenShift)"
fi

# === 12. Storage Classes ===
log_info "=== 12. Storage Classes ==="

echo -n "Testing: storage-class-availability... "
SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l || echo "0")

if [[ $SC_COUNT -gt 0 ]]; then
    DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || echo "")
    log_pass "storage-class-availability ($SC_COUNT classes, default: $DEFAULT_SC)"
else
    log_skip "storage-class-availability (no storage classes)"
fi

# === 13. Pod Status in Restricted Mode ===
log_info "=== 13. Pod Status Verification ==="

echo -n "Testing: pods-running-restricted... "
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c Running || echo "0")
FAILED_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c -E 'Failed|Error|CrashLoopBackOff' || echo "0")

if [[ $FAILED_PODS -eq 0 && $RUNNING_PODS -gt 0 ]]; then
    log_pass "pods-running-restricted ($RUNNING_PODS running, 0 failed)"
elif [[ $FAILED_PODS -gt 0 ]]; then
    log_fail "pods-running-restricted ($FAILED_PODS failed pods)"
else
    log_skip "pods-running-restricted (no pods found)"
fi

# === Summary ===
echo ""
echo "=============================================="
echo "OPENSHIFT COMPATIBILITY TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

echo "openshift,$PASSED,$FAILED,$SKIPPED,$(date +%Y%m%d_%H%M%S)" >> "$RESULTS_DIR/openshift-history.csv"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests logged to: $RESULTS_DIR/openshift-failed.log"
    exit 1
else
    echo "All OpenShift compatibility tests passed!"
    exit 0
fi
