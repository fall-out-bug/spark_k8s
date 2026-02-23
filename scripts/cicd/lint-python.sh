#!/bin/bash
# Lint Python code using flake8, black, isort, mypy
#
# Usage:
#   ./lint-python.sh --dir <path> [--fix]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
CODE_DIR=""
FIX=false
CONFIG_DIR="$(cd "$SCRIPT_DIR" && cd ../.. && pwd)/configs/codestyle"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            CODE_DIR="$2"
            shift 2
            ;;
        --fix)
            FIX=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$CODE_DIR" ]]; then
    log_error "Usage: $0 --dir <path> [--fix]"
    exit 1
fi

log_info "=== Python Code Linting ==="
log_info "Directory: ${CODE_DIR}"
log_info "Config: ${CONFIG_DIR}"

declare -i ERRORS=0

# 1. Format with black
log_info "Running black..."

if command -v black &> /dev/null; then
    if [[ "$FIX" == "true" ]]; then
        black --config "$CONFIG_DIR/pyproject.toml" "$CODE_DIR"
    else
        black --check --config "$CONFIG_DIR/pyproject.toml" "$CODE_DIR"
    fi
else
    log_warn "black not found, skipping"
fi

# 2. Sort imports with isort
log_info "Running isort..."

if command -v isort &> /dev/null; then
    if [[ "$FIX" == "true" ]]; then
        isort --settings-path "$CONFIG_DIR/pyproject.toml" "$CODE_DIR"
    else
        isort --check-only --settings-path "$CONFIG_DIR/pyproject.toml" "$CODE_DIR" || ((ERRORS++))
    fi
else
    log_warn "isort not found, skipping"
fi

# 3. Lint with flake8
log_info "Running flake8..."

if command -v flake8 &> /dev/null; then
    if [[ -f "$CONFIG_DIR/.flake8" ]]; then
        flake8 --config="$CONFIG_DIR/.flake8" "$CODE_DIR" || ((ERRORS++))
    else
        flake8 --max-line-length=100 "$CODE_DIR" || ((ERRORS++))
    fi
else
    log_warn "flake8 not found, skipping"
fi

# 4. Type check with mypy
log_info "Running mypy..."

if command -v mypy &> /dev/null; then
    mypy --strict "$CODE_DIR" 2>/dev/null || log_warn "mypy found issues (non-blocking)"
else
    log_info "mypy not found, skipping type checking"
fi

# 5. Security scan with bandit
log_info "Running bandit security scan..."

if command -v bandit &> /dev/null; then
    bandit -r "$CODE_DIR" -f txt -o /tmp/bandit-report.txt || true

    # Check for critical issues
    if grep -q "Issue: \[High" /tmp/bandit-report.txt 2>/dev/null; then
        log_error "Critical security issues found:"
        grep "Issue: \[High" /tmp/bandit-report.txt
        ((ERRORS++))
    elif grep -q "Issue: \[Medium" /tmp/bandit-report.txt 2>/dev/null; then
        log_warn "Medium security issues found:"
        grep "Issue: \[Medium" /tmp/bandit-report.txt
    fi

    rm -f /tmp/bandit-report.txt
else
    log_info "bandit not found, skipping security scan"
fi

# Summary
log_info "=== Lint Summary ==="

if [[ $ERRORS -eq 0 ]]; then
    log_info "✓ All checks passed"
else
    log_error "✗ Found ${ERRORS} issues"
fi

exit $ERRORS
