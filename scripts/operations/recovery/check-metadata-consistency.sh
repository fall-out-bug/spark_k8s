#!/bin/bash
# Metadata Consistency Check Script
# Checks consistency between Hive Metastore and actual data in S3/MinIO
#
# Usage:
#   check-metadata-consistency.sh --namespace <name> [OPTIONS]
#
# Examples:
#   check-metadata-consistency.sh --namespace spark-operations
#   check-metadata-consistency.sh --namespace spark-operations --repair
#   check-metadata-consistency.sh --namespace spark-operations --database production

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
DATABASE=""
TABLE=""
REPAIR=false
DRY_RUN=false
VERBOSE=false
OUTPUT_FORMAT="text"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Issue tracking
declare -i total_issues=0
declare -i missing_partitions=0
declare -i orphaned_metadata=0
declare -i schema_mismatches=0
declare -i permission_issues=0

usage() {
    cat <<EOF
Usage: $(basename "$0") --namespace <name> [OPTIONS]

Check consistency between Hive Metastore and actual data in S3/MinIO.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -d, --database NAME        Specific database to check (default: all)
    -t, --table NAME           Specific table to check
    -r, --repair               Attempt to repair issues found
    --dry-run                  Show what would be done without executing
    --output-format FORMAT     Output format: text, json (default: text)
    -v, --verbose              Enable verbose output
    -h, --help                 Show this help

EXAMPLES:
    # Check all databases and tables
    $(basename "$0") --namespace spark-operations

    # Check specific database
    $(basename "$0") --namespace spark-operations --database production

    # Check and repair issues
    $(basename "$0") --namespace spark-operations --repair

    # Dry run to see what would be fixed
    $(basename "$0") --namespace spark-operations --dry-run --verbose
EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[DEBUG] $*"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -d|--database)
                DATABASE="$2"
                shift 2
                ;;
            -t|--table)
                TABLE="$2"
                shift 2
                ;;
            -r|--repair)
                REPAIR=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --output-format)
                OUTPUT_FORMAT="$2"
                shift 2
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
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    if ! command -v aws &> /dev/null && ! command -v mc &> /dev/null; then
        log_error "Neither AWS CLI nor MinIO client found"
        exit 1
    fi

    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

get_hive_metastore_pod() {
    kubectl get pods -n "$NAMESPACE" \
        -l app=hive-metastore -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

get_s3_path_for_table() {
    local db="$1"
    local tbl="$2"

    local location
    location=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
        hive -S -e "DESCRIBE EXTENDED ${db}.${tbl};" 2>/dev/null | \
        grep "Location:" | awk '{print $2}' || echo "")

    # Convert s3a:// to s3://
    location=$(echo "$location" | sed 's|s3a://|s3://|')

    echo "$location"
}

check_partition_exists_in_s3() {
    local s3_path="$1"

    if command -v aws &> /dev/null && [[ "$s3_path" == s3://* ]]; then
        aws s3 ls "$s3_path" &> /dev/null
    elif command -v mc &> /dev/null && [[ "$s3_path" == minio://* ]]; then
        local minio_path=$(echo "$s3_path" | sed 's|minio://|minio/|')
        mc ls "$minio_path" &> /dev/null
    else
        return 1
    fi
}

check_missing_partitions() {
    log_info "Checking for missing partitions..."

    local databases
    if [[ -n "$DATABASE" ]]; then
        databases=("$DATABASE")
    else
        mapfile -t databases < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
            hive -S -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    fi

    for db in "${databases[@]}"; do
        [[ -z "$db" ]] && continue

        local tables
        if [[ -n "$TABLE" ]]; then
            tables=("$TABLE")
        else
            mapfile -t tables < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "SHOW TABLES IN $db;" 2>/dev/null | tail -n +2)
        fi

        for tbl in "${tables[@]}"; do
            [[ -z "$tbl" ]] && continue

            # Check if table is partitioned
            local partitioned
            partitioned=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "DESCRIBE EXTENDED ${db}.${tbl};" 2>/dev/null | \
                grep "partitionKeys:" | wc -l)

            if [[ "$partitioned" -eq 0 ]]; then
                log_verbose "Table $db.$tbl is not partitioned, skipping"
                continue
            fi

            # Get table location
            local table_location
            table_location=$(get_s3_path_for_table "$db" "$tbl")

            if [[ -z "$table_location" ]]; then
                log_error "Could not get location for $db.$tbl"
                continue
            fi

            log_verbose "Checking $db.$tbl at $table_location"

            # Get partitions from metastore
            local partitions
            mapfile -t partitions < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "SHOW PARTITIONS ${db}.${tbl};" 2>/dev/null | tail -n +2)

            for part in "${partitions[@]}"; do
                [[ -z "$part" ]] && continue

                # Convert partition format to S3 path
                local part_path
                part_path=$(echo "$part" | sed 's|/|/=|g' | sed 's|^|/|' | sed 's|=|/|g')
                local s3_path="${table_location}${part_path}"

                if ! check_partition_exists_in_s3 "$s3_path"; then
                    log_warn "Missing partition: $db.$tbl $part"
                    log_verbose "  S3 path: $s3_path"
                    ((missing_partitions++)) || true
                    ((total_issues++)) || true
                fi
            done
        done
    done
}

repair_missing_partitions() {
    if [[ "$REPAIR" != true ]]; then
        return
    fi

    log_info "Repairing missing partitions..."

    local databases
    if [[ -n "$DATABASE" ]]; then
        databases=("$DATABASE")
    else
        mapfile -t databases < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
            hive -S -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    fi

    for db in "${databases[@]}"; do
        [[ -z "$db" ]] && continue

        local tables
        if [[ -n "$TABLE" ]]; then
            tables=("$TABLE")
        else
            mapfile -t tables < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "SHOW TABLES IN $db;" 2>/dev/null | tail -n +2)
        fi

        for tbl in "${tables[@]}"; do
            [[ -z "$tbl" ]] && continue

            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would run MSCK REPAIR TABLE $db.$tbl"
            else
                log_verbose "Running MSCK REPAIR TABLE $db.$tbl"
                kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                    hive -S -e "MSCK REPAIR TABLE ${db}.${tbl};" &> /dev/null || true
            fi
        done
    done
}

check_orphaned_metadata() {
    log_info "Checking for orphaned metadata..."

    # This is a simplified check - in reality you'd need to compare
    # S3 listings with metastore partitions

    local databases
    if [[ -n "$DATABASE" ]]; then
        databases=("$DATABASE")
    else
        mapfile -t databases < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
            hive -S -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    fi

    for db in "${databases[@]}"; do
        [[ -z "$db" ]] && continue

        local tables
        if [[ -n "$TABLE" ]]; then
            tables=("$TABLE")
        else
            mapfile -t tables < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "SHOW TABLES IN $db;" 2>/dev/null | tail -n +2)
        fi

        for tbl in "${tables[@]}"; do
            [[ -z "$tbl" ]] && continue

            # Check for tables with no partitions but data exists
            local partition_count
            partition_count=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "SHOW PARTITIONS ${db}.${tbl};" 2>/dev/null | tail -n +2 | wc -l)

            if [[ "$partition_count" -eq 0 ]]; then
                local table_location
                table_location=$(get_s3_path_for_table "$db" "$tbl")

                if [[ -n "$table_location" ]] && check_partition_exists_in_s3 "$table_location"; then
                    log_warn "Orphaned data: $db.$tbl has data but no partition metadata"
                    ((orphaned_metadata++)) || true
                    ((total_issues++)) || true
                fi
            fi
        done
    done
}

check_schema_consistency() {
    log_info "Checking schema consistency..."

    local databases
    if [[ -n "$DATABASE" ]]; then
        databases=("$DATABASE")
    else
        mapfile -t databases < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
            hive -S -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    fi

    for db in "${databases[@]}"; do
        [[ -z "$db" ]] && continue

        local tables
        if [[ -n "$TABLE" ]]; then
            tables=("$TABLE")
        else
            mapfile -t tables < <(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "SHOW TABLES IN $db;" 2>/dev/null | tail -n +2)
        done

        for tbl in "${tables[@]}"; do
            [[ -z "$tbl" ]] && continue

            # Get table schema from metastore
            local schema
            schema=$(kubectl exec -n "$NAMESPACE" "$HIVE_METASTORE_POD" -- \
                hive -S -e "DESCRIBE ${db}.${tbl};" 2>/dev/null | tail -n +3 | head -n -3)

            if [[ -z "$schema" ]]; then
                log_warn "Could not get schema for $db.$tbl"
                ((schema_mismatches++)) || true
                ((total_issues++)) || true
            fi
        done
    done
}

generate_report() {
    log_info "=== Consistency Check Report ==="
    log_info "Total issues: $total_issues"
    log_info "Missing partitions: $missing_partitions"
    log_info "Orphaned metadata: $orphaned_metadata"
    log_info "Schema mismatches: $schema_mismatches"

    local status="PASSED"
    if [[ "$total_issues" -gt 0 ]]; then
        status="FAILED"
    fi

    log_info "Status: $status"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "namespace": "$NAMESPACE",
  "database": "${DATABASE:-all}",
  "table": "${TABLE:-all}",
  "total_issues": $total_issues,
  "missing_partitions": $missing_partitions,
  "orphaned_metadata": $orphaned_metadata,
  "schema_mismatches": $schema_mismatches,
  "status": "$status"
}
EOF
    fi

    if [[ "$total_issues" -gt 0 ]]; then
        return 1
    fi
    return 0
}

main() {
    parse_args "$@"

    log_info "=== Metadata Consistency Check ==="
    log_info "Namespace: $NAMESPACE"
    log_info "Database: ${DATABASE:-All}"
    log_info "Table: ${TABLE:-All}"

    check_prerequisites

    HIVE_METASTORE_POD=$(get_hive_metastore_pod)

    if [[ -z "$HIVE_METASTORE_POD" ]]; then
        log_error "Hive Metastore pod not found"
        exit 1
    fi

    log_info "Using Hive Metastore pod: $HIVE_METASTORE_POD"

    check_missing_partitions
    check_orphaned_metadata
    check_schema_consistency

    if [[ "$REPAIR" == true ]]; then
        repair_missing_partitions
    fi

    generate_report
}

main "$@"
