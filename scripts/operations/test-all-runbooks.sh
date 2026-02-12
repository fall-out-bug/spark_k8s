#!/bin/bash
# Test all operational runbooks for syntax, dry-run execution, and accuracy
#
# Usage:
#   ./test-all-runbooks.sh [--syntax-only] [--dry-run] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
SYNTAX_ONLY=false
DRY_RUN=true
VERBOSE=false
RUNBOOK_DIR="$(cd "$SCRIPT_DIR" && cd ../.. && pwd)/docs/operations/runbooks"
PASSING=0
FAILING=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --syntax-only)
            SYNTAX_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-dry-run)
            DRY_RUN=false
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "=== Runbook Testing Suite ==="
log_info "Runbook directory: ${RUNBOOK_DIR}"
log_info "Syntax only: ${SYNTAX_ONLY}"
log_info "Dry run: ${DRY_RUN}"

# Find all runbook scripts
RUNBOOK_SCRIPTS=$(find "${SCRIPT_DIR}" -name "*.sh" -type f | grep -v test-all-runbooks.sh || true)

if [[ -z "$RUNBOOK_SCRIPTS" ]]; then
    log_info "No runbook scripts found"
    exit 0
fi

SCRIPT_COUNT=$(echo "$RUNBOOK_SCRIPTS" | wc -l)
log_info "Found ${SCRIPT_COUNT} runbook scripts to test"

# Test 1: Syntax validation
log_info "=== Test 1: Syntax Validation ==="

for script in $RUNBOOK_SCRIPTS; do
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Checking syntax: $(basename "$script")"
    fi

    if bash -n "$script" 2>/dev/null; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  ✓ Syntax OK"
        fi
        ((PASSING++))
    else
        log_error "✗ Syntax error in: $script"
        bash -n "$script"  # Show the error
        ((FAILING++))
    fi
done

if [[ "$SYNTAX_ONLY" == "true" ]]; then
    log_info "=== Syntax Test Complete ==="
    log_info "Passing: ${PASSING}"
    log_info "Failing: ${FAILING}"

    if [[ $FAILING -eq 0 ]]; then
        log_info "✓ All syntax checks passed"
        exit 0
    else
        log_error "✗ ${FAILING} script(s) have syntax errors"
        exit 1
    fi
fi

# Test 2: Required elements
log_info "=== Test 2: Required Elements ==="

for script in $RUNBOOK_SCRIPTS; do
    SCRIPT_NAME=$(basename "$script")
    ISSUES=0

    # Check for usage/help
    if ! grep -q "Usage:" "$script"; then
        log_warn "Missing usage info: ${SCRIPT_NAME}"
        ((ISSUES++))
    fi

    # Check for common.sh source
    if ! grep -q "source.*common.sh" "$script"; then
        log_warn "Missing common.sh source: ${SCRIPT_NAME}"
        ((ISSUES++))
    fi

    # Check for error handling
    if ! grep -q "set -e" "$script"; then
        log_warn "Missing 'set -e': ${SCRIPT_NAME}"
        ((ISSUES++))
    fi

    # Check for logging functions
    if ! grep -q "log_info\|log_error\|log_warn" "$script"; then
        log_warn "Missing logging functions: ${SCRIPT_NAME}"
        ((ISSUES++))
    fi

    if [[ $ISSUES -eq 0 ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "✓ ${SCRIPT_NAME}: All required elements present"
        fi
    else
        ((WARNINGS++))
    fi
done

# Test 3: Dry-run execution
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "=== Test 3: Dry-run Execution ==="

    for script in $RUNBOOK_SCRIPTS; do
        SCRIPT_NAME=$(basename "$script")

        # Check if script supports --dry-run or --help
        if grep -q -- "--dry-run" "$script"; then
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "Testing dry-run: ${SCRIPT_NAME}"
            fi

            # Try to run with --dry-run (may require namespace)
            if timeout 10 "$script" --help &>/dev/null || \
               timeout 10 "$script" --dry-run --namespace test &>/dev/null; then
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "  ✓ Dry-run successful"
                fi
            else
                log_warn "Dry-run failed or timed out: ${SCRIPT_NAME}"
                ((WARNINGS++))
            fi
        else
            log_warn "No --dry-run support: ${SCRIPT_NAME}"
            ((WARNINGS++))
        fi
    done
fi

# Test 4: Runbook documentation validation
log_info "=== Test 4: Runbook Documentation ==="

if [[ -d "$RUNBOOK_DIR" ]]; then
    RUNBOOK_DOCS=$(find "$RUNBOOK_DIR" -name "*.md" -type f || true)

    for doc in $RUNBOOK_DOCS; do
        DOC_NAME=$(basename "$doc")

        # Check for required sections
        if ! grep -q "## Severity" "$doc"; then
            log_warn "Missing severity section: ${DOC_NAME}"
            ((WARNINGS++))
        fi

        if ! grep -q "## Detection" "$doc" && ! grep -q "## Symptoms" "$doc"; then
            log_warn "Missing detection/symptoms: ${DOC_NAME}"
            ((WARNINGS++))
        fi

        if ! grep -q "## Resolution" "$doc" && ! grep -q "## Steps" "$doc"; then
            log_warn "Missing resolution steps: ${DOC_NAME}"
            ((WARNINGS++))
        fi

        # Check for broken links
        if grep -qE '(\[.*\]\()|<http' "$doc"; then
            # Extract URLs and check (basic check)
            BROKEN=$(grep -oE '(http|https)://[^)]+' "$doc" | while read -r url; do
                if ! curl -s -f -I "$url" &>/dev/null; then
                    echo "$url"
                fi
            done || true)

            if [[ -n "$BROKEN" ]]; then
                log_warn "Possible broken links in ${DOC_NAME}:"
                echo "$BROKEN"
            fi
        fi
    done
else
    log_info "Runbook directory not found: ${RUNBOOK_DIR}"
fi

# Summary
log_info "=== Test Summary ==="
log_info "Passing checks: ${PASSING}"
log_info "Failing checks: ${FAILING}"
log_info "Warnings: ${WARNINGS}"

if [[ $FAILING -eq 0 ]]; then
    log_info "✓ All critical tests passed"

    if [[ $WARNINGS -gt 0 ]]; then
        log_info "⚠ ${WARNINGS} warning(s) - review recommended"
    fi

    exit 0
else
    log_error "✗ ${FAILING} test(s) failed"
    exit 1
fi
