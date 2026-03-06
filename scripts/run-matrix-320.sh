#!/bin/bash
# Run all 320 scenarios: deploy → smoke → e2e → load (with history validation).
# Requires: k8s cluster, kubectl, helm, spark-custom images.
# Usage: ./scripts/run-matrix-320.sh [--shared-infra]
#   --shared-infra: use spark-infra + observability (MinIO, History, Hive, OTEL)
# Output: tests/results/scenario-*.json, tests/results/matrix-320-summary.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${PROJECT_ROOT}/tests/results"
FILTER=""
SHARED_INFRA=""
[[ "${1:-}" == "--shared-infra" ]] && SHARED_INFRA="--shared-infra" && shift || true

cd "$PROJECT_ROOT"

echo "=== Matrix 320: all scenarios (deploy smoke e2e load)${SHARED_INFRA:+ [shared-infra]} ==="
echo "Start: $(date -Iseconds)"

mkdir -p "$RESULTS_DIR"
t0=$(date +%s)

if ! ./scripts/run-matrix.sh --filter "$FILTER" $SHARED_INFRA all; then
    echo "Matrix run had failures (see above)"
fi

t1=$(date +%s)
duration=$((t1 - t0))
echo "End: $(date -Iseconds)"
echo "Duration: ${duration}s"

# Aggregate results (always run, even if matrix had failures)
python3 "$PROJECT_ROOT/scripts/aggregate-matrix-results.py" \
    --results-dir "$RESULTS_DIR" \
    --filter "$FILTER" \
    --output "$RESULTS_DIR/matrix-320-summary.json" \
    --duration "$duration"
exit $?
