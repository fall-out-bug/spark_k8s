#!/bin/bash
# S3 Bucket Restore Script
# Restores S3 objects from versioned backups or cross-region replication
#
# Usage:
#   restore-s3-bucket.sh --bucket <name> --prefix <path> [OPTIONS]
#
# Examples:
#   restore-s3-bucket.sh --bucket spark-data --prefix "production/fact_table/"
#   restore-s3-bucket.sh --bucket spark-data --restore-to "2026-02-10 12:00:00"
#   restore-s3-bucket.sh --bucket spark-data --from-replica spark-data-dr

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUCKET=""
PREFIX=""
RESTORE_TO=""
FROM_REPLICA=""
DRY_RUN=false
VERIFY_AFTER=true
CHECKSUM_ONLY=false
MAX_PARALLEL=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") --bucket <name> --prefix <path> [OPTIONS]

Restore S3 objects from versioned backups or cross-region replication.

OPTIONS:
    -b, --bucket NAME         Bucket name to restore
    -p, --prefix PATH         Prefix path to restore
    -r, --restore-to TIME     Restore to specific point in time (format: "YYYY-MM-DD HH:MM:SS")
    -f, --from-replica NAME   Restore from replica bucket
    --checksum-only           Only restore objects with checksum mismatches
    --no-verify               Skip verification after restore
    --max-parallel NUM        Maximum parallel operations (default: 10)
    --dry-run                 Show what would be done without executing
    -v, --verbose             Enable verbose output
    -h, --help                Show this help

EXAMPLES:
    # Restore from versioning (to previous version before deletion)
    $(basename "$0") --bucket spark-data --prefix "production/fact_table/dt=2026-02-11/"

    # Restore to specific point in time
    $(basename "$0") --bucket spark-data --prefix "production/" \\
        --restore-to "2026-02-10 12:00:00"

    # Restore from DR region replica
    $(basename "$0") --bucket spark-data --from-replica spark-data-dr

    # Restore only corrupted files (based on checksum)
    $(basename "$0") --bucket spark-data --prefix "production/" --checksum-only

    # Dry run to see what would be restored
    $(basename "$0") --bucket spark-data --prefix "production/" --dry-run
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
            -b|--bucket)
                BUCKET="$2"
                shift 2
                ;;
            -p|--prefix)
                PREFIX="$2"
                shift 2
                ;;
            -r|--restore-to)
                RESTORE_TO="$2"
                shift 2
                ;;
            -f|--from-replica)
                FROM_REPLICA="$2"
                shift 2
                ;;
            --checksum-only)
                CHECKSUM_ONLY=true
                shift
                ;;
            --no-verify)
                VERIFY_AFTER=false
                shift
                ;;
            --max-parallel)
                MAX_PARALLEL="$2"
                shift 2
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

    if [[ -z "$BUCKET" ]]; then
        log_error "Bucket name is required"
        usage
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "aws CLI not found"
        exit 1
    fi

    # Check bucket exists
    if ! aws s3 ls "s3://$BUCKET" &> /dev/null; then
        log_error "Bucket $BUCKET not found or not accessible"
        exit 1
    fi

    # Check if versioning is enabled
    local versioning
    versioning=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query 'Status' --output text 2>/dev/null || echo "Suspended")
    if [[ "$versioning" != "Enabled" ]]; then
        log_warn "Bucket versioning is not enabled: $versioning"
    fi

    log_info "Prerequisites check passed"
}

list_objects_to_restore() {
    local output_file="$1"

    log_info "Listing objects to restore..."

    if [[ -n "$PREFIX" ]]; then
        aws s3api list-objects-v2 \
            --bucket "$BUCKET" \
            --prefix "$PREFIX" \
            --query 'Contents[].{Key:Key,VersionId:VersionId}' \
            --output json > "$output_file"
    else
        aws s3api list-objects-v2 \
            --bucket "$BUCKET" \
            --query 'Contents[].{Key:Key,VersionId:VersionId}' \
            --output json > "$output_file"
    fi

    local count
    count=$(jq '. | length' "$output_file")
    log_info "Found $count objects"
}

list_versioned_objects() {
    local output_file="$1"

    log_info "Listing versioned objects..."

    aws s3api list-object-versions \
        --bucket "$BUCKET" \
        --prefix "${PREFIX:-}" \
        --query 'Versions[].{Key:Key,VersionId:VersionId,LastModified:LastModified,IsLatest:IsLatest}' \
        --output json > "$output_file"

    local count
    count=$(jq '. | length' "$output_file")
    log_info "Found $count versions"
}

get_objects_before_time() {
    local input_file="$1"
    local output_file="$2"
    local restore_time="$3"

    log_info "Filtering objects before: $restore_time"

    # Convert restore time to epoch
    local restore_epoch
    restore_epoch=$(date -d "$restore_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$restore_time" +%s 2>/dev/null || echo "0")

    if [[ "$restore_epoch" == "0" ]]; then
        log_error "Invalid restore time format: $restore_time"
        log_info "Expected format: YYYY-MM-DD HH:MM:SS"
        exit 1
    fi

    jq "[.[] | select(.LastModified | fromdateiso8601 <= $restore_epoch)]" "$input_file" > "$output_file"

    local count
    count=$(jq '. | length' "$output_file")
    log_info "Found $count objects to restore"
}

restore_object_version() {
    local key="$1"
    local version_id="$2"

    log_info "Restoring: $key (version: $version_id)"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restore: $key from version $version_id"
        return 0
    fi

    # Download previous version
    local temp_file
    temp_file=$(mktemp)

    aws s3api get-object \
        --bucket "$BUCKET" \
        --key "$key" \
        --version-id "$version_id" \
        "$temp_file" &> /dev/null

    # Upload as new version
    aws s3 cp "$temp_file" "s3://$BUCKET/$key" \
        --metadata "restore-source=version-id:$version_id,restore-date=$(date -u +%Y-%m-%dT%H:%M:%S)"

    rm -f "$temp_file"
}

restore_from_replica() {
    log_info "Restoring from replica: $FROM_REPLICA"

    local replica_prefix="${PREFIX:-}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would sync from s3://$FROM_REPLICA/$replica_prefix to s3://$BUCKET/$replica_prefix"
        return 0
    fi

    # Sync from replica
    aws s3 sync "s3://$FROM_REPLICA/$replica_prefix" "s3://$BUCKET/$replica_prefix" \
        --source-region "$(aws s3api get-bucket-location --bucket "$FROM_REPLICA" --query 'LocationConstraint' --output text || echo us-east-1)" \
        --region "$(aws s3api get-bucket-location --bucket "$BUCKET" --query 'LocationConstraint' --output text || echo us-east-1)" \
        --parallel "$MAX_PARALLEL"
}

restore_objects_batch() {
    local objects_file="$1"

    local count
    count=$(jq '. | length' "$objects_file")

    log_info "Restoring $count objects..."

    local index=0
    jq -c '.[]' "$objects_file" | while read -r obj; do
        ((index++)) || true
        local key version_id

        key=$(echo "$obj" | jq -r '.Key')
        version_id=$(echo "$obj" | jq -r '.VersionId // empty')

        if [[ -n "$version_id" ]]; then
            restore_object_version "$key" "$version_id"
        else
            log_warn "No version ID for $key, skipping"
        fi

        # Progress indicator
        if [[ $((index % 100)) -eq 0 ]]; then
            log_info "Progress: $index/$count objects restored"
        fi
    done
}

verify_checksums() {
    log_info "Verifying checksums..."

    local checksum_mismatches=0

    if [[ -n "$PREFIX" ]]; then
        aws s3 ls "s3://$BUCKET/$PREFIX" --recursive | \
        while read -r line; do
            local key size
            key=$(echo "$line" | awk '{print $4}')
            size=$(echo "$line" | awk '{print $3}')

            # Get stored checksum
            local stored_checksum
            stored_checksum=$(aws s3api head-object \
                --bucket "$BUCKET" \
                --key "$key" \
                --query 'Metadata.checksum' \
                --output text 2>/dev/null || echo "")

            if [[ -n "$stored_checksum" ]]; then
                # Download and verify
                local temp_file
                temp_file=$(mktemp)
                aws s3 cp "s3://$BUCKET/$key" "$temp_file" &> /dev/null

                local actual_checksum
                actual_checksum=$(md5sum "$temp_file" | awk '{print $1}')

                if [[ "$stored_checksum" != "$actual_checksum" ]]; then
                    log_error "Checksum mismatch: $key"
                    ((checksum_mismatches++)) || true
                fi

                rm -f "$temp_file"
            fi
        done
    fi

    if [[ $checksum_mismatches -gt 0 ]]; then
        log_error "Found $checksum_mismatches checksum mismatches"
        return 1
    else
        log_info "All checksums verified"
    fi
}

verify_restore() {
    if [[ "$VERIFY_AFTER" != true ]]; then
        return
    fi

    log_info "Verifying restore..."

    local object_count
    object_count=$(aws s3api list-objects-v2 \
        --bucket "$BUCKET" \
        --prefix "${PREFIX:-}" \
        --query 'Count' \
        --output text)

    log_info "Object count in prefix: $object_count"

    # Verify checksums if enabled
    if [[ "$CHECKSUM_ONLY" == true ]] || command -v jq &> /dev/null; then
        verify_checksums || log_warn "Checksum verification found issues"
    fi

    log_info "Restore verification complete"
}

main() {
    parse_args "$@"

    log_info "=== S3 Bucket Restore ==="
    log_info "Bucket: $BUCKET"
    log_info "Prefix: ${PREFIX:-All}"
    log_info "Restore to: ${RESTORE_TO:-Latest}"
    log_info "From replica: ${FROM_REPLICA:-None}"

    check_prerequisites

    if [[ -n "$FROM_REPLICA" ]]; then
        restore_from_replica
    else
        local temp_dir
        temp_dir=$(mktemp -d)

        if [[ -n "$RESTORE_TO" ]]; then
            # Restore to point in time
            local versions_file="$temp_dir/versions.json"
            local filtered_file="$temp_dir/filtered.json"

            list_versioned_objects "$versions_file"
            get_objects_before_time "$versions_file" "$filtered_file" "$RESTORE_TO"
            restore_objects_batch "$filtered_file"
        else
            # Restore latest non-deleted versions
            local objects_file="$temp_dir/objects.json"

            list_objects_to_restore "$objects_file"
            restore_objects_batch "$objects_file"
        fi

        rm -rf "$temp_dir"
    fi

    if [[ "$DRY_RUN" != true ]]; then
        verify_restore
    fi

    log_info ""
    log_info "=== Restore Complete ==="
}

main "$@"
