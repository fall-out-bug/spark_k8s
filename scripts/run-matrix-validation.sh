#!/usr/bin/env bash
# Run and validate test matrix with NYC Taxi pipeline (smoke → e2e → load)
# Each scenario: deploy → smoke → e2e → load → cleanup namespace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_ROOT/tests"

# Default: 1 scenario for quick validation. Override with --scenarios N or --filter
SCENARIO_FILTER="${SCENARIO_FILTER:-id=SCENARIO-0009}"
RUN_ALL_LEVELS="${RUN_ALL_LEVELS:-true}"  # smoke,e2e,load per scenario

echo "=== Matrix Validation (NYC Taxi pipeline) ==="
echo "Filter: ${SCENARIO_FILTER}"
echo "Levels: smoke + e2e + load per scenario"
echo ""

# 1. Smoke
echo ">>> Running smoke tests..."
cd "$PROJECT_ROOT"
bash "$TESTS_DIR/run-matrix.sh" smoke --filter "$SCENARIO_FILTER" --timeout 5

# 2. E2E (if RUN_ALL_LEVELS)
if [[ "$RUN_ALL_LEVELS" == "true" ]]; then
    echo ""
    echo ">>> Running e2e tests..."
    bash "$TESTS_DIR/run-matrix.sh" e2e --filter "$SCENARIO_FILTER" --timeout 10
fi

# 3. Load (if RUN_ALL_LEVELS)
if [[ "$RUN_ALL_LEVELS" == "true" ]]; then
    echo ""
    echo ">>> Running load tests..."
    bash "$TESTS_DIR/run-matrix.sh" load --filter "$SCENARIO_FILTER" --timeout 15
fi

echo ""
echo "=== Validation complete ==="
echo "Results: $TESTS_DIR/results/"
