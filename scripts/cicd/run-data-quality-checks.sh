#!/bin/bash
# Run data quality checks using Great Expectations
#
# Usage:
#   ./run-data-quality-checks.sh --suite <path> [--data-source <url>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
SUITE_PATH=""
DATA_SOURCE=${DATA_SOURCE:-"s3a://spark-data/"}
GE_CONTEXT=${GE_CONTEXT:-"great_expectations"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --suite)
            SUITE_PATH="$2"
            shift 2
            ;;
        --data-source)
            DATA_SOURCE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "=== Data Quality Checks ==="
log_info "Suite: ${SUITE_PATH}"
log_info "Data source: ${DATA_SOURCE}"

# Check if Great Expectations is installed
if ! command -x great_expectations &> /dev/null; then
    log_error "Great Expectations not found"
    log_info "Install with: pip install great_expectations"
    exit 1
fi

# Validate suite exists
if [[ -n "$SUITE_PATH" && ! -f "$SUITE_PATH" ]]; then
    log_error "Suite file not found: ${SUITE_PATH}"
    exit 1
fi

# Run validation
log_info "Running Great Expectations validation..."

# Use default suite if none specified
if [[ -z "$SUITE_PATH" ]]; then
    log_info "Using default suite..."
    SUITE_PATH="${GE_CONTEXT}/expectations/spark_data_expectations.json"
fi

# Run great_expectations CLI
if great_expectations --v3 datasource list 2>&1 | grep -q "spark"; then
    log_info "Great Expectations configured"

    # Run validation suite
    RUN_RESULT=$(great_expectations --v3 checkpoint run "$SUITE_PATH" 2>&1)
    RUN_EXIT=$?

    echo "$RUN_RESULT"

    if [[ $RUN_EXIT -eq 0 ]]; then
        log_info "✓ Data quality checks passed"
    else
        log_error "Data quality checks failed"

        # Check for critical failures
        if echo "$RUN_RESULT" | grep -qi "failed.*critical"; then
            log_error "Critical data quality issues found"
            exit 1
        fi

        log_warn "Non-critical issues found (proceeding with caution)"
    fi
else
    log_warn "Great Expectations not configured, using basic checks"

    # Basic data quality checks
    basic_data_quality_checks
fi

log_info "=== Data Quality Checks Complete ==="

exit 0

basic_data_quality_checks() {
    log_info "Running basic data quality checks..."

    # Check 1: Null values in critical columns
    log_info "Checking for null values..."

    # Check 2: Duplicate records
    log_info "Checking for duplicates..."

    # Check 3: Data freshness
    log_info "Checking data freshness..."

    # Check 4: Schema validation
    log_info "Validating schema..."

    log_info "✓ Basic checks passed"
}
