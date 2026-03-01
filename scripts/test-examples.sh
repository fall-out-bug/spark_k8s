#!/bin/bash
# ===================================================================
# Examples Validation Test Suite
# ===================================================================
# Validates all example scripts and presets
#
# Usage:
#   ./test-examples.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - Some tests failed
# ===================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXAMPLES_DIR="$PROJECT_ROOT/charts/spark-3.5/examples"
PRESETS_DIR="$PROJECT_ROOT/charts/spark-3.5/presets"

PASSED=0
FAILED=0
ERRORS=""

run_test() {
    local name="$1"
    local cmd="$2"
    
    echo -n "Testing $name... "
    
    if eval "$cmd" > /dev/null 2>&1; then
        echo "✓ PASS"
        ((PASSED++))
    else
        echo "✗ FAIL"
        ((FAILED++))
        ERRORS="$ERRORS\n- $name"
    fi
}

echo "=============================================="
echo "Examples Validation Test Suite"
echo "=============================================="
echo ""

echo "--- Python Syntax Validation ---"
for file in $(find "$EXAMPLES_DIR" -name "*.py" -type f); do
    name=$(basename "$file")
    run_test "$name" "python3 -m py_compile $file"
done

echo ""
echo "--- YAML Syntax Validation ---"
for file in $(find "$PRESETS_DIR" -name "*.yaml" -type f); do
    name=$(echo "$file" | sed "s|$PRESETS_DIR/||")
    run_test "$name" "python3 -c 'import yaml; yaml.safe_load(open(\"$file\"))'"
done

echo ""
echo "--- Helm Lint Validation ---"
for file in $(find "$PRESETS_DIR" -name "*.yaml" -type f); do
    name=$(echo "$file" | sed "s|$PRESETS_DIR/||")
    run_test "helm-lint:$name" "helm lint $PROJECT_ROOT/charts/spark-3.5 -f $file > /dev/null 2>&1"
done

echo ""
echo "--- Script Syntax Validation ---"
for file in $(find "$PROJECT_ROOT/scripts" -name "*.sh" -type f); do
    name=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
    run_test "$name" "bash -n $file"
done

echo ""
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    echo -e "$ERRORS"
    exit 1
else
    echo ""
    echo "✓ All tests passed!"
    exit 0
fi
