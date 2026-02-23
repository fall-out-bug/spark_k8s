#!/bin/bash
# Check that new files don't exceed size limits
#
# Usage:
#   ./check-file-sizes.sh --max-size <lines> [--ref <branch>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
MAX_SIZE=200
REF="origin/main"
OVERRIDE_FILE=".file-size-override"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        --ref)
            REF="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "=== Checking File Sizes ==="
log_info "Max lines: ${MAX_SIZE}"
log_info "Reference branch: ${REF}"

# Get list of changed files
CHANGED_FILES=$(git diff --name-only --diff-filter=d "${REF}..." 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    log_info "No changed files found"
    exit 0
fi

# Load override list
OVERRIDE_LIST=()
if [[ -f "$OVERRIDE_FILE" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] || OVERRIDE_LIST+=("$line")
    done < "$OVERRIDE_FILE"
fi

VIOLATIONS=0

for file in $CHANGED_FILES; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    # Skip binary files
    if grep -qI '.' "$file" 2>/dev/null; then
        LINE_COUNT=$(wc -l < "$file" || echo "0")

        if [[ $LINE_COUNT -gt $MAX_SIZE ]]; then
            # Check if file is in override list
            IS_OVERRIDDEN=false
            for pattern in "${OVERRIDE_LIST[@]}"; do
                if [[ "$file" == $pattern ]]; then
                    IS_OVERRIDDEN=true
                    break
                fi
            done

            if [[ "$IS_OVERRIDDEN" == "false" ]]; then
                log_error "✗ ${file}: ${LINE_COUNT} lines (max: ${MAX_SIZE})"
                ((VIOLATIONS++))
            else
                log_warn "⚠ ${file}: ${LINE_COUNT} lines (overridden)"
            fi
        fi
    fi
done

# Summary
log_info "=== Check Complete ==="

if [[ $VIOLATIONS -eq 0 ]]; then
    log_info "✓ All files within size limit"
    exit 0
else
    log_error "✗ ${VIOLATIONS} file(s) exceed size limit"

    if [[ ${#OVERRIDE_LIST[@]} -gt 0 ]]; then
        log_info ""
        log_info "To override, add to ${OVERRIDE_FILE}:"
        log_info "# Override large files (one pattern per line)"
        log_info "src/very-large-file.scala"
    fi

    exit 1
fi
