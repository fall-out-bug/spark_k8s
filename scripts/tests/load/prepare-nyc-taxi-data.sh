#!/bin/bash
# Prepare NYC Taxi Dataset for Load Testing
# Part of WS-025-11: Load Tests with 10GB NYC Taxi Dataset
#
# Generates or downloads NYC Taxi data and uploads to MinIO.
# Usage: ./prepare-nyc-taxi-data.sh [--size 1gb|11gb] [--download]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_SIZE="${DATA_SIZE:-11gb}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/nyc-taxi-generated}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.load-testing.svc.cluster.local:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"
BUCKET_NAME="${BUCKET_NAME:-raw-data}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Prepare NYC Taxi dataset for load testing.

Options:
    --size SIZE          Dataset size: 1gb or 11gb (default: 11gb)
    --download           Download from NYC TLC website instead of generating
    --output DIR         Output directory (default: /tmp/nyc-taxi-generated)
    --upload-only        Skip generation, only upload existing data

Environment Variables:
    DATA_SIZE            Dataset size (1gb|11gb)
    OUTPUT_DIR           Output directory
    MINIO_ENDPOINT       MinIO endpoint URL
    MINIO_ACCESS_KEY    MinIO access key
    MINIO_SECRET_KEY    MinIO secret key
    BUCKET_NAME         Target bucket name (default: raw-data)

Examples:
    # Generate 11GB dataset
    $0 --size 11gb

    # Generate 1GB dataset for quick testing
    $0 --size 1gb

    # Download real data from NYC TLC (slower)
    $0 --download

    # Upload existing generated data
    $0 --upload-only
EOF
    exit 1
}

# Parse arguments
DOWNLOAD_MODE=false
UPLOAD_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --size)
            DATA_SIZE="$2"
            shift 2
            ;;
        --download)
            DOWNLOAD_MODE=true
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --upload-only)
            UPLOAD_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Validate size
if [[ "$DATA_SIZE" != "1gb" && "$DATA_SIZE" != "11gb" ]]; then
    log_error "Invalid size: $DATA_SIZE. Must be 1gb or 11gb."
    exit 1
fi

log_info "NYC Taxi Data Preparation"
log_info "Size: $DATA_SIZE"
log_info "Output: $OUTPUT_DIR"
log_info "MinIO: $MINIO_ENDPOINT"

# Check dependencies
check_dependencies() {
    local deps=("python3" "spark-submit" "mc")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency not found: $dep"
            return 1
        fi
    done
    log_info "All dependencies satisfied"
}

# Configure MinIO client
configure_minio() {
    log_info "Configuring MinIO client..."
    if mc alias set local "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" 2>/dev/null; then
        log_info "MinIO client configured"
    else
        log_error "Failed to configure MinIO client"
        return 1
    fi
}

# Generate data using Python script
generate_data() {
    log_info "Generating $DATA_SIZE NYC Taxi dataset..."
    log_info "This may take 10-30 minutes for 11GB dataset."

    local python_script="$SCRIPT_DIR/data/generate-nyc-taxi.py"

    if [[ ! -f "$python_script" ]]; then
        log_error "Python script not found: $python_script"
        return 1
    fi

    if python3 "$python_script" \
        --size "$DATA_SIZE" \
        --output "$OUTPUT_DIR" \
        --upload; then
        log_info "Data generation and upload completed successfully"
        return 0
    else
        log_error "Data generation failed"
        return 1
    fi
}

# Download real NYC Taxi data
download_data() {
    log_info "Downloading real NYC Taxi data from TLC website..."

    local base_url="https://d37ci6vzishch.cloudfront.net/trip-data"
    local year=2024
    local months=(1 2 3 4 5 6 7 8 9 10 11 12)

    mkdir -p "$OUTPUT_DIR/download"
    cd "$OUTPUT_DIR/download"

    for month in "${months[@]}"; do
        local month_str=$(printf "%02d" "$month")
        local filename="yellow_tripdata_${year}-${month_str}.parquet"
        local url="${base_url}/${filename}"

        log_info "Downloading: $filename"
        if curl -f -s -O "$url"; then
            log_info "Downloaded: $filename"
        else
            log_warn "Failed to download: $filename (may not be available yet)"
        fi
    done

    log_info "Download completed. Files in $OUTPUT_DIR/download"
}

# Upload existing data to MinIO
upload_data() {
    log_info "Uploading data to MinIO bucket: $BUCKET_NAME"

    # Create bucket if not exists
    if ! mc ls "local/$BUCKET_NAME" &>/dev/null; then
        log_info "Creating bucket: $BUCKET_NAME"
        mc mb "local/$BUCKET_NAME"
    fi

    # Upload data
    local data_path="$OUTPUT_DIR"
    if [[ "$DATA_SIZE" == "1gb" ]]; then
        data_path="$OUTPUT_DIR/1gb"
    else
        data_path="$OUTPUT_DIR/11gb"
    fi

    if [[ ! -d "$data_path" ]]; then
        log_error "Data directory not found: $data_path"
        return 1
    fi

    log_info "Uploading from: $data_path"
    mc cp --recursive "$data_path/" "local/$BUCKET_NAME/"

    # Verify upload
    local file_count=$(mc ls "local/$BUCKET_NAME/" | wc -l)
    log_info "Upload completed. Files in bucket: $file_count"
}

# Main execution
main() {
    check_dependencies || exit 1
    configure_minio || exit 1

    if [[ "$UPLOAD_ONLY" == true ]]; then
        upload_data || exit 1
    elif [[ "$DOWNLOAD_MODE" == true ]]; then
        download_data || exit 1
        upload_data || exit 1
    else
        generate_data || exit 1
    fi

    log_info "✓ Data preparation completed successfully"
    log_info "Next: Run load tests with ./run-direct-load-tests.sh"
}

main "$@"
