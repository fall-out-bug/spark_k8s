#!/bin/bash
# Create MLflow experiment backup
#
# Usage:
#   ./create-mlflow-backup.sh [--namespace <namespace>] [--output <file>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
NAMESPACE=${NAMESPACE:-"mlflow"}
BACKEND_STORE=${BACKEND_STORE:-"postgresql://mlflow:mlflow@${NAMESPACE}-postgresql:5432/mlflow"}
ARTIFACT_ROOT=${ARTIFACT_ROOT:-"/mlflow-artifacts"}
BACKUP_DIR=${BACKUP_DIR:-"/backups/mlflow"}
BACKUP_DATE=$(date +%Y%m%d)

log_info "=== MLflow Backup ==="
log_info "Namespace: ${NAMESPACE}"
log_info "Backend store: ${BACKEND_STORE}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# 1. Backup PostgreSQL metadata
log_info "Backing up MLflow metadata..."

PG_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
         kubectl get pod -n "$NAMESPACE" -l app=postgresql -o jsonpath='{.items[0].metadata.name}')

if [[ -n "$PG_POD" ]]; then
    METADATA_BACKUP="${BACKUP_DIR}/mlflow-metadata-${BACKUP_DATE}.sql"

    kubectl exec -n "$NAMESPACE" "$PG_POD" -- \
        pg_dump -U mlflow -d mlflow --clean > "$METADATA_BACKUP"

    SIZE=$(du -h "$METADATA_BACKUP" | cut -f1)
    log_info "Metadata backup: ${METADATA_BACKUP} (${SIZE})"

    sha256sum "$METADATA_BACKUP" > "${METADATA_BACKUP}.sha256"
else
    log_warn "PostgreSQL pod not found, skipping metadata backup"
fi

# 2. Backup artifact store (if using local storage)
log_info "Backing up MLflow artifacts..."

ARTIFACT_POD=$(kubectl get pod -n "$NAMESPACE" -l app=mlflow -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -n "$ARTIFACT_POD" ]]; then
    ARTIFACT_BACKUP="${BACKUP_DIR}/mlflow-artifacts-${BACKUP_DATE}.tar.gz"

    kubectl exec -n "$NAMESPACE" "$ARTIFACT_POD" -- \
        tar -czf /tmp/artifacts.tar.gz "$ARTIFACT_ROOT" 2>/dev/null || true

    if kubectl exec -n "$NAMESPACE" "$ARTIFACT_POD" -- test -f /tmp/artifacts.tar.gz; then
        kubectl cp "${NAMESPACE}/${ARTIFACT_POD}:/tmp/artifacts.tar.gz" "$ARTIFACT_BACKUP"
        SIZE=$(du -h "$ARTIFACT_BACKUP" | cut -f1)
        log_info "Artifact backup: ${ARTIFACT_BACKUP} (${SIZE})"

        sha256sum "$ARTIFACT_BACKUP" > "${ARTIFACT_BACKUP}.sha256"

        # Cleanup
        kubectl exec -n "$NAMESPACE" "$ARTIFACT_POD" -- rm -f /tmp/artifacts.tar.gz
    else
        log_warn "Artifact backup not created (no artifacts or error)"
    fi
else
    log_info "Using external artifact store, artifacts already backed up separately"
fi

# 3. Generate backup manifest
cat > "${BACKUP_DIR}/mlflow-manifest-${BACKUP_DATE}.json" <<EOF
{
  "backup_type": "mlflow",
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "namespace": "${NAMESPACE}",
  "components": {
    "metadata": {
      "file": "mlflow-metadata-${BACKUP_DATE}.sql",
      "exists": $([[ -n "$PG_POD" ]] && echo "true" || echo "false")
    },
    "artifacts": {
      "file": "mlflow-artifacts-${BACKUP_DATE}.tar.gz",
      "exists": $([[ -n "$ARTIFACT_POD" ]] && echo "true" || echo "false"),
      "external": true
    }
  }
}
EOF

log_info "=== MLflow Backup Complete ==="
log_info "Backup directory: ${BACKUP_DIR}"

exit 0
