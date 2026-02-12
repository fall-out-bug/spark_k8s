#!/bin/bash
# Validate commit messages against conventional commits specification
#
# Usage:
#   ./validate-commits.sh --target-branch <branch>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
TARGET_BRANCH=""
ALLOWED_TYPES=("feat" "fix" "docs" "style" "refactor" "test" "chore" "perf" "ci")
INVALID_COUNT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-branch)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET_BRANCH" ]]; then
    log_error "Usage: $0 --target-branch <branch>"
    exit 1
fi

log_info "=== Validating Commits ==="
log_info "Target branch: ${TARGET_BRANCH}"

# Get list of commits to validate
COMMITS=$(git rev-list --no-merges "${TARGET_BRANCH}..HEAD" 2>/dev/null || true)

if [[ -z "$COMMITS" ]]; then
    log_info "No commits to validate"
    exit 0
fi

COMMIT_COUNT=$(echo "$COMMITS" | wc -l)
log_info "Found ${COMMIT_COUNT} commit(s) to validate"

# Conventional commits pattern: type(scope): description
PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\(.+\))?: .{1,72}$'

# Validate each commit
for commit in $COMMITS; do
    MESSAGE=$(git log -1 --format="%s" "$commit")
    BODY=$(git log -1 --format="%b" "$commit")
    AUTHOR=$(git log -1 --format="%an" "$commit")

    if [[ ! "$MESSAGE" =~ $PATTERN ]]; then
        log_error "✗ Invalid commit format: ${MESSAGE}"
        log_error "  Author: ${AUTHOR}"
        log_error "  Expected: type(scope): description (max 72 chars)"
        log_error "  Allowed types: ${ALLOWED_TYPES[*]}"
        ((INVALID_COUNT++))
    else
        # Extract type
        TYPE=$(echo "$MESSAGE" | cut -d':' -f1 | cut -d'(' -f1)

        # Check if type is allowed
        if [[ ! " ${ALLOWED_TYPES[@]} " =~ " ${TYPE} " ]]; then
            log_warn "⚠ Unknown commit type: ${TYPE}"
            ((INVALID_COUNT++))
        else
            if [[ "$INVALID_COUNT" -eq 0 ]]; then
                log_info "✓ ${MESSAGE}"
            fi
        fi
    fi

    # Check for WIP commits
    if [[ "$MESSAGE" =~ [Ww][Ii][Pp] ]] || [[ "$MESSAGE" =~ [Ww][Ii][Pp] ]]; then
        log_error "✗ WIP commit found: ${MESSAGE}"
        ((INVALID_COUNT++))
    fi

    # Check commit body length
    BODY_LINES=$(echo "$BODY" | grep -c "." || echo "0")
    if [[ $BODY_LINES -gt 0 ]]; then
        LONG_LINES=$(echo "$BODY" | awk 'length > 72' | wc -l)
        if [[ $LONG_LINES -gt 0 ]]; then
            log_warn "⚠ Commit body has lines > 72 chars: ${MESSAGE}"
        fi
    fi
done

# Summary
log_info "=== Validation Summary ==="

if [[ $INVALID_COUNT -eq 0 ]]; then
    log_info "✓ All ${COMMIT_COUNT} commit(s) are valid"
    exit 0
else
    log_error "✗ ${INVALID_COUNT} commit(s) failed validation"
    exit 1
fi
