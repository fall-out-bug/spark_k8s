#!/bin/bash
# Test Prometheus metrics scraping for Spark on Kubernetes
#
# Usage:
#   ./test_metrics.sh --namespace spark-operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
TIMEOUT="${TIMEOUT:-300}"
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Test Prometheus metrics scraping for Spark applications.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -t, --timeout SECONDS     Test timeout in seconds (default: 300)
    -v, --verbose              Enable verbose output
    -h, --help                 Show this help

EXAMPLES:
    $(basename "$0") --namespace spark-operations
    $(basename "$0") --timeout 600 --verbose

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        return 1
    fi

    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE not found"
        return 1
    fi

    # Check Prometheus
    if ! kubectl get statefulset prometheus -n "$NAMESPACE" &> /dev/null; then
        log_warn "Prometheus StatefulSet not found in $NAMESPACE"
        log_warn "Run setup_prometheus.sh first"
        return 1
    fi

    log_info "Prerequisites check passed"
    return 0
}

test_prometheus_pod() {
    log_info "Testing Prometheus pod..."

    local prometheus_pod
    prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$prometheus_pod" ]]; then
        log_error "Prometheus pod not found"
        return 1
    fi

    log_info "Found Prometheus pod: $prometheus_pod"

    # Check pod is running
    local pod_status
    pod_status=$(kubectl get pod "$prometheus_pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

    if [[ "$pod_status" != "Running" ]]; then
        log_error "Prometheus pod is not running (status: $pod_status)"
        return 1
    fi

    log_info "Prometheus pod is running"
    return 0
}

test_prometheus_metrics() {
    log_info "Testing Prometheus metrics endpoint..."

    local prometheus_pod
    prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    # Port-forward to Prometheus
    log_info "Setting up port-forward to Prometheus..."
    kubectl port-forward -n "$NAMESPACE" "$prometheus_pod" 9090:9090 > /dev/null 2>&1 &
    local pf_pid=$!

    # Wait for port-forward to be ready
    sleep 3

    # Test metrics endpoint
    log_info "Querying Prometheus metrics..."
    local metrics_response
    metrics_response=$(curl -s http://localhost:9090/api/v1/query?query=up 2>/dev/null || echo "")

    # Cleanup port-forward
    kill $pf_pid 2>/dev/null || true

    if [[ -z "$metrics_response" ]]; then
        log_error "Failed to query Prometheus metrics"
        return 1
    fi

    # Check if response contains 'status":"success"'
    if echo "$metrics_response" | grep -q '"status":"success"'; then
        log_info "Prometheus metrics endpoint is working"
    else
        log_error "Prometheus metrics endpoint returned unexpected response"
        log_debug "Response: $metrics_response"
        return 1
    fi

    return 0
}

test_spark_metrics() {
    log_info "Testing Spark metrics scraping..."

    local prometheus_pod
    prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    # Port-forward to Prometheus
    kubectl port-forward -n "$NAMESPACE" "$prometheus_pod" 9090:9090 > /dev/null 2>&1 &
    local pf_pid=$!
    sleep 3

    # Test Spark-specific metrics
    log_info "Querying Spark executor metrics..."
    local executor_metrics
    executor_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=spark_executor_memoryUsed" 2>/dev/null || echo "")

    # Cleanup
    kill $pf_pid 2>/dev/null || true

    if echo "$executor_metrics" | grep -q '"status":"success"'; then
        local result_count
        result_count=$(echo "$executor_metrics" | jq -r '.data.result | length' 2>/dev/null || echo "0")

        if [[ "$result_count" -gt 0 ]]; then
            log_info "Found Spark executor metrics ($result_count results)"
        else
            log_warn "No Spark executor metrics found (no active Spark applications)"
        fi
    else
        log_debug "Spark executor metrics query result: $executor_metrics"
        log_warn "Could not query Spark metrics (Prometheus may need time to scrape)"
    fi

    return 0
}

test_prometheus_targets() {
    log_info "Testing Prometheus targets..."

    local prometheus_pod
    prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    # Port-forward to Prometheus
    kubectl port-forward -n "$NAMESPACE" "$prometheus_pod" 9090:9090 > /dev/null 2>&1 &
    local pf_pid=$!
    sleep 3

    # Query targets
    log_info "Querying Prometheus targets..."
    local targets_response
    targets_response=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null || echo "")

    # Cleanup
    kill $pf_pid 2>/dev/null || true

    if [[ -z "$targets_response" ]]; then
        log_error "Failed to query Prometheus targets"
        return 1
    fi

    # Check active targets
    local active_targets
    active_targets=$(echo "$targets_response" | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")

    log_info "Active Prometheus targets: $active_targets"

    if [[ "$active_targets" -gt 0 ]]; then
        log_info "Prometheus is scraping targets successfully"
    else
        log_warn "No active targets found"
    fi

    return 0
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  Prometheus Metrics Test Summary"
    echo "=========================================="
    echo ""
    echo "Namespace: $NAMESPACE"
    echo ""
    echo "Next steps:"
    echo "  - Deploy a Spark application to test metrics collection"
    echo "  - Check Grafana dashboards: http://localhost:3000"
    echo "  - View Prometheus UI: kubectl port-forward -n $NAMESPACE prometheus-0 9090:9090"
    echo ""
}

main() {
    parse_args "$@"

    log_info "Starting Prometheus metrics test..."
    log_info "Namespace: $NAMESPACE"
    echo ""

    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi

    echo ""

    local failed=0

    # Run tests
    if ! test_prometheus_pod; then
        ((failed++))
    fi

    echo ""

    if ! test_prometheus_metrics; then
        ((failed++))
    fi

    echo ""

    if ! test_spark_metrics; then
        ((failed++))
    fi

    echo ""

    if ! test_prometheus_targets; then
        ((failed++))
    fi

    echo ""

    if [[ $failed -eq 0 ]]; then
        log_info "All tests passed!"
        print_summary
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
