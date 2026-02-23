#!/bin/bash
# Replicate backups to DR region
#
# Usage:
#   ./replicate-to-dr-region.sh [--source <region>] [--dest <region>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
SOURCE_REGION=${SOURCE_REGION:-"us-east-1"}
DEST_REGION=${DEST_REGION:-"us-west-2"}
SOURCE_BUCKET=${SOURCE_BUCKET:-"spark-backups"}
DEST_BUCKET=${DEST_BUCKET:-"spark-backups-dr"}
BACKUP_DATE=$(date +%Y%m%d)

log_info "=== Backup Replication to DR Region ==="
log_info "Source: ${SOURCE_REGION}/${SOURCE_BUCKET}"
log_info "Destination: ${DEST_REGION}/${DEST_BUCKET}"

# Check prerequisites
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found"
    exit 1
fi

# Check source bucket access
log_info "Checking source bucket..."
if ! aws s3 ls "s3://${SOURCE_BUCKET}" --region "$SOURCE_REGION" &>/dev/null; then
    log_error "Cannot access source bucket: ${SOURCE_BUCKET}"
    exit 1
fi

# Check/create destination bucket
log_info "Checking destination bucket..."
if ! aws s3 ls "s3://${DEST_BUCKET}" --region "$DEST_REGION" &>/dev/null; then
    log_info "Creating destination bucket: ${DEST_BUCKET}"

    aws s3 mb "s3://${DEST_BUCKET}" --region "$DEST_REGION" || \
        log_warn "Bucket creation failed (may already exist)"
fi

# Replicate backup data
log_info "Replicating backup data..."

# Get list of objects to replicate
OBJECTS=$(aws s3 ls "s3://${SOURCE_BUCKET}/${BACKUP_DATE}/" --recursive --region "$SOURCE_REGION" 2>/dev/null | awk '{print $4}')

if [[ -z "$OBJECTS" ]]; then
    log_warn "No objects found for date: ${BACKUP_DATE}"
    exit 0
fi

# Count objects
TOTAL_OBJECTS=$(echo "$OBJECTS" | wc -l)
log_info "Found ${TOTAL_OBJECTS} objects to replicate"

# Replicate each object
declare -i replicated=0
declare -i failed=0

while IFS= read -r object; do
    if [[ -z "$object" ]]; then
        continue
    fi

    log_info "Replicating: ${object}"

    if aws s3 cp "s3://${SOURCE_BUCKET}/${object}" "s3://${DEST_BUCKET}/${object}" \
        --region "$SOURCE_REGION" --source-region "$SOURCE_REGION" &>/dev/null; then
        ((replicated++))
    else
        log_error "Failed to replicate: ${object}"
        ((failed++))
    fi
done <<< "$OBJECTS"

# Summary
log_info "=== Replication Summary ==="
log_info "Total objects: ${TOTAL_OBJECTS}"
log_info "Replicated: ${replicated}"
log_info "Failed: ${failed}"

if [[ $failed -gt 0 ]]; then
    log_error "Some objects failed to replicate"
    exit 1
fi

# Set up cross-region replication (CRR) for future backups
log_info "Setting up cross-region replication..."

# Create replication configuration
cat > /tmp/replication-config.json <<EOF
{
    "Role": "arn:aws:iam::ACCOUNT_ID:role/s3-replication-role",
    "Rules": [
        {
            "Status": "Enabled",
            "Priority": 1,
            "Filter": {},
            "Destination": {
                "Bucket": "arn:aws:s3:::${DEST_BUCKET}",
                "ReplicationTime": {
                    "Status": "Enabled",
                    "Time": {
                        "Minutes": 15
                    }
                },
                "Metrics": {
                    "Status": "Enabled"
                },
                "StorageClass": "STANDARD",
                "ReplicationKmsKeyID": "arn:aws:kms::SOURCE_REGION_ID:key/KMS_KEY_ID"
            },
            "DeleteMarkerReplication": {
                "Status": "Enabled"
            }
        }
    ]
}
EOF

# Apply replication configuration (requires proper IAM setup)
if aws s3api put-bucket-replication \
    --bucket "$SOURCE_BUCKET" \
    --replication-configuration "file:///tmp/replication-config.json" \
    --region "$SOURCE_REGION" 2>/dev/null; then
    log_info "✓ Cross-region replication configured"
else
    log_warn "Failed to configure CRR (requires IAM setup)"
fi

# Cleanup
rm -f /tmp/replication-config.json

log_info "=== Replication Complete ==="

exit 0
