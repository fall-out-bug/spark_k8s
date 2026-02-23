#!/bin/bash
# MinIO Volume Recovery Script
# Restores MinIO data from backup archives
#
# Usage:
#   restore-minio-volume.sh --backup <backup_file> [OPTIONS]
#
# Examples:
#   restore-minio-volume.sh --backup s3://spark-backups-minio/minio-data/backup.tar.gz
#   restore-minio-volume.sh --backup /tmp/backup.tar.gz --namespace spark-operations
#   restore-minio-volume.sh --backup backup.tar.gz --pvc minio-data-minio-0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
BACKUP_FILE=""
PVC="minio-data-minio-0"
MINIO_POD="minio-0"
MINIO_ALIAS="myminio"
TEMP_DIR="/tmp/minio-restore"
SKIP_VERIFY=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") --backup <backup_file> [OPTIONS]

Restore MinIO data from a backup archive.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -b, --backup FILE         Backup archive file (s3:// or local)
    -p, --pvc NAME            PVC to restore to (default: minio-data-minio-0)
    -m, --minio-pod NAME      MinIO pod name (default: minio-0)
    -a, --alias NAME          MinIO alias (default: myminio)
    -t, --temp-dir DIR        Temporary directory (default: /tmp/minio-restore)
    --skip-verify             Skip backup verification
    --dry-run                 Show what would be done without executing
    -v, --verbose             Enable verbose output
    -h, --help                Show this help

EXAMPLES:
    # Restore from S3 backup
    $(basename "$0") --backup s3://spark-backups-minio/minio-data/backup.tar.gz

    # Restore from local file
    $(basename "$0") --backup /tmp/backup.tar.gz --namespace spark-operations

    # Restore to specific PVC
    $(basename "$0") --backup backup.tar.gz --pvc minio-data-minio-0

    # Dry run to see what would be restored
    $(basename "$0") --backup backup.tar.gz --dry-run
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

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -b|--backup)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -p|--pvc)
                PVC="$2"
                shift 2
                ;;
            -m|--minio-pod)
                MINIO_POD="$2"
                shift 2
                ;;
            -a|--alias)
                MINIO_ALIAS="$2"
                shift 2
                ;;
            -t|--temp-dir)
                TEMP_DIR="$2"
                shift 2
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    if [[ -z "$BACKUP_FILE" ]]; then
        log_error "Backup file is required"
        usage
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    # Check AWS CLI (for S3)
    if [[ "$BACKUP_FILE" == s3://* ]] && ! command -v aws &> /dev/null; then
        log_error "aws CLI not found (required for S3 backups)"
        exit 1
    fi

    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

scale_down_minio() {
    log_info "Scaling down MinIO StatefulSet..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would scale down minio StatefulSet"
        return
    fi

    kubectl scale statefulset -n "$NAMESPACE" minio --replicas=0

    log_info "Waiting for pods to terminate..."
    kubectl wait --for=delete pods -n "$NAMESPACE" -l app=minio --timeout=120s || true

    log_info "MinIO scaled down"
}

download_backup() {
    local backup_file="$1"
    local local_backup="$TEMP_DIR/$(basename "$backup_file")"

    log_info "Downloading backup: $backup_file"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would download to: $local_backup"
        echo "$local_backup"
        return
    fi

    mkdir -p "$TEMP_DIR"

    if [[ "$backup_file" == s3://* ]]; then
        aws s3 cp "$backup_file" "$local_backup"
    else
        cp "$backup_file" "$local_backup"
    fi

    echo "$local_backup"
}

verify_backup() {
    local backup_file="$1"

    if [[ "$SKIP_VERIFY" == true ]]; then
        log_warn "Skipping backup verification"
        return
    fi

    log_info "Verifying backup: $backup_file"

    # Check file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi

    # Check file type
    local file_type
    file_type=$(file "$backup_file" | cut -d: -f2)

    if [[ ! "$file_type" =~ gzip|tar|POSIX ]]; then
        log_error "Backup file does not appear to be a tar archive"
        log_info "File type: $file_type"
        exit 1
    fi

    # List contents to verify
    log_info "Backup contents:"
    tar -tzf "$backup_file" | head -20

    local total_files
    total_files=$(tar -tzf "$backup_file" | wc -l)
    log_info "Total files in archive: $total_files"

    log_info "Backup verification passed"
}

restore_to_pvc() {
    local backup_file="$1"

    log_info "Restoring to PVC: $PVC"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restore to PVC: $PVC"
        return
    fi

    # Check PVC exists
    if ! kubectl get pvc -n "$NAMESPACE" "$PVC" &> /dev/null; then
        log_error "PVC $PVC not found"
        exit 1
    fi

    # Create temporary pod for restore
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minio-restore-helper
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: $PVC
  containers:
  - name: restore
    image: alpine:latest
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
EOF

    # Wait for pod to be ready
    log_info "Waiting for restore helper pod..."
    kubectl wait --for=condition=ready pod -n "$NAMESPACE" minio-restore-helper --timeout=120s

    # Copy backup to pod
    log_info "Copying backup to pod..."
    kubectl cp "$backup_file" "$NAMESPACE/minio-restore-helper:/tmp/backup.tar.gz"

    # Extract backup
    log_info "Extracting backup..."
    kubectl exec -n "$NAMESPACE" minio-restore-helper -- \
        tar -xzf /tmp/backup.tar.gz -C /data

    # Verify extraction
    log_info "Verifying extraction..."
    kubectl exec -n "$NAMESPACE" minio-restore-helper -- \
        ls -la /data

    # Clean up helper pod
    kubectl delete pod -n "$NAMESPACE" minio-restore-helper

    log_info "Restore to PVC complete"
}

scale_up_minio() {
    log_info "Scaling up MinIO StatefulSet..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would scale up minio StatefulSet"
        return
    fi

    kubectl scale statefulset -n "$NAMESPACE" minio --replicas=1

    log_info "Waiting for MinIO to be ready..."
    kubectl wait --for=condition=ready pod -n "$NAMESPACE" -l app=minio --timeout=300s

    log_info "MinIO is ready"
}

verify_restore() {
    log_info "Verifying restore..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would verify restore"
        return
    fi

    # Check MinIO is healthy
    kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
        mc admin info "$MINIO_ALIAS" || {
        log_error "MinIO health check failed"
        exit 1
    }

    # List buckets
    kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
        mc ls "$MINIO_ALIAS"

    # Check data directory
    kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
        ls -la /data

    log_info "Restore verification complete"
}

main() {
    parse_args "$@"

    log_info "=== MinIO Volume Restore ==="
    log_info "Namespace: $NAMESPACE"
    log_info "Backup: $BACKUP_FILE"
    log_info "PVC: $PVC"
    log_info "MinIO pod: $MINIO_POD"

    check_prerequisites

    # Scale down MinIO
    scale_down_minio

    # Download backup
    local local_backup
    local_backup=$(download_backup "$BACKUP_FILE")

    # Verify backup
    verify_backup "$local_backup"

    # Restore to PVC
    restore_to_pvc "$local_backup"

    # Scale up MinIO
    scale_up_minio

    # Verify restore
    verify_restore

    log_info ""
    log_info "=== Restore Complete ==="

    # Clean up
    if [[ "$DRY_RUN" != true ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

main "$@"
