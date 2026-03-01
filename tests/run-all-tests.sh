#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAIN_RESULTS="$RESULTS_DIR/all-tests-$TIMESTAMP.log"

echo "=============================================="
echo "LEGO-SPARK TEST SUITE"
echo "=============================================="
echo "Time: $(date)"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

run_test_suite() {
    local name="$1"
    local script="$2"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running: $name${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local output
    local exit_code
    
    output=$(bash "$script" 2>&1) && exit_code=$? || exit_code=$?
    
    echo "$output" | tee -a "$MAIN_RESULTS"
    
    local passed=$(echo "$output" | grep -c "✓ PASS" || echo "0")
    local failed=$(echo "$output" | grep -c "✗ FAIL" || echo "0")
    local skipped=$(echo "$output" | grep -c "⊘ SKIP" || echo "0")
    
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ $name completed successfully${NC}"
    else
        echo -e "${RED}✗ $name failed${NC}"
    fi
}

echo -e "${YELLOW}Select test suite to run:${NC}"
echo "  1) Smoke tests (quick validation)"
echo "  2) E2E tests (full scenarios)"
echo "  3) Load tests (performance)"
echo "  4) All tests"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        run_test_suite "SMOKE TESTS" "$SCRIPT_DIR/smoke/run-smoke-tests.sh"
        ;;
    2)
        run_test_suite "E2E TESTS" "$SCRIPT_DIR/e2e/run-e2e-tests.sh"
        ;;
    3)
        run_test_suite "LOAD TESTS" "$SCRIPT_DIR/load/run-load-tests.sh"
        ;;
    4)
        run_test_suite "SMOKE TESTS" "$SCRIPT_DIR/smoke/run-smoke-tests.sh"
        run_test_suite "E2E TESTS" "$SCRIPT_DIR/e2e/run-e2e-tests.sh"
        run_test_suite "LOAD TESTS" "$SCRIPT_DIR/load/run-load-tests.sh"
        ;;
    *)
        echo "Invalid choice. Running all tests..."
        run_test_suite "SMOKE TESTS" "$SCRIPT_DIR/smoke/run-smoke-tests.sh"
        run_test_suite "E2E TESTS" "$SCRIPT_DIR/e2e/run-e2e-tests.sh"
        run_test_suite "LOAD TESTS" "$SCRIPT_DIR/load/run-load-tests.sh"
        ;;
esac

echo ""
echo "=============================================="
echo "FINAL TEST SUMMARY"
echo "=============================================="
echo -e "${GREEN}Total Passed:${NC}  $TOTAL_PASSED"
echo -e "${RED}Total Failed:${NC}  $TOTAL_FAILED"
echo -e "${YELLOW}Total Skipped:${NC} $TOTAL_SKIPPED"
echo ""
echo "Results saved to: $MAIN_RESULTS"

if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
