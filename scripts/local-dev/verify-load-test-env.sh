#!/bin/bash
# Verify Load Test Environment
# Part of WS-013-06: Minikube Auto-Setup Infrastructure
#
# This script verifies that all components of the load test
# infrastructure are properly deployed and accessible.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0

# Helper functions
log_info() {
    echo -e "${GREEN}[CHECK]${NC} $1"
}

log_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

log_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

log_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

check_kubectl() {
    log_info "Checking kubectl access"
    if kubectl get nodes &> /dev/null; then
        log_pass "kubectl can access cluster"
        kubectl get nodes
    else
        log_fail "kubectl cannot access cluster"
        return 1
    fi
}

check_namespace() {
    log_info "Checking load-testing namespace"
    if kubectl get namespace load-testing &> /dev/null; then
        log_pass "load-testing namespace exists"
    else
        log_fail "load-testing namespace does not exist"
        return 1
    fi
}

check_minio() {
    log_info "Checking Minio deployment"

    # Check deployment
    if kubectl get deployment minio -n load-testing &> /dev/null; then
        log_pass "Minio deployment exists"
    else
        log_fail "Minio deployment not found"
        return 1
    fi

    # Check pods
    if kubectl get pods -l app=minio -n load-testing | grep -q Running; then
        log_pass "Minio pods are running"
    else
        log_fail "Minio pods are not running"
        return 1
    fi

    # Check service
    if kubectl get service minio -n load-testing &> /dev/null; then
        log_pass "Minio service exists"
    else
        log_fail "Minio service not found"
        return 1
    fi

    # Check buckets (requires mc or port-forward)
    log_warn "Skipping bucket check (requires mc or port-forward)"
}

check_postgres() {
    log_info "Checking Postgres deployment"

    # Check deployment
    if kubectl get deployment postgres-load-testing -n load-testing &> /dev/null; then
        log_pass "Postgres deployment exists"
    else
        log_fail "Postgres deployment not found"
        return 1
    fi

    # Check pods
    if kubectl get pods -l app.kubernetes.io/name=postgresql -n load-testing | grep -q Running; then
        log_pass "Postgres pods are running"
    else
        log_fail "Postgres pods are not running"
        return 1
    fi

    # Check service
    if kubectl get service postgres-load-testing -n load-testing &> /dev/null; then
        log_pass "Postgres service exists"
    else
        log_fail "Postgres service not found"
        return 1
    fi
}

check_hive_metastore() {
    log_info "Checking Hive Metastore deployment"

    # Check deployment
    if kubectl get deployment hive-metastore -n load-testing &> /dev/null; then
        log_pass "Hive Metastore deployment exists"
    else
        log_fail "Hive Metastore deployment not found"
        return 1
    fi

    # Check pods
    if kubectl get pods -l app=hive-metastore -n load-testing | grep -q Running; then
        log_pass "Hive Metastore pods are running"
    else
        log_fail "Hive Metastore pods are not running"
        return 1
    fi

    # Check service
    if kubectl get service hive-metastore -n load-testing &> /dev/null; then
        log_pass "Hive Metastore service exists"
    else
        log_fail "Hive Metastore service not found"
        return 1
    fi
}

check_history_server() {
    log_info "Checking Spark History Server deployment"

    # Check deployment
    if kubectl get deployment spark-history-server -n load-testing &> /dev/null; then
        log_pass "History Server deployment exists"
    else
        log_fail "History Server deployment not found"
        return 1
    fi

    # Check pods
    if kubectl get pods -l app=spark-history-server -n load-testing | grep -q Running; then
        log_pass "History Server pods are running"
    else
        log_fail "History Server pods are not running"
        return 1
    fi

    # Check service
    if kubectl get service spark-history-server -n load-testing &> /dev/null; then
        log_pass "History Server service exists"
    else
        log_fail "History Server service not found"
        return 1
    fi
}

check_test_data() {
    log_info "Checking test data availability"

    log_warn "Test data check requires Minio access (skipped)"
    log_warn "Run: kubectl port-forward -n load-testing svc/minio 9000:9000"
    log_warn "Then: mc alias set local http://localhost:9000 minioadmin minioadmin"
    log_warn "Then: mc ls local/test-data/nyc-taxi/"
}

print_summary() {
    echo ""
    echo "===================="
    echo "Verification Summary"
    echo "===================="
    echo ""
    echo "Checks passed: $CHECKS_PASSED"
    echo "Checks failed: $CHECKS_FAILED"
    echo ""

    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
        echo ""
        echo "Load test environment is ready."
        echo ""
        echo "Access services:"
        echo "  - Minio: kubectl port-forward -n load-testing svc/minio 9000:9000"
        echo "  - Postgres: kubectl port-forward -n load-testing svc/postgres-load-testing 5432:5432"
        echo "  - History Server: kubectl port-forward -n load-testing svc/spark-history-server 18080:18080"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Some checks failed${NC}"
        echo ""
        echo "Run setup script to fix:"
        echo "  ./scripts/local-dev/setup-minikube-load-tests.sh"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    echo "Verifying load test environment..."
    echo ""

    check_kubectl
    check_namespace
    check_minio
    check_postgres
    check_hive_metastore
    check_history_server
    check_test_data

    print_summary
}

main "$@"
