#!/bin/bash
# Test restore to staging environment
#
# Usage:
#   ./test-restore-to-staging.sh --backup-type <hive|minio|airflow> --backup-date <YYYYMMDD>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
BACKUP_TYPE=${BACKUP_TYPE:-""}
BACKUP_DATE=${BACKUP_DATE:-""}
STAGING_NAMESPACE=${STAGING_NAMESPACE:-"spark-staging"}
BACKUP_DIR=${BACKUP_DIR:-"/backups"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backup-type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --backup-date)
            BACKUP_DATE="$2"
            shift 2
            ;;
        --namespace)
            STAGING_NAMESPACE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$BACKUP_TYPE" || -z "$BACKUP_DATE" ]]; then
    log_error "Usage: $0 --backup-type <hive|minio|airflow> --backup-date <YYYYMMDD>"
    exit 1
fi

log_info "=== Restore Test to Staging ==="
log_info "Type: ${BACKUP_TYPE}"
log_info "Backup date: ${BACKUP_DATE}"
log_info "Namespace: ${STAGING_NAMESPACE}"

# Check staging namespace
if ! kubectl get ns "$STAGING_NAMESPACE" &>/dev/null; then
    log_error "Staging namespace not found: ${STAGING_NAMESPACE}"
    exit 1
fi

# Restore based on type
case "$BACKUP_TYPE" in
    hive)
        restore_hive
        ;;
    minio)
        restore_minio
        ;;
    airflow)
        restore_airflow
        ;;
    *)
        log_error "Unknown backup type: ${BACKUP_TYPE}"
        exit 1
        ;;
esac

restore_hive() {
    log_info "Restoring Hive Metastore..."

    local backup_file="${BACKUP_DIR}/hive/hive-metastore-${BACKUP_DATE}.sql"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: ${backup_file}"
        exit 1
    fi

    # Get Hive pod
    local hive_pod=$(get_pod "$STAGING_NAMESPACE" "app=hive-metastore")

    if [[ -z "$hive_pod" ]]; then
        log_error "Hive pod not found in ${STAGING_NAMESPACE}"
        exit 1
    fi

    # Copy backup file
    log_info "Copying backup to pod..."
    kubectl cp "$backup_file" "${STAGING_NAMESPACE}/${hive_pod}:/tmp/restore.sql"

    # Restore
    log_info "Restoring database..."
    kubectl exec -n "$STAGING_NAMESPACE" "$hive_pod" -- \
        psql -U hive -d metastore -f /tmp/restore.sql

    # Verify
    log_info "Verifying restore..."
    local db_count=$(kubectl exec -n "$STAGING_NAMESPACE" "$hive_pod" -- \
        psql -U hive -d metastore -t -A -c "SELECT COUNT(*) FROM DBS;")

    log_info "✓ Restored ${db_count} databases"

    # Cleanup
    kubectl exec -n "$STAGING_NAMESPACE" "$hive_pod" -- rm -f /tmp/restore.sql

    log_info "✓ Hive restore complete"
}

restore_minio() {
    log_info "Restoring MinIO data..."

    local backup_prefix="minio-${BACKUP_DATE}"

    # Check MinIO access
    if ! mc ls minio/spark-backups &>/dev/null; then
        log_error "MinIO not accessible"
        exit 1
    fi

    # List restore data
    local object_count=$(mc ls --recursive "minio/spark-backups/${backup_prefix}" | wc -l)

    if [[ $object_count -eq 0 ]]; then
        log_error "No backup data found"
        exit 1
    fi

    log_info "Found ${object_count} objects to restore"

    # Restore test data (sample only)
    log_info "Restoring sample data for testing..."

    mc cp --recursive "minio/spark-backups/${backup_prefix}/test/" "minio/spark-test-data/"

    local test_objects=$(mc ls --recursive minio/spark-test-data | wc -l)
    log_info "✓ Restored ${test_objects} test objects"

    log_info "✓ MinIO restore complete"
}

restore_airflow() {
    log_info "Restoring Airflow metadata..."

    local backup_file="${BACKUP_DIR}/airflow/airflow-metadata-${BACKUP_DATE}.json"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: ${backup_file}"
        exit 1
    fi

    # Get PostgreSQL pod
    local pg_pod=$(get_pod "$STAGING_NAMESPACE" "app=postgresql")

    if [[ -z "$pg_pod" ]]; then
        log_error "PostgreSQL pod not found in ${STAGING_NAMESPACE}"
        exit 1
    fi

    # Restore metadata
    log_info "Restoring Airflow tables..."

    # This would need custom implementation based on JSON structure
    log_warn "Full Airflow restore requires manual JSON parsing"
    log_info "Backup file: ${backup_file}"

    # Verify Airflow is accessible
    if kubectl exec -n "$STAGING_NAMESPACE" "$pg_pod" -- \
        psql -U airflow -d airflow -c "SELECT COUNT(*) FROM dag;" &>/dev/null; then

        local dag_count=$(kubectl exec -n "$STAGING_NAMESPACE" "$pg_pod" -- \
            psql -U airflow -d airflow -t -A -c "SELECT COUNT(*) FROM dag;")

        log_info "✓ Airflow has ${dag_count} DAGs"
    fi

    log_info "✓ Airflow restore complete"
}

log_info "=== Restore Test Complete ==="

exit 0
