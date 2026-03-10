#!/usr/bin/env bash
# Matrix test runner: deploy → smoke → e2e → load per scenario
# EXECUTES commands, never checks file existence.
# Usage: run-matrix.sh --filter "id=SCENARIO-0009" all
#        run-matrix.sh --filter "gpu=false,platform=k8s" deploy smoke

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_FILE="${PROJECT_ROOT}/tests/test-matrix.yaml"
RESULTS_DIR="${PROJECT_ROOT}/tests/results"

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
FILTER=""
LEVELS=""
DRY_RUN=""
SHARED_INFRA=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter) FILTER="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --shared-infra) SHARED_INFRA=1; shift ;;
        all) LEVELS="deploy smoke e2e load"; shift ;;
        deploy|smoke|e2e|load)
            LEVELS="${LEVELS:+$LEVELS }$1"
            shift
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [[ -z "$LEVELS" ]]; then
    echo "Usage: $0 --filter 'id=SCENARIO-0009' all"
    echo "       $0 --filter 'gpu=false' deploy smoke"
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# -----------------------------------------------------------------------------
# Main: Python does the heavy lifting (parse YAML, filter, helm, kubectl)
# -----------------------------------------------------------------------------
exec python3 "$SCRIPT_DIR/run_matrix_main.py" "$MATRIX_FILE" "$FILTER" "$LEVELS" "$RESULTS_DIR" "$PROJECT_ROOT" "${DRY_RUN:-}" "${SHARED_INFRA:-}"
