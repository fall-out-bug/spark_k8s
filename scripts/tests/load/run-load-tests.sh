#!/bin/bash
# Run all load tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"

# Default values
SPARK_CONNECT_URL="${SPARK_CONNECT_URL:-sc://localhost:15002}"
TEST_NAMESPACE="${TEST_NAMESPACE:-spark-load-test}"
LOAD_TEST_DURATION="${LOAD_TEST_DURATION:-1800}"
LOAD_TEST_INTERVAL="${LOAD_TEST_INTERVAL:-1.0}"
METRICS_OUTPUT_DIR="${METRICS_OUTPUT_DIR:-${SCRIPT_DIR}/results}"

# Create results directory
mkdir -p "$METRICS_OUTPUT_DIR"

# Export for pytest
export SPARK_CONNECT_URL
export TEST_NAMESPACE
export LOAD_TEST_DURATION
export LOAD_TEST_INTERVAL
export METRICS_OUTPUT_DIR

log_section "Load Tests Configuration"
log_info "Spark Connect URL: $SPARK_CONNECT_URL"
log_info "Namespace: $TEST_NAMESPACE"
log_info "Duration: ${LOAD_TEST_DURATION}s ($((LOAD_TEST_DURATION / 60)) min)"
log_info "Interval: ${LOAD_TEST_INTERVAL}s"
log_info "Output: $METRICS_OUTPUT_DIR"

# Check if spark-connect is available
log_section "Checking Prerequisites"

if ! kubectl get svc -n "$TEST_NAMESPACE" &>/dev/null; then
    log_warning "Namespace $TEST_NAMESPACE not found. Tests may fail."
fi

# Check pytest
if ! command -v pytest &>/dev/null; then
    log_error "pytest not found. Install with: pip install pytest pytest-timeout"
    exit 1
fi

# Parse arguments
CATEGORY="${1:-all}"
VERBOSE="${2:-false}"

log_section "Running Load Tests"
log_info "Category: $CATEGORY"

case "$CATEGORY" in
    baseline)
        pytest -v -m baseline
        ;;
    gpu)
        pytest -v -m gpu
        ;;
    iceberg)
        pytest -v -m iceberg
        ;;
    comparison)
        pytest -v -m comparison
        ;;
    security)
        pytest -v -m security
        ;;
    all)
        log_warning "Running all load tests may take 15+ hours"
        pytest -v
        ;;
    *)
        log_error "Unknown category: $CATEGORY"
        log_info "Available: baseline, gpu, iceberg, comparison, security, all"
        exit 1
        ;;
esac

log_success "Load tests completed!"
log_info "Results saved to: $METRICS_OUTPUT_DIR"
