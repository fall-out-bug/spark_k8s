#!/bin/bash
# Cleanup namespaces created during parallel test execution
#
# Usage:
#   ./cleanup.sh [--results-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-"${PROJECT_ROOT}/test-results"}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Cleanup namespaces created during parallel test execution.

OPTIONS:
    -r, --results-dir DIR    Results directory (default: test-results)
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0")

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

cleanup_namespaces() {
    local namespaces_file="${RESULTS_DIR}/namespaces.txt"

    if [[ ! -f "${namespaces_file}" ]]; then
        log_info "No namespaces to clean up"
        return
    fi

    log_info "Cleaning up namespaces from ${namespaces_file}..."

    local count=0
    while IFS= read -r namespace; do
        [[ -z "${namespace}" ]] && continue

        log_info "Deleting namespace: ${namespace}"
        if kubectl delete namespace "${namespace}" --ignore-not-found=true --timeout=60s 2>/dev/null; then
            ((count++))
        else
            log_error "Failed to delete namespace: ${namespace}"
            # Force delete if normal delete fails
            kubectl patch namespace "${namespace}" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        fi
    done < "${namespaces_file}"

    # Remove the tracking file
    rm -f "${namespaces_file}"

    log_info "Cleaned up ${count} namespace(s)"
}

main() {
    parse_args "$@"

    log_info "=== Namespace Cleanup ==="

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    cleanup_namespaces

    log_info "=== Cleanup Complete ==="
}

main "$@"
