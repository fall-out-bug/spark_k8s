#!/bin/bash
# Run 96 k8s/no-gpu scenarios: deploy → smoke → e2e → load (with history validation).
# Requires: k8s cluster, kubectl, helm, spark-custom images.
# Usage: ./scripts/run-matrix-96.sh
# Output: tests/results/scenario-*.json, tests/results/matrix-96-summary.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${PROJECT_ROOT}/tests/results"
FILTER="gpu=false,platform=k8s"

echo "=== Matrix 96: $FILTER (deploy smoke e2e load) ==="
echo "Start: $(date -Iseconds)"

mkdir -p "$RESULTS_DIR"
t0=$(date +%s)

if ! ./scripts/run-matrix.sh --filter "$FILTER" all; then
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
    --output "$RESULTS_DIR/matrix-96-summary.json" \
    --duration "$duration"
exit $?
