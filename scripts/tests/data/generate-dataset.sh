#!/bin/bash
# Generate test datasets for smoke testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
DATASET_NAME="nyc-taxi-sample"
DATASET_PATH="${DATA_DIR}/${DATASET_NAME}.parquet"

SIZE="${1:-small}"
ROWS_SMALL=1000
ROWS_MEDIUM=10000
ROWS_LARGE=100000

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

generate_dataset() {
    local rows="$1"

    mkdir -p "$DATA_DIR"

    log_info "Generating NYC Taxi sample dataset (~$rows rows)"

    # Use Python to generate synthetic taxi data
    python3 << EOF
import pandas as pd
import numpy as np

# Generate synthetic taxi trip data
np.random.seed(42)
n = $rows

data = {
    'VendorID': np.random.choice([1, 2], n),
    'tpep_pickup_datetime': pd.date_range('2023-01-01', periods=n, freq='1min'),
    'tpep_dropoff_datetime': pd.date_range('2023-01-01', periods=n, freq='1min') + pd.Timedelta(minutes=np.random.randint(5, 30, n)),
    'passenger_count': np.random.randint(1, 6, n),
    'trip_distance': np.random.uniform(0.5, 20, n),
    'RatecodeID': np.random.choice([1, 2, 3, 4, 5], n),
    'store_and_fwd_flag': np.random.choice(['N', 'Y'], n),
    'PULocationID': np.random.randint(1, 266, n),
    'DOLocationID': np.random.randint(1, 266, n),
    'payment_type': np.random.choice([1, 2, 3, 4, 5, 6], n),
    'fare_amount': np.random.uniform(5, 100, n),
    'extra': np.random.uniform(0, 10, n),
    'mta_tax': np.random.uniform(0, 1, n),
    'tip_amount': np.random.uniform(0, 20, n),
    'tolls_amount': np.random.uniform(0, 15, n),
    'improvement_surcharge': 0.3,
    'total_amount': np.random.uniform(5, 150, n)
}

df = pd.DataFrame(data)
df.to_parquet('$DATASET_PATH', index=False)
print(f"Generated {len(df)} rows to $DATASET_PATH")
EOF

    if [[ ! -f "$DATASET_PATH" ]]; then
        log_error "Dataset generation failed"
        exit 1
    fi

    local size_bytes
    size_bytes=$(du -b "$DATASET_PATH" | cut -f1)
    local size_mb
    size_mb=$((size_bytes / 1024 / 1024))

    log_success "Dataset generated: $DATASET_PATH (~${size_mb}MB)"
    log_info "Usage: export DATASET_PATH=\"$DATASET_PATH\""
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [SIZE]

Generate test datasets for smoke testing.

Arguments:
  SIZE        Dataset size: small (1000 rows), medium (10000 rows), large (100000 rows)
              Default: small

Options:
  -h, --help  Show this help message

Examples:
  $(basename "$0") small
  $(basename "$0") medium
  $(basename "$0") large

Environment:
  DATASET_PATH  Set to dataset path for use in smoke tests

EOF
}

case "$SIZE" in
    small)
        generate_dataset "$ROWS_SMALL"
        ;;
    medium)
        generate_dataset "$ROWS_MEDIUM"
        ;;
    large)
        generate_dataset "$ROWS_LARGE"
        ;;
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        log_error "Invalid size: $SIZE (use: small, medium, large)"
        show_help
        exit 1
        ;;
esac
