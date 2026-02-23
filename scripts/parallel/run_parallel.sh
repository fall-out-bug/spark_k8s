#!/bin/bash
# Parallel execution framework for Spark K8s tests
#
# Usage:
#   ./run_parallel.sh [--max-parallel N] [--scenarios-dir DIR] [--results-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
MAX_PARALLEL=${MAX_PARALLEL:-4}
SCENARIOS_DIR=${SCENARIOS_DIR:-"${PROJECT_ROOT}/scripts/tests/smoke/scenarios"}
RESULTS_DIR=${RESULTS_DIR:-"${PROJECT_ROOT}/test-results"}
TIMESTAMP=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run Spark K8s test scenarios in parallel.

OPTIONS:
    -j, --max-parallel N     Maximum parallel jobs (default: 4)
    -s, --scenarios-dir DIR  Scenarios directory (default: scripts/tests/smoke/scenarios)
    -r, --results-dir DIR    Results directory (default: test-results)
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0") --max-parallel 8
    $(basename "$0") --scenarios-dir ./custom-scenarios

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -j|--max-parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            -s|--scenarios-dir)
                SCENARIOS_DIR="$2"
                shift 2
                ;;
            -r|--results-dir)
                RESULTS_DIR="$2"
                shift 2
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

    if [[ ! -d "${SCENARIOS_DIR}" ]]; then
        log_error "Scenarios directory not found: ${SCENARIOS_DIR}"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Cleanup handler
cleanup() {
    local exit_code=$?
    echo ""
    log_info "Cleaning up namespaces..."
    "${SCRIPT_DIR}/cleanup.sh" --results-dir "${RESULTS_DIR}"
    exit ${exit_code}
}

trap cleanup EXIT INT TERM

main() {
    parse_args "$@"

    log_info "=== Parallel Test Execution ==="
    log_info "Max parallel: ${MAX_PARALLEL}"
    log_info "Scenarios dir: ${SCENARIOS_DIR}"
    log_info "Results dir: ${RESULTS_DIR}"

    check_prerequisites

    # Create results directory
    mkdir -p "${RESULTS_DIR}"

    # Get list of scenarios
    mapfile -t scenarios < <(find "${SCENARIOS_DIR}" -name "*.sh" -type f | sort)

    if [[ ${#scenarios[@]} -eq 0 ]]; then
        log_error "No scenarios found in ${SCENARIOS_DIR}"
        exit 1
    fi

    log_info "Found ${#scenarios[@]} scenarios"

    # Export environment for parallel execution
    export SCRIPT_DIR RESULTS_DIR TIMESTAMP

    # Run scenarios in parallel
    if command -v parallel &> /dev/null; then
        log_info "Using GNU parallel..."
        printf "%s\n" "${scenarios[@]}" | parallel -j "${MAX_PARALLEL}" --timeout 3600 \
            "${SCRIPT_DIR}/run_scenario.sh" {} "${RESULTS_DIR}" "${TIMESTAMP}"
    else
        log_info "GNU parallel not found, using xargs..."
        printf "%s\n" "${scenarios[@]}" | xargs -P "${MAX_PARALLEL}" -I {} \
            "${SCRIPT_DIR}/run_scenario.sh" {} "${RESULTS_DIR}" "${TIMESTAMP}"
    fi

    log_info "=== All scenarios completed ==="

    # Aggregate results
    log_info "Aggregating results..."
    if [[ -f "${PROJECT_ROOT}/scripts/aggregate/aggregate_json.py" ]]; then
        python3 "${PROJECT_ROOT}/scripts/aggregate/aggregate_json.py" "${RESULTS_DIR}"
    fi
}

main "$@"
