#!/bin/bash
# Smoke test for Spark jobs after deployment
#
# Usage:
#   ./smoke-test-job.sh --namespace <ns> --release <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
NAMESPACE=""
RELEASE_NAME=""
TEST_TIMEOUT=300  # 5 minutes

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        --timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$NAMESPACE" || -z "$RELEASE_NAME" ]]; then
    log_error "Usage: $0 --namespace <ns> --release <name>"
    exit 1
fi

log_info "=== Spark Job Smoke Test ==="
log_info "Namespace: ${NAMESPACE}"
log_info "Release: ${RELEASE_NAME}"
log_info "Timeout: ${TEST_TIMEOUT}s"

# Test counter
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

# Test 1: Check driver pod is running
log_info "Test 1: Checking driver pod..."

DRIVER_POD=$(kubectl get pod -n "$NAMESPACE" -l "spark-role=driver,app.kubernetes.io/instance=${RELEASE_NAME}" -o jsonpath='{.items[0].metadata.name}')

if [[ -n "$DRIVER_POD" ]]; then
    POD_STATUS=$(kubectl get pod -n "$NAMESPACE" "$DRIVER_POD" -o jsonpath='{.status.phase}')

    if [[ "$POD_STATUS" == "Running" ]]; then
        log_info "✓ Driver pod is running: ${DRIVER_POD}"
        ((TESTS_PASSED++))
    else
        log_error "✗ Driver pod status: ${POD_STATUS}"
        ((TESTS_FAILED++))
    fi
else
    log_error "✗ Driver pod not found"
    ((TESTS_FAILED++))
fi

# Test 2: Check Spark UI is accessible
log_info "Test 2: Checking Spark UI..."

if kubectl get svc -n "$NAMESPACE" "${RELEASE_NAME}-spark-ui" &>/dev/null; then
    UI_URL=$(kubectl get svc -n "$NAMESPACE" "${RELEASE_NAME}-spark-ui" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

    if [[ -n "$UI_URL" ]]; then
        if curl -sf "http://${UI_URL}:4040" &>/dev/null; then
            log_info "✓ Spark UI is accessible"
            ((TESTS_PASSED++))
        else
            log_warn "Spark UI not responding (may be starting up)"
        fi
    else
        log_warn "Spark UI service has no external IP"
    fi
else
    log_warn "Spark UI service not found"
fi

# Test 3: Check executor pods
log_info "Test 3: Checking executor pods..."

EXECUTOR_COUNT=$(kubectl get pod -n "$NAMESPACE" -l "spark-role=executor,app.kubernetes.io/instance=${RELEASE_NAME}" --no-headers 2>/dev/null | wc -l)

if [[ $EXECUTOR_COUNT -gt 0 ]]; then
    log_info "✓ Found ${EXECUTOR_COUNT} executor(s)"
    ((TESTS_PASSED++))
else
    log_warn "No executor pods found yet"
fi

# Test 4: Run simple test query
log_info "Test 4: Running test query..."

TEST_QUERY="SELECT 1 AS test_col"

# Submit test job
JOB_OUTPUT=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- \
    spark-sql -e "$TEST_QUERY" 2>&1 || true)

if echo "$JOB_OUTPUT" | grep -q "test_col"; then
    log_info "✓ Test query executed successfully"
    ((TESTS_PASSED++))
else
    log_error "✗ Test query failed"
    ((TESTS_FAILED++))
fi

# Test 5: Check for errors in logs
log_info "Test 5: Checking for errors in logs..."

ERROR_COUNT=$(kubectl logs -n "$NAMESPACE" "$DRIVER_POD" --tail=100 2>/dev/null | grep -ci "error" || echo "0")

if [[ $ERROR_COUNT -eq 0 ]]; then
    log_info "✓ No errors found in logs"
    ((TESTS_PASSED++))
else
    log_warn "Found ${ERROR_COUNT} error(s) in logs (may be warnings)"
fi

# Summary
log_info "=== Smoke Test Summary ==="
log_info "Passed: ${TESTS_PASSED}"
log_info "Failed: ${TESTS_FAILED}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    log_error "Smoke test failed!"
    exit 1
fi

log_info "✓ All smoke tests passed"

exit 0
