#!/bin/bash
# Create MinIO/S3 backup
#
# Usage:
#   ./create-minio-backup.sh --bucket <name> --prefix <prefix>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
MINIO_ENDPOINT=${MINIO_ENDPOINT:-"http://minio:9000"}
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-"minioadmin"}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-"minioadmin"}
BACKUP_BUCKET=${BACKUP_BUCKET:-"spark-backups"}
BACKUP_PREFIX=${BACKUP_PREFIX:-"minio-$(date +%Y%m%d)"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bucket)
            BACKUP_BUCKET="$2"
            shift 2
            ;;
        --prefix)
            BACKUP_PREFIX="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "=== MinIO Backup ==="
log_info "Bucket: ${BACKUP_BUCKET}"
log_info "Prefix: ${BACKUP_PREFIX}"

# Check prerequisites
if ! command -v mc &> /dev/null; then
    log_error "mc (MinIO Client) not found"
    exit 1
fi

# Configure MinIO alias
mc alias set minio "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"

# Create backup bucket if it doesn't exist
if ! mc ls minio/"$BACKUP_BUCKET" &> /dev/null; then
    log_info "Creating bucket: ${BACKUP_BUCKET}"
    mc mb minio/"$BACKUP_BUCKET"
fi

# Backup bucket data
log_info "Backing up bucket data..."

# List all buckets
BUCKETS=$(mc ls --json minio | jq -r '.key')

for bucket in $BUCKETS; do
    if [[ "$bucket" == "$BACKUP_BUCKET" ]]; then
        continue
    fi

    log_info "Backing up bucket: ${bucket}"

    # Mirror bucket to backup location
    mc mirror --overwrite --remove \
        "minio/${bucket}" \
        "minio/${BACKUP_BUCKET}/${BACKUP_PREFIX}/${bucket}/"

    # Count objects
    OBJECT_COUNT=$(mc ls --recursive "minio/${BACKUP_BUCKET}/${BACKUP_PREFIX}/${bucket}/" | wc -l)
    log_info "Backed up ${OBJECT_COUNT} objects from ${bucket}"
done

# Generate manifest
MANIFEST="${BACKUP_BUCKET}/${BACKUP_PREFIX}/manifest.json"
log_info "Creating manifest: ${MANIFEST}"

cat > /tmp/manifest.json <<EOF
{
  "backup_type": "minio",
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_prefix": "${BACKUP_PREFIX}",
  "minio_endpoint": "${MINIO_ENDPOINT}",
  "buckets": $(mc ls --json minio | jq -c '[.[] | {key, size, time}]'),
  "total_objects": $(mc ls --recursive "minio/${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | wc -l),
  "total_size": "$(mc du --json "minio/${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | jq -r '.size')"
}
EOF

mc cp /tmp/manifest.json "minio/${MANIFEST}"
log_info "Manifest uploaded"

# Generate checksum
log_info "Generating checksum..."
CHECKSUM_FILE="${BACKUP_BUCKET}/${BACKUP_PREFIX}/checksums.txt"
mc ls --recursive "minio/${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | \
    while read -r line; do
        etag=$(echo "$line" | jq -r '.etag')
        key=$(echo "$line" | jq -r '.key')
        echo "${etag}  ${key}"
    done > /tmp/checksums.txt

mc cp /tmp/checksums.txt "minio/${CHECKSUM_FILE}"

log_info "=== MinIO Backup Complete ==="
log_info "Backup location: minio://${BACKUP_BUCKET}/${BACKUP_PREFIX}/"

# Cleanup
rm -f /tmp/manifest.json /tmp/checksums.txt

exit 0
