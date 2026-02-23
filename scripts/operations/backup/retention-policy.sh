#!/bin/bash
# Backup retention policy enforcement
#
# Usage:
#   ./retention-policy.sh [--type <hive|minio|airflow>] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
BACKUP_TYPE=${BACKUP_TYPE:-"all"}
BACKUP_DIR=${BACKUP_DIR:-"/backups"}
DRY_RUN=${DRY_RUN:-false}

# Retention policies
DAILY_RETENTION=7      # days
WEEKLY_RETENTION=28    # days (4 weeks)
MONTHLY_RETENTION=365  # days (12 months)

log_info "=== Backup Retention Policy ==="
log_info "Type: ${BACKUP_TYPE}"
log_info "Dry run: ${DRY_RUN}"

apply_retention() {
    local backup_type=$1
    local backup_dir=$2

    log_info "Applying retention policy for: ${backup_type}"

    # Find old backups
    local current_date=$(date +%s)
    local daily_cutoff=$((current_date - (DAILY_RETENTION * 86400)))
    local weekly_cutoff=$((current_date - (WEEKLY_RETENTION * 86400)))
    local monthly_cutoff=$((current_date - (MONTHLY_RETENTION * 86400)))

    declare -i deleted=0
    declare -i kept=0

    # Process backup files
    for backup_file in $(find "$backup_dir" -name "*-${backup_type}-*.sql" -o -name "*-${backup_type}-*.json" -o -name "*-${backup_type}-*.tar.gz" 2>/dev/null); do
        # Extract date from filename
        local file_date=$(basename "$backup_file" | grep -oE '[0-9]{8}' | head -1)

        if [[ -z "$file_date" ]]; then
            continue
        fi

        # Convert to epoch
        local backup_epoch=$(date -d "$file_date" +%s 2>/dev/null || echo "0")

        if [[ $backup_epoch -eq 0 ]]; then
            continue
        fi

        # Check if backup should be kept (monthly on 1st of month)
        local file_month=$(date -d "$file_date" +%Y%m)
        local day_of_month=$(date -d "$file_date" +%d)

        local should_delete=false

        if [[ $backup_epoch -lt $monthly_cutoff ]]; then
            # Keep monthly backups (1st of month)
            if [[ "$day_of_month" != "01" ]]; then
                should_delete=true
            fi
        elif [[ $backup_epoch -lt $weekly_cutoff ]]; then
            # Keep weekly backups (Sundays)
            local day_of_week=$(date -d "$file_date" +%u)
            if [[ "$day_of_week" != "7" ]]; then
                should_delete=true
            fi
        elif [[ $backup_epoch -lt $daily_cutoff ]]; then
            # Delete old daily backups
            should_delete=true
        fi

        if [[ "$should_delete" == "true" ]]; then
            log_info "Deleting old backup: ${backup_file}"

            if [[ "$DRY_RUN" != "true" ]]; then
                rm -f "$backup_file"
                rm -f "${backup_file}.sha256"
                ((deleted++))
            else
                log_info "[DRY RUN] Would delete: ${backup_file}"
                ((deleted++))
            fi
        else
            ((kept++))
        fi
    done

    log_info "Deleted: ${deleted} backups"
    log_info "Kept: ${kept} backups"
}

# Apply retention based on type
case "$BACKUP_TYPE" in
    hive)
        apply_retention "hive" "${BACKUP_DIR}/hive"
        ;;
    minio)
        apply_retention "minio" "${BACKUP_DIR}/minio"
        ;;
    airflow)
        apply_retention "airflow" "${BACKUP_DIR}/airflow"
        ;;
    mlflow)
        apply_retention "mlflow" "${BACKUP_DIR}/mlflow"
        ;;
    all)
        for type in hive minio airflow mlflow; do
            if [[ -d "${BACKUP_DIR}/${type}" ]]; then
                apply_retention "$type" "${BACKUP_DIR}/${type}"
            fi
        done
        ;;
    *)
        log_error "Unknown backup type: ${BACKUP_TYPE}"
        exit 1
        ;;
esac

log_info "=== Retention Policy Complete ==="

exit 0
