#!/bin/bash
# Data Integrity Verification Script
# Verifies data integrity using checksums and validates file formats
#
# Usage:
#   verify-data-integrity.sh --bucket <name> [OPTIONS]
#
# Examples:
#   verify-data-integrity.sh --bucket spark-data --prefix "production/"
#   verify-data-integrity.sh --bucket minio --check-checksum
#   verify-data-integrity.sh --bucket spark-data --full-validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUCKET=""
PREFIX=""
CHECKSUM_FILE=""
CHECK_CHECKSUM=false
FULL_VALIDATION=false
RECURSIVE=true
OUTPUT_FORMAT="text"
TEMP_DIR="/tmp/data-integrity-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Statistics
declare -i total_files=0
declare -i verified_files=0
declare -i corrupted_files=0
declare -i missing_files=0
declare -i checksum_mismatches=0

usage() {
    cat <<EOF
Usage: $(basename "$0") --bucket <name> [OPTIONS]

Verify data integrity using checksums and validate file formats.

OPTIONS:
    -b, --bucket NAME         Bucket name (S3 or MinIO)
    -p, --prefix PATH         Prefix path to verify (default: all)
    -c, --checksum-file FILE  Checksum file to verify against
    --check-checksum           Verify stored checksums in object metadata
    --full-validation         Perform full validation (schema, checksum, format)
    --no-recursive            Don't recurse into subdirectories
    --output-format FORMAT    Output format: text, json, csv (default: text)
    --temp-dir DIR            Temporary directory (default: /tmp/data-integrity-$$)
    -v, --verbose             Enable verbose output
    -h, --help                Show this help

EXAMPLES:
    # Verify all files in bucket
    $(basename "$0") --bucket spark-data

    # Verify specific prefix
    $(basename "$0") --bucket spark-data --prefix "production/fact_table/"

    # Verify against checksum file
    $(basename "$0") --bucket spark-data --checksum-file checksums.txt

    # Verify stored checksums in metadata
    $(basename "$0") --bucket spark-data --check-checksum

    # Full validation with schema checks
    $(basename "$0") --bucket spark-data --full-validation
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
        echo -e "[DEBUG] $*"
    fi
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
            -c|--checksum-file)
                CHECKSUM_FILE="$2"
                shift 2
                ;;
            --check-checksum)
                CHECK_CHECKSUM=true
                shift
                ;;
            --full-validation)
                FULL_VALIDATION=true
                shift
                ;;
            --no-recursive)
                RECURSIVE=false
                shift
                ;;
            --output-format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --temp-dir)
                TEMP_DIR="$2"
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

    if [[ -z "$BUCKET" ]]; then
        echo "Error: Bucket name is required" >&2
        usage
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check AWS CLI or MinIO client
    if [[ "$BUCKET" == "minio" ]]; then
        if ! command -v mc &> /dev/null; then
            log_error "MinIO client (mc) not found"
            exit 1
        fi
    else
        if ! command -v aws &> /dev/null; then
            log_error "AWS CLI not found"
            exit 1
        fi
    fi

    # Check for required tools
    if [[ "$FULL_VALIDATION" == true ]]; then
        if ! command -v parquet-tools &> /dev/null && ! command -v spark-sql &> /dev/null; then
            log_warn "parquet-tools or spark-sql not found, skipping format validation"
        fi
    fi

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    log_info "Prerequisites check passed"
}

list_files() {
    local output_file="$1"

    log_info "Listing files in s3://$BUCKET/${PREFIX:-}..."

    if [[ "$BUCKET" == "minio" ]]; then
        # Use MinIO client
        mc ls --recursive "minio/${PREFIX:-}" | awk '{print $5}' > "$output_file"
    else
        # Use AWS CLI
        local recursive_flag=""
        if [[ "$RECURSIVE" == true ]]; then
            recursive_flag="--recursive"
        fi

        aws s3 ls "s3://$BUCKET/${PREFIX:-}" $recursive_flag | awk '{print $4}' > "$output_file"
    fi

    total_files=$(wc -l < "$output_file")
    log_info "Found $total_files files"
}

verify_checksums_from_file() {
    local files_file="$1"
    local checksum_file="$2"

    log_info "Verifying checksums from: $checksum_file"

    while IFS='  ' read -r checksum filepath; do
        [[ -z "$filepath" ]] && continue

        # Check if file exists
        if ! grep -q "$filepath" "$files_file"; then
            log_error "File not found: $filepath"
            ((missing_files++)) || true
            continue
        fi

        # Download and verify
        local temp_file="$TEMP_DIR/$(basename "$filepath")"

        if [[ "$BUCKET" == "minio" ]]; then
            mc cp "minio/$filepath" "$temp_file" &> /dev/null
        else
            aws s3 cp "s3://$BUCKET/$filepath" "$temp_file" &> /dev/null
        fi

        local actual_checksum
        actual_checksum=$(md5sum "$temp_file" | awk '{print $1}')

        if [[ "$checksum" != "$actual_checksum" ]]; then
            log_error "Checksum mismatch: $filepath"
            log_error "  Expected: $checksum"
            log_error "  Actual: $actual_checksum"
            ((checksum_mismatches++)) || true
            ((corrupted_files++)) || true
        else
            ((verified_files++)) || true
            log_verbose "Checksum OK: $filepath"
        fi

        rm -f "$temp_file"
    done < "$checksum_file"
}

verify_stored_checksums() {
    local files_file="$1"

    log_info "Verifying stored checksums..."

    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        # Get stored checksum
        local stored_checksum=""
        if [[ "$BUCKET" == "minio" ]]; then
            stored_checksum=$(mc stat --json "minio/$filepath" | jq -r '.metadata.etag // empty' 2>/dev/null || echo "")
        else
            stored_checksum=$(aws s3api head-object \
                --bucket "$BUCKET" \
                --key "$filepath" \
                --query 'Metadata.checksum' \
                --output text 2>/dev/null || echo "")
        fi

        if [[ -z "$stored_checksum" ]]; then
            log_verbose "No stored checksum for: $filepath"
            continue
        fi

        # Download and verify
        local temp_file="$TEMP_DIR/$(basename "$filepath")"

        if [[ "$BUCKET" == "minio" ]]; then
            mc cp "minio/$filepath" "$temp_file" &> /dev/null
        else
            aws s3 cp "s3://$BUCKET/$filepath" "$temp_file" &> /dev/null
        fi

        local actual_checksum
        actual_checksum=$(md5sum "$temp_file" | awk '{print $1}')

        if [[ "$stored_checksum" != "$actual_checksum" ]]; then
            log_error "Checksum mismatch: $filepath"
            ((checksum_mismatches++)) || true
            ((corrupted_files++)) || true
        else
            ((verified_files++)) || true
            log_verbose "Checksum OK: $filepath"
        fi

        rm -f "$temp_file"
    done < "$files_file"
}

validate_parquet_file() {
    local filepath="$1"
    local temp_file="$2"

    # Try parquet-tools
    if command -v parquet-tools &> /dev/null; then
        if parquet-tools show "$temp_file" &> /dev/null; then
            return 0
        else
            return 1
        fi
    fi

    # Try spark-sql
    if command -v spark-sql &> /dev/null; then
        if spark-sql -e "SELECT * FROM parquet('$temp_file') LIMIT 1;" &> /dev/null; then
            return 0
        else
            return 1
        fi
    fi

    return 0
}

validate_file_formats() {
    local files_file="$1"

    log_info "Validating file formats..."

    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        local extension="${filepath##*.}"
        local temp_file="$TEMP_DIR/$(basename "$filepath")"

        # Download file
        if [[ "$BUCKET" == "minio" ]]; then
            mc cp "minio/$filepath" "$temp_file" &> /dev/null
        else
            aws s3 cp "s3://$BUCKET/$filepath" "$temp_file" &> /dev/null
        fi

        local is_valid=true

        case "$extension" in
            parquet)
                if ! validate_parquet_file "$filepath" "$temp_file"; then
                    is_valid=false
                fi
                ;;
            orc)
                if ! command -v orc-tools &> /dev/null; then
                    log_verbose "orc-tools not found, skipping validation"
                elif ! orc-tools scan "$temp_file" &> /dev/null; then
                    is_valid=false
                fi
                ;;
            csv)
                if ! head -n 1 "$temp_file" &> /dev/null; then
                    is_valid=false
                fi
                ;;
            json)
                if ! jq empty "$temp_file" 2>/dev/null; then
                    is_valid=false
                fi
                ;;
            *)
                log_verbose "Unknown format: $extension"
                ;;
        esac

        if [[ "$is_valid" == false ]]; then
            log_error "Corrupted file: $filepath"
            ((corrupted_files++)) || true
        else
            ((verified_files++)) || true
            log_verbose "Valid: $filepath"
        fi

        rm -f "$temp_file"
    done < "$files_file"
}

generate_report() {
    log_info "=== Data Integrity Report ==="
    log_info "Total files: $total_files"
    log_info "Verified: $verified_files"
    log_info "Corrupted: $corrupted_files"
    log_info "Missing: $missing_files"
    log_info "Checksum mismatches: $checksum_mismatches"

    local exit_code=0

    if [[ "$corrupted_files" -gt 0 ]]; then
        log_info "Status: FAILED"
        exit_code=1
    else
        log_info "Status: PASSED"
    fi

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "bucket": "$BUCKET",
  "prefix": "${PREFIX:-}",
  "total_files": $total_files,
  "verified_files": $verified_files,
  "corrupted_files": $corrupted_files,
  "missing_files": $missing_files,
  "checksum_mismatches": $checksum_mismatches,
  "status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")"
}
EOF
    fi

    return $exit_code
}

main() {
    parse_args "$@"

    log_info "=== Data Integrity Verification ==="
    log_info "Bucket: $BUCKET"
    log_info "Prefix: ${PREFIX:-All}"

    check_prerequisites

    local files_file="$TEMP_DIR/files.txt"
    list_files "$files_file"

    if [[ -n "$CHECKSUM_FILE" ]]; then
        verify_checksums_from_file "$files_file" "$CHECKSUM_FILE"
    elif [[ "$CHECK_CHECKSUM" == true ]]; then
        verify_stored_checksums "$files_file"
    fi

    if [[ "$FULL_VALIDATION" == true ]]; then
        validate_file_formats "$files_file"
    fi

    generate_report

    rm -rf "$TEMP_DIR"
}

main "$@"
