#!/bin/bash
# Load Test Scenario Template
# Part of WS-013-07: Test Matrix Definition & Template System
#
# Jinja2 template for generating bash scenario scripts
# that execute specific workload tests.
#
# Usage (via generator):
#   jinja2 load-scenario.jinja2.sh -D test_name="..." \
#     -D spark_ver="..." -D operation="..." -D data_size="..."

# Auto-generated load test scenario
# Test: {{ test_name }}
# Configuration: {{ spark_ver }} | {{ orchestrator }} | {{ mode }} | {{ extensions }} | {{ operation }} | {{ data_size }}

set -euo pipefail

# Script metadata (for parsing by test harness)
# @test_name {{ test_name }}
# @spark_version {{ spark_ver }}
# @orchestrator {{ orchestrator }}
# @mode {{ mode }}
# @extensions {{ extensions }}
# @operation {{ operation }}
# @data_size {{ data_size }}
# @timeout {{ timeout_sec }}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration from template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TEST_NAME="{{ test_name }}"
SPARK_VERSION="{{ spark_ver }}"
ORCHESTRATOR="{{ orchestrator }}"
MODE="{{ mode }}"
EXTENSIONS="{{ extensions }}"
OPERATION="{{ operation }}"
DATA_SIZE="{{ data_size }}"
TIMEOUT_SEC={{ timeout_sec }}

# Derived paths
HELM_VALUES_FILE="$PROJECT_ROOT/scripts/tests/output/helm-values/${TEST_NAME}-values.yaml"
WORKLOAD_SCRIPT="$PROJECT_ROOT/scripts/tests/load/workloads/{{ operation }}.py"
RESULTS_DIR="$PROJECT_ROOT/scripts/tests/output/results/${TEST_NAME}"
RESULTS_FILE="${RESULTS_DIR}/metrics.jsonl"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} [$TEST_NAME] $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} [$TEST_NAME] $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} [$TEST_NAME] $1"
}

# Test lifecycle functions
setup() {
    log_info "Setting up test environment..."

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    # Check if Helm values file exists
    if [ ! -f "$HELM_VALUES_FILE" ]; then
        log_error "Helm values file not found: $HELM_VALUES_FILE"
        return 1
    fi

    # Check if workload script exists
    if [ ! -f "$WORKLOAD_SCRIPT" ]; then
        log_error "Workload script not found: $WORKLOAD_SCRIPT"
        return 1
    fi

    log_info "Setup complete"
}

deploy_spark() {
    log_info "Deploying Spark..."

    local release_name="spark-load-test-${TEST_NAME}"
    local namespace="load-test-${TEST_NAME}"

    # Create namespace
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Deploy Spark using Helm
    if [ "$SPARK_VERSION" = "3.5.0" ]; then
        helm_chart="spark-3.5/spark-connect"
    else
        helm_chart="spark-4.1/spark-connect"
    fi

    helm upgrade --install "$release_name" "$helm_chart" \
        --namespace "$namespace" \
        --values "$HELM_VALUES_FILE" \
        --wait \
        --timeout 5m

    log_info "Spark deployed successfully"

    # Get service endpoint
    if [ "$ORCHESTRATOR" = "connect" ]; then
        SPARK_CONNECT_URL="sc://${release_name}-spark-connect.${namespace}.svc.cluster.local:15002"
        export SPARK_CONNECT_URL
        log_info "Spark Connect URL: $SPARK_CONNECT_URL"
    fi

    # Store namespace for cleanup
    echo "$namespace" > "${RESULTS_DIR}/namespace.txt"
}

run_workload() {
    log_info "Running workload: $OPERATION"

    local start_time=$(date +%s)
    local exit_code=0

    # Run workload with timeout
    if timeout "$TIMEOUT_SEC" python3 "$WORKLOAD_SCRIPT" \
        --operation "$OPERATION" \
        --data_size "$DATA_SIZE" \
        --output "$RESULTS_FILE" \
        --metadata "$TEST_NAME"; then
        log_info "Workload completed successfully"
    else
        exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "Workload timed out after ${TIMEOUT_SEC}s"
        else
            log_error "Workload failed with exit code $exit_code"
        fi
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Append metadata to results
    cat >> "${RESULTS_FILE}" <<EOF
{"test_name": "$TEST_NAME", "spark_version": "$SPARK_VERSION", "orchestrator": "$ORCHESTRATOR", "mode": "$MODE", "extensions": "$EXTENSIONS", "operation": "$OPERATION", "data_size": "$DATA_SIZE", "duration_sec": $duration, "exit_code": $exit_code, "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

    return $exit_code
}

collect_metrics() {
    log_info "Collecting metrics..."

    # Collect pod metrics
    local namespace
    namespace=$(cat "${RESULTS_DIR}/namespace.txt" 2>/dev/null || echo "")

    if [ -n "$namespace" ]; then
        kubectl get pods -n "$namespace" -o json > "${RESULTS_DIR}/pods.json"
        kubectl top pods -n "$namespace" > "${RESULTS_DIR}/top.txt" 2>/dev/null || true
    fi

    log_info "Metrics collected"
}

cleanup() {
    log_info "Cleaning up..."

    local namespace
    namespace=$(cat "${RESULTS_DIR}/namespace.txt" 2>/dev/null || echo "")

    if [ -n "$namespace" ]; then
        # Delete namespace (cascading delete)
        kubectl delete namespace "$namespace" --timeout=60s || true
        log_info "Namespace $namespace deleted"
    fi
}

# Signal handlers
trap cleanup EXIT INT TERM

# Main execution
main() {
    log_info "Starting test: $TEST_NAME"
    log_info "Configuration: ${SPARK_VERSION} | ${ORCHESTRATOR} | ${MODE} | ${EXTENSIONS} | ${OPERATION} | ${DATA_SIZE}"

    setup || exit 1
    deploy_spark || exit 1
    run_workload || exit 1
    collect_metrics

    log_info "Test complete: $TEST_NAME"

    return 0
}

# Run main
main "$@"
