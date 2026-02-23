#!/bin/bash
# Hive Metadata Verification Script
# Verifies Hive Metastore metadata consistency and integrity
#
# Usage:
#   verify-hive-metadata.sh --namespace <name> [OPTIONS]
#
# Examples:
#   verify-hive-metadata.sh --namespace spark-operations
#   verify-hive-metadata.sh --namespace spark-operations --repair
#   verify-hive-metadata.sh --namespace spark-operations --output /tmp/report.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
HIVE_METASTORE_POD=""
OUTPUT=""
REPAIR=false
VERBOSE=false
FAIL_ON_WARNINGS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Result tracking
declare -i total_checks=0
declare -i passed_checks=0
declare -i failed_checks=0
declare -i warnings=0

usage() {
    cat <<EOF
Usage: $(basename "$0") --namespace <name> [OPTIONS]

Verify Hive Metastore metadata consistency and integrity.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -p, --pod NAME            Hive Metastore pod name (auto-detected if not specified)
    -o, --output FILE         Output report to file (JSON format)
    -r, --repair              Attempt to repair issues found
    -w, --fail-on-warnings    Exit with error code on warnings
    -v, --verbose             Enable verbose output
    -h, --help                Show this help

EXAMPLES:
    # Basic verification
    $(basename "$0") --namespace spark-operations

    # Verify and repair
    $(basename "$0") --namespace spark-operations --repair

    # Output report to file
    $(basename "$0") --namespace spark-operations --output /tmp/report.json

    # Fail on warnings (for CI/CD)
    $(basename "$0") --namespace spark-operations --fail-on-warnings
EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((warnings++)) || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    ((failed_checks++)) || true
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((passed_checks++)) || true
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -p|--pod)
                HIVE_METASTORE_POD="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -r|--repair)
                REPAIR=true
                shift
                ;;
            -w|--fail-on-warnings)
                FAIL_ON_WARNINGS=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                ;;
        esac
    done
}

check_prerequisites() {
    ((total_checks++))

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        return 1
    fi

    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        return 1
    fi

    log_pass "Prerequisites check passed"
}

get_hive_metastore_pod() {
    if [[ -z "$HIVE_METASTORE_POD" ]]; then
        HIVE_METASTORE_POD=$(kubectl get pods -n "$NAMESPACE" \
            -l app=hive-metastore -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

        if [[ -z "$HIVE_METASTORE_POD" ]]; then
            log_error "Hive Metastore pod not found"
            return 1
        fi
    fi

    if ! kubectl get pod -n "$NAMESPACE" "$HIVE_METASTORE_POD" &> /dev/null; then
        log_error "Hive Metastore pod $HIVE_METASTORE_POD not found"
        return 1
    fi

    if [[ "$VERBOSE" == true ]]; then
        log_info "Using Hive Metastore pod: $HIVE_METASTORE_POD"
    fi
}

check_hive_metastore_health() {
    ((total_checks++))

    if ! kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -e "SHOW DATABASES;" &> /dev/null; then
        log_error "Hive Metastore is not healthy"
        return 1
    fi

    log_pass "Hive Metastore is healthy"
}

check_database_count() {
    ((total_checks++))

    local db_count
    db_count=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM DBS;" 2>/dev/null | tail -1 || echo "0")

    if [[ "$db_count" -lt 1 ]]; then
        log_warn "Database count is low: $db_count"
        return 1
    fi

    log_pass "Database count: $db_count"

    if [[ "$OUTPUT" ]]; then
        echo "database_count=$db_count" >> "$OUTPUT.tmp"
    fi
}

check_table_count() {
    ((total_checks++))

    local table_count
    table_count=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM TBLS;" 2>/dev/null | tail -1 || echo "0")

    if [[ "$table_count" -lt 1 ]]; then
        log_warn "Table count is low: $table_count"
        return 1
    fi

    log_pass "Table count: $table_count"

    if [[ "$OUTPUT" ]]; then
        echo "table_count=$table_count" >> "$OUTPUT.tmp"
    fi
}

check_partition_count() {
    ((total_checks++))

    local partition_count
    partition_count=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM PARTITIONS;" 2>/dev/null | tail -1 || echo "0")

    log_pass "Partition count: $partition_count"

    if [[ "$OUTPUT" ]]; then
        echo "partition_count=$partition_count" >> "$OUTPUT.tmp"
    fi
}

check_storage_descriptors() {
    ((total_checks++))

    local invalid_sd
    invalid_sd=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM TBLS WHERE SD_ID NOT IN (SELECT SD_ID FROM STORAGE_DESCS);" 2>/dev/null | tail -1 || echo "0")

    if [[ "$invalid_sd" -gt 0 ]]; then
        log_error "Found $invalid_sd tables with invalid storage descriptors"
        repair_storage_descriptors "$invalid_sd"
        return 1
    fi

    log_pass "All storage descriptors are valid"
}

repair_storage_descriptors() {
    local count="$1"

    if [[ "$REPAIR" != true ]]; then
        log_warn "Run with --repair to fix storage descriptors"
        return
    fi

    log_info "Attempting to repair $count storage descriptors..."

    # Get affected tables
    kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -e "SELECT TBL_NAME, DB_ID FROM TBLS WHERE SD_ID NOT IN (SELECT SD_ID FROM STORAGE_DESCS);" > /tmp/invalid_tables.txt

    # Create default storage descriptor for each
    while read -r table_name db_id; do
        kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
            hive -e "ALTER TABLE $table_name SET SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe';"
    done < /tmp/invalid_tables.txt

    log_info "Storage descriptor repair complete"
}

check_orphaned_partitions() {
    ((total_checks++))

    local orphaned
    orphaned=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM PARTITIONS WHERE TBL_ID NOT IN (SELECT TBL_ID FROM TBLS);" 2>/dev/null | tail -1 || echo "0")

    if [[ "$orphaned" -gt 0 ]]; then
        log_warn "Found $orphaned orphaned partitions"
        repair_orphaned_partitions "$orphaned"
        return 1
    fi

    log_pass "No orphaned partitions found"
}

repair_orphaned_partitions() {
    local count="$1"

    if [[ "$REPAIR" != true ]]; then
        log_warn "Run with --repair to clean up orphaned partitions"
        return
    fi

    log_info "Cleaning up $orphaned orphaned partitions..."

    kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -e "DELETE FROM PARTITIONS WHERE TBL_ID NOT IN (SELECT TBL_ID FROM TBLS);"

    log_info "Orphaned partitions cleaned up"
}

check_s3_path_consistency() {
    ((total_checks++))

    local invalid_paths
    invalid_paths=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM TBLS T JOIN STORAGE_DESCS S ON T.SD_ID = S.SD_ID WHERE S.LOCATION NOT LIKE 's3a://%' AND S.LOCATION NOT LIKE 's3://%' AND S.LOCATION NOT LIKE 'hdfs://%';" 2>/dev/null | tail -1 || echo "0")

    if [[ "$invalid_paths" -gt 0 ]]; then
        log_warn "Found $invalid_paths tables with invalid S3 paths"
        return 1
    fi

    log_pass "S3 path consistency verified"
}

check_table_locations() {
    ((total_checks++))

    local missing_locations
    missing_locations=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT COUNT(*) FROM TBLS T JOIN STORAGE_DESCS S ON T.SD_ID = S.SD_ID WHERE S.LOCATION IS NULL OR S.LOCATION = '';" 2>/dev/null | tail -1 || echo "0")

    if [[ "$missing_locations" -gt 0 ]]; then
        log_error "Found $missing_locations tables with missing locations"
        return 1
    fi

    log_pass "All tables have valid locations"
}

check_duplicate_tables() {
    ((total_checks++))

    local duplicates
    duplicates=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "SELECT TBL_NAME, COUNT(*) FROM TBLS GROUP BY TBL_NAME HAVING COUNT(*) > 1;" 2>/dev/null | wc -l)

    if [[ "$duplicates" -gt 0 ]]; then
        log_warn "Found $duplicates duplicate table names"
        return 1
    fi

    log_pass "No duplicate table names found"
}

run_all_checks() {
    log_info "Running metadata verification checks..."
    echo ""

    check_prerequisites
    get_hive_metastore_pod
    check_hive_metastore_health
    check_database_count
    check_table_count
    check_partition_count
    check_storage_descriptors
    check_orphaned_partitions
    check_s3_path_consistency
    check_table_locations
    check_duplicate_tables

    echo ""
    log_info "Verification complete"
}

generate_report() {
    local exit_code=0

    echo ""
    echo "=== Verification Summary ==="
    echo "Total checks: $total_checks"
    echo "Passed: $passed_checks"
    echo "Failed: $failed_checks"
    echo "Warnings: $warnings"
    echo ""

    if [[ "$failed_checks" -gt 0 ]]; then
        echo "Status: FAILED"
        exit_code=1
    elif [[ "$warnings" -gt 0 ]] && [[ "$FAIL_ON_WARNINGS" == true ]]; then
        echo "Status: FAILED (warnings as errors)"
        exit_code=1
    else
        echo "Status: PASSED"
        exit_code=0
    fi

    if [[ "$OUTPUT" ]]; then
        cat > "$OUTPUT" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "namespace": "$NAMESPACE",
  "hive_metastore_pod": "$HIVE_METASTORE_POD",
  "total_checks": $total_checks,
  "passed_checks": $passed_checks,
  "failed_checks": $failed_checks,
  "warnings": $warnings,
  "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")"
}
EOF
        log_info "Report written to: $OUTPUT"
    fi

    return $exit_code
}

main() {
    parse_args "$@"

    log_info "=== Hive Metadata Verification ==="
    log_info "Namespace: $NAMESPACE"

    run_all_checks

    generate_report
}

main "$@"
