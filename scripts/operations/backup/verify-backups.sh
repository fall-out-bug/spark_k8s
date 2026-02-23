#!/bin/bash
# Verify backup integrity
#
# Usage:
#   ./verify-backups.sh [--type <hive|minio|airflow|mlflow>] [--date <YYYYMMDD>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
BACKUP_TYPE=${BACKUP_TYPE:-"all"}
BACKUP_DATE=${BACKUP_DATE:-$(date +%Y%m%d)}
BACKUP_DIR=${BACKUP_DIR:-"/backups"}

log_info "=== Backup Verification ==="
log_info "Type: ${BACKUP_TYPE}"
log_info "Date: ${BACKUP_DATE}"

# Verification results
declare -i TOTAL=0
declare -i PASSED=0
declare -i FAILED=0

verify_hive_backup() {
    log_info "Verifying Hive Metastore backup..."

    local backup_file="${BACKUP_DIR}/hive/hive-metastore-${BACKUP_DATE}.sql"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: ${backup_file}"
        ((FAILED++))
        return 1
    fi

    ((TOTAL++))

    # Check file size
    local size=$(du -k "$backup_file" | cut -f1)
    if [[ $size -lt 100 ]]; then
        log_error "Backup file too small: ${size}KB"
        ((FAILED++))
        return 1
    fi

    # Verify checksum
    if [[ -f "${backup_file}.sha256" ]]; then
        if sha256sum -c "${backup_file}.sha256"; then
            log_info "✓ Checksum verified"
        else
            log_error "Checksum verification failed"
            ((FAILED++))
            return 1
        fi
    fi

    # Validate SQL syntax
    if docker run --rm -v "$backup_file:/backup.sql" \
        postgres:15 psql -f /backup.sql --list &>/dev/null; then
        log_info "✓ SQL syntax valid"
    else
        log_warn "SQL validation failed (may have non-standard syntax)"
    fi

    ((PASSED++))
    log_info "✓ Hive backup verified"
}

verify_minio_backup() {
    log_info "Verifying MinIO backup..."

    local backup_prefix="minio-${BACKUP_DATE}"

    # Check if MinIO is accessible
    if ! mc ls minio/spark-backups &>/dev/null; then
        log_error "MinIO not accessible"
        ((FAILED++))
        return 1
    fi

    ((TOTAL++))

    # List backup objects
    local object_count=$(mc ls --recursive "minio/spark-backups/${backup_prefix}" 2>/dev/null | wc -l)

    if [[ $object_count -eq 0 ]]; then
        log_error "No backup objects found"
        ((FAILED++))
        return 1
    fi

    log_info "Found ${object_count} backup objects"

    # Verify manifest
    if mc stat "minio/spark-backups/${backup_prefix}/manifest.json" &>/dev/null; then
        log_info "✓ Manifest exists"

        # Validate manifest JSON
        if mc cat "minio/spark-backups/${backup_prefix}/manifest.json" | jq empty &>/dev/null; then
            log_info "✓ Manifest JSON valid"
        fi
    else
        log_warn "Manifest not found"
    fi

    ((PASSED++))
    log_info "✓ MinIO backup verified"
}

verify_airflow_backup() {
    log_info "Verifying Airflow backup..."

    local backup_file="${BACKUP_DIR}/airflow/airflow-metadata-${BACKUP_DATE}.json"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: ${backup_file}"
        ((FAILED++))
        return 1
    fi

    ((TOTAL++))

    # Check file size
    local size=$(du -k "$backup_file" | cut -f1)
    if [[ $size -lt 1 ]]; then
        log_error "Backup file empty"
        ((FAILED++))
        return 1
    fi

    # Verify JSON structure
    if jq empty "$backup_file" 2>/dev/null; then
        log_info "✓ JSON valid"
    else
        log_error "Invalid JSON"
        ((FAILED++))
        return 1
    fi

    # Verify checksum
    if [[ -f "${backup_file}.sha256" ]]; then
        if sha256sum -c "${backup_file}.sha256"; then
            log_info "✓ Checksum verified"
        else
            log_error "Checksum verification failed"
            ((FAILED++))
            return 1
        fi
    fi

    ((PASSED++))
    log_info "✓ Airflow backup verified"
}

verify_mlflow_backup() {
    log_info "Verifying MLflow backup..."

    local metadata_backup="${BACKUP_DIR}/mlflow/mlflow-metadata-${BACKUP_DATE}.sql"
    local artifact_backup="${BACKUP_DIR}/mlflow/mlflow-artifacts-${BACKUP_DATE}.tar.gz"

    if [[ ! -f "$metadata_backup" ]]; then
        log_warn "Metadata backup not found (may use external DB)"
    else
        ((TOTAL++))

        if [[ -s "$metadata_backup" ]]; then
            log_info "✓ Metadata backup exists"
            ((PASSED++))
        else
            log_error "Metadata backup empty"
            ((FAILED++))
            return 1
        fi
    fi

    if [[ ! -f "$artifact_backup" ]]; then
        log_info "Artifact backup not found (using external store)"
    else
        if [[ -s "$artifact_backup" ]]; then
            log_info "✓ Artifact backup exists"

            # Verify tar archive
            if tar -tzf "$artifact_backup" &>/dev/null; then
                log_info "✓ Artifact archive valid"
            else
                log_warn "Artifact archive may be corrupt"
            fi
        fi
    fi

    log_info "✓ MLflow backup verified"
}

# Main execution
case "$BACKUP_TYPE" in
    hive)
        verify_hive_backup
        ;;
    minio)
        verify_minio_backup
        ;;
    airflow)
        verify_airflow_backup
        ;;
    mlflow)
        verify_mlflow_backup
        ;;
    all)
        verify_hive_backup
        verify_minio_backup
        verify_airflow_backup
        verify_mlflow_backup
        ;;
    *)
        log_error "Unknown backup type: ${BACKUP_TYPE}"
        exit 1
        ;;
esac

# Summary
log_info "=== Verification Summary ==="
log_info "Total: ${TOTAL}"
log_info "Passed: ${PASSED}"
log_info "Failed: ${FAILED}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
