#!/bin/bash
# Runbook Validation Script
# Validates runbook structure, syntax, and content

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNBOOK_DIR="${RUNBOOK_DIR:-/home/fall_out_bug/work/s7/spark_k8s/docs/operations/runbooks}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validate runbook structure and content.

OPTIONS:
    -r, --runbook NAME      Runbook name (leave empty for all)
    -d, --runbook-dir DIR   Runbook directory (default: docs/operations/runbooks)
    -s, --strict            Enable strict validation
    -o, --output FORMAT     Output format: json|text (default: text)
    -h, --help              Show this help

EXAMPLES:
    $(basename "$0") --runbook spark/driver-crash-loop.md
    $(basename "$0") --strict
    $(basename "$0") -o json
EOF
    exit 1
}

RUNBOOK=""
STRICT=false
OUTPUT="text"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--runbook)
                RUNBOOK="$2"
                shift 2
                ;;
            -d|--runbook-dir)
                RUNBOOK_DIR="$2"
                shift 2
                ;;
            -s|--strict)
                STRICT=true
                shift
                ;;
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

validate_runbook() {
    local runbook_path="$1"
    local errors=0
    local warnings=0

    echo "Validating: $runbook_path"

    # Check file exists
    if [[ ! -f "$runbook_path" ]]; then
        echo "  [ERROR] File not found"
        return 1
    fi

    # Check file extension
    if [[ "$runbook_path" != *.md ]]; then
        echo "  [ERROR] Not a markdown file"
        errors=$((errors + 1))
    fi

    # Check for required sections
    local required_sections=("Overview" "Detection" "Diagnosis" "Remediation")
    for section in "${required_sections[@]}"; do
        if ! grep -q "## $section" "$runbook_path"; then
            if [[ "$STRICT" == true ]]; then
                echo "  [ERROR] Missing required section: $section"
                errors=$((errors + 1))
            else
                echo "  [WARN] Missing recommended section: $section"
                warnings=$((warnings + 1))
            fi
        fi
    done

    # Check for optional but recommended sections
    local recommended_sections=("Prevention" "Related Runbooks" "References")
    for section in "${recommended_sections[@]}"; do
        if ! grep -q "## $section" "$runbook_path"; then
            echo "  [INFO] Missing recommended section: $section"
        fi
    done

    # Check for code blocks
    if ! grep -q '```' "$runbook_path"; then
        echo "  [WARN] No code blocks found"
        warnings=$((warnings + 1))
    fi

    # Check for broken links
    local links=$(grep -o '\[.*\]([^)]*)' "$runbook_path" | grep -o '([^)]*)' | tr -d '()')
    for link in $links; do
        if [[ "$link" == http* ]]; then
            if ! curl -s -o /dev/null -w "%{http_code}" "$link" | grep -q "200"; then
                echo "  [WARN] Broken link: $link"
                warnings=$((warnings + 1))
            fi
        fi
    done

    # Check for command examples
    if ! grep -q '```bash' "$runbook_path"; then
        echo "  [INFO] No bash examples found"
    fi

    echo "  Validation complete: $errors errors, $warnings warnings"

    return $errors
}

main() {
    parse_args "$@"

    if [[ -n "$RUNBOOK" ]]; then
        local runbook_path="$RUNBOOK_DIR/$RUNBOOK"
        validate_runbook "$runbook_path"
    else
        echo "Validating all runbooks in $RUNBOOK_DIR"
        echo ""

        find "$RUNBOOK_DIR" -name "*.md" -type f | while read -r runbook; do
            validate_runbook "$runbook"
            echo ""
        done
    fi
}

main "$@"
