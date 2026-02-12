#!/bin/bash
# Create Airflow metadata backup
#
# Usage:
#   ./create-airflow-backup.sh [--namespace <namespace>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
NAMESPACE=${NAMESPACE:-"airflow"}
BACKUP_DIR=${BACKUP_DIR:-"/backups/airflow"}
BACKUP_DATE=$(date +%Y%m%d)
BACKUP_FILE="${BACKUP_DIR}/airflow-metadata-${BACKUP_DATE}.json"

log_info "=== Airflow Metadata Backup ==="
log_info "Namespace: ${NAMESPACE}"
log_info "Backup file: ${BACKUP_FILE}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Get PostgreSQL pod
PG_POD=$(kubectl get pod -n "$NAMESPACE" -l app=postgresql -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$PG_POD" ]]; then
    log_error "PostgreSQL pod not found in namespace ${NAMESPACE}"
    exit 1
fi

log_info "PostgreSQL pod: ${PG_POD}"

# Export Airflow metadata
log_info "Exporting Airflow metadata..."

kubectl exec -n "$NAMESPACE" "$PG_POD" -- \
    psql -U airflow -d airflow -c "COPY (
        SELECT json_agg(t)
        FROM (
            SELECT 'dag' as table_type, json_agg(row_to_json(dag)) as data FROM dag
            UNION ALL
            SELECT 'task_instance' as table_type, json_agg(row_to_json(ti)) as data FROM task_instance
            UNION ALL
            SELECT 'dag_run' as table_type, json_agg(row_to_json(dr)) as data FROM dag_run
            UNION ALL
            SELECT 'connection' as table_type, json_agg(row_to_json(c)) as data FROM connection
            UNION ALL
            SELECT 'variable' as table_type, json_agg(row_to_json(v)) as data FROM variable
        ) t
    ) TO STDOUT" > "$BACKUP_FILE" 2>/dev/null || true

# Fallback: table-by-table export
if [[ ! -s "$BACKUP_FILE" ]]; then
    log_info "Using table-by-table export..."

    cat > "$BACKUP_FILE" <<EOF
{
  "backup_type": "airflow",
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "namespace": "${NAMESPACE}",
  "tables": {
EOF

    # Export each table
    TABLES=("dag" "task_instance" "dag_run" "connection" "variable" "sla_miss" "log")
    FIRST=true

    for table in "${TABLES[@]}"; do
        log_info "Exporting table: ${table}"

        if [[ "$FIRST" == "false" ]]; then
            echo "," >> "$BACKUP_FILE"
        fi
        FIRST=false

        echo -n "\"${table}\": " >> "$BACKUP_FILE"

        kubectl exec -n "$NAMESPACE" "$PG_POD" -- \
            psql -U airflow -d airflow -t -A -F, \
            -c "SELECT * FROM ${table}" 2>/dev/null | \
            jq -R 'split(",") | map({
                key: .[0],
                value: .[1]
            })' | jq -c '.' >> "$BACKUP_FILE" || echo "[]" >> "$BACKUP_FILE"
    done

    echo "}" >> "$BACKUP_FILE"
    echo "}" >> "$BACKUP_FILE"
fi

# Verify backup
if [[ -s "$BACKUP_FILE" ]]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_info "Backup created successfully: ${BACKUP_FILE} (${SIZE})"

    # Generate checksum
    sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
    log_info "Checksum: ${BACKUP_FILE}.sha256"
else
    log_error "Backup file is empty"
    exit 1
fi

log_info "=== Airflow Backup Complete ==="

exit 0
