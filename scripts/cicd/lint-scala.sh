#!/bin/bash
# Lint Scala code using scalafmt and scalastyle
#
# Usage:
#   ./lint-scala.sh --dir <path> [--fix]

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

log_info "=== Scala Code Linting ==="
log_info "Directory: ${CODE_DIR}"
log_info "Config: ${CONFIG_DIR}"

declare -i ERRORS=0

# 1. Format with scalafmt
log_info "Running scalafmt..."

if command -v scalafmt &> /dev/null; then
    if [[ "$FIX" == "true" ]]; then
        scalafmt --config "$CONFIG_DIR/scalafmt.conf" "$CODE_DIR"
    else
        scalafmt --config "$CONFIG_DIR/scalafmt.conf" --test "$CODE_DIR" || ((ERRORS++))
    fi
else
    log_warn "scalafmt not found, skipping"
fi

# 2. Check style with scalastyle
log_info "Running scalastyle..."

if command -v scalastyle &> /dev/null; then
    if [[ -f "$CONFIG_DIR/scalastyle-config.xml" ]]; then
        scalastyle --config "$CONFIG_DIR/scalastyle-config.xml" "$CODE_DIR" || ((ERRORS++))
    else
        # Create default scalastyle config
        log_info "Using default scalastyle configuration"
        scalastyle --config "$CONFIG_DIR/scalastyle-config.xml" "$CODE_DIR" 2>/dev/null || log_warn "scalastyle found issues (non-blocking)"
    fi
else
    log_info "scalastyle not found, skipping style checks"
fi

# 3. Check for common anti-patterns
log_info "Checking for Scala anti-patterns..."

# Find all Scala files
SCALA_FILES=$(find "$CODE_DIR" -name "*.scala" -type f 2>/dev/null || true)

if [[ -n "$SCALA_FILES" ]]; then
    # Check for mutable collections in val
    while IFS= read -r file; do
        if grep -qE "val.*mutable\.(ArrayBuffer|ListBuffer|HashMap)" "$file" 2>/dev/null; then
            log_warn "Found mutable collection in val: $file"
        fi
    done <<< "$SCALA_FILES"

    # Check for empty catch blocks
    while IFS= read -r file; do
        if grep -qE "catch\s*\{\s*\}" "$file" 2>/dev/null; then
            log_error "Found empty catch block: $file"
            ((ERRORS++))
        fi
    done <<< "$SCALA_FILES"

    # Check for return statements in functions (anti-functional)
    while IFS= read -r file; do
        if grep -qE "^\s*return " "$file" 2>/dev/null; then
            log_warn "Found return statement (consider functional style): $file"
        fi
    done <<< "$SCALA_FILES"
else
    log_info "No Scala files found"
fi

# Summary
log_info "=== Lint Summary ==="

if [[ $ERRORS -eq 0 ]]; then
    log_info "✓ All checks passed"
else
    log_error "✗ Found ${ERRORS} issues"
fi

exit $ERRORS
