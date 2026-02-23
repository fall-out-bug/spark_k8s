#!/bin/bash
# Workload Runner for Load Testing
# Part of WS-013-08: Load Test Scenario Implementation
#
# Orchestrates workload execution with proper environment setup
# and result collection.
#
# Usage: ./workload-runner.sh <workload_script> <args>

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKLOADS_DIR="$PROJECT_ROOT/workloads"
RESULTS_DIR="${RESULTS_DIR:-/tmp/load-test-results}"
SPARK_CONNECT_URL="${SPARK_CONNECT_URL:-sc://localhost:15002}"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Validate inputs
validate_inputs() {
    local workload_script="$1"

    if [ -z "$workload_script" ]; then
        log_error "Workload script not specified"
        return 1
    fi

    # Check if script exists
    if [ ! -f "$workload_script" ]; then
        # Try to find it in workloads directory
        if [ -f "$WORKLOADS_DIR/$workload_script" ]; then
            workload_script="$WORKLOADS_DIR/$workload_script"
        else
            log_error "Workload script not found: $workload_script"
            return 1
        fi
    fi

    # Check if script is executable
    if [ ! -x "$workload_script" ]; then
        log_warning "Script is not executable, attempting to run with python3"
    fi

    echo "$workload_script"
}

# Setup environment
setup_environment() {
    log_info "Setting up workload environment"

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    # Check Spark Connect URL
    if [ -z "$SPARK_CONNECT_URL" ]; then
        log_error "SPARK_CONNECT_URL not set"
        return 1
    fi

    log_info "Spark Connect URL: $SPARK_CONNECT_URL"

    # Check Python dependencies
    if ! python3 -c "import pyspark" 2>/dev/null; then
        log_error "PySpark not installed"
        return 1
    fi

    # Check S3 configuration
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        log_warning "S3 credentials not set, using defaults"
        export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-minioadmin}"
        export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-minioadmin}"
    fi

    log_info "Environment setup complete"
}

# Run workload
run_workload() {
    local workload_script="$1"
    shift

    log_info "Running workload: $workload_script"
    log_info "Arguments: $*"

    local start_time=$(date +%s)
    local exit_code=0

    # Run the workload script
    if python3 "$workload_script" "$@"; then
        exit_code=0
        log_info "Workload completed successfully"
    else
        exit_code=$?
        log_error "Workload failed with exit code $exit_code"
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Workload duration: ${duration}s"

    # Append execution metadata to results
    local results_file="$RESULTS_DIR/execution.jsonl"
    cat >> "$results_file" <<EOF
{"script": "$workload_script", "args": "$*", "exit_code": $exit_code, "duration_sec": $duration, "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

    return $exit_code
}

# Collect metrics
collect_metrics() {
    local results_file="${1:-$RESULTS_DIR/results.jsonl}"

    log_info "Collecting metrics from: $results_file"

    if [ ! -f "$results_file" ]; then
        log_warning "Results file not found: $results_file"
        return 1
    fi

    # Print summary
    local row_count=$(wc -l < "$results_file")
    log_info "Results: $row_count records"

    # Print latest result
    log_info "Latest result:"
    tail -1 "$results_file" | python3 -m json.tool 2>/dev/null || tail -1 "$results_file"
}

# Main execution
main() {
    if [ $# -lt 1 ]; then
        log_error "Usage: $0 <workload_script> [args...]"
        log_error ""
        log_error "Example:"
        log_error "  $0 read.py --data_size 1gb --output results.jsonl"
        exit 1
    fi

    local workload_script
    workload_script=$(validate_inputs "$1")
    shift

    setup_environment || exit 1
    run_workload "$workload_script" "$@" || exit $?
    collect_metrics "${RESULTS_DIR}/results.jsonl"

    log_info "Workload execution complete"
}

main "$@"
