#!/usr/bin/env bash
# Download and load NYT/Parquet data into MinIO for testing
# Usage: ./scripts/load-nyt-parquet-data.sh [dataset] [months]
#
# Datasets:
#   nyt     - New York Times dataset (via HuggingFace)
#   nyc     - NYC Yellow Taxi data (default)
#   trips   - Chicago Taxi Trips
#
# Examples:
#   ./scripts/load-nyt-parquet-data.sh nyc 3     # Download 3 months of NYC taxi
#   ./scripts/load-nyt-parquet-data.sh nyt        # Download NYT dataset
#   ./scripts/load-nyt-parquet-data.sh trips 2    # Download 2 months of Chicago taxi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/test-e2e-lib.sh"

DATASET="${1:-nyc}"
MONTHS="${2:-10}"
DATA_DIR="/tmp/spark-test-data"
BUCKET="test-data"
NAMESPACE="${NAMESPACE:-spark}"
MINIO_POD=""

# Dataset configurations
declare -A DATASET_URLS
declare -A DATASET_PATTERNS
declare -A DATASET_NAMES

# NYC Yellow Taxi (2025 data)
DATASET_URLS[nyc]="https://d37ci6vzurychx.cloudfront.net/trip-data"
DATASET_PATTERNS[nyc]="yellow_tripdata_2025-{01..${MONTHS}}.parquet"
DATASET_NAMES[nyc]="NYC Yellow Taxi"

# Chicago Taxi Trips
DATASET_URLS[trips]="https://data.cityofchicago.org/api/views"
DATASET_PATTERNS[trips]="taxi-trips-2025-{01..${MONTHS}}.parquet"
DATASET_NAMES[trips]="Chicago Taxi Trips"

# NYT (via alternative - using available parquet datasets)
# NYT original requires API access, so we use alternative large parquet datasets
DATASET_URLS[nyt]="https://github.com/Teradata/kylo/tree/master/samples/sample-data"
DATASET_PATTERNS[nyt]="*.parquet"
DATASET_NAMES[nyt]="Sample Parquet Dataset"

echo "=== Spark Test Data Loader for Minikube ==="
echo "Dataset: ${DATASET_NAMES[$DATASET]:-${DATASET}}"
echo "Months: ${MONTHS}"
echo "Bucket: s3://${BUCKET}/${DATASET}/"
echo ""

# Check if Minikube is running
if ! minikube_running; then
  echo "ERROR: Minikube is not running"
  echo "Start with: minikube start"
  exit 1
fi

# Create temp directory
mkdir -p "${DATA_DIR}"

# Find MinIO pod
echo "Finding MinIO pod in namespace ${NAMESPACE}..."
for i in $(seq 1 30); do
  MINIO_POD=$(kubectl get pod -n "${NAMESPACE}" -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "${MINIO_POD}" ]]; then
    echo "  Found: ${MINIO_POD}"
    break
  fi
  echo "  Waiting for MinIO pod... (${i}/30)"
  sleep 2
done

if [[ -z "${MINIO_POD}" ]]; then
  echo "ERROR: MinIO pod not found in namespace ${NAMESPACE}"
  echo "Install Spark with MinIO first, or specify NAMESPACE env var"
  exit 1
fi

# Wait for MinIO to be ready
echo "Waiting for MinIO to be ready..."
kubectl wait --for=condition=ready pod -n "${NAMESPACE}" "${MINIO_POD}" --timeout=120s

# Download data based on dataset type
echo ""
echo "Downloading data to ${DATA_DIR}..."

case "${DATASET}" in
  nyc)
    # NYC Yellow Taxi - download multiple months
    for i in $(seq -f "%02g" 1 "${MONTHS}"); do
      FILE="yellow_tripdata_2025-${i}.parquet"
      URL="${DATASET_URLS[nyc]}/${FILE}"

      if [[ -f "${DATA_DIR}/${FILE}" ]]; then
        echo "  [skip] ${FILE} already exists"
      else
        echo "  [download] ${FILE}"
        curl -sL "${URL}" -o "${DATA_DIR}/${FILE}" || {
          echo "  [error] Failed to download ${FILE}"
          echo "  Trying previous year data..."
          URL="https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-${i}.parquet"
          curl -sL "${URL}" -o "${DATA_DIR}/${FILE}"
        }
      fi
    done
    ;;

  nyt)
    # NYT alternative - use sample parquet files
    echo "  [download] sample parquet dataset"
    # Using open datasets from GitHub
    curl -sL "https://github.com/apache/spark/raw/master/examples/src/main/resources/people.json" \
      -o "${DATA_DIR}/people.json"

    # Create a larger sample parquet using Python if available
    if command -v python3 >/dev/null 2>&1; then
      python3 <<EOF
import json
import random

# Generate larger sample data
records = []
for i in range(100000):
    records.append({
        "id": i,
        "name": f"user_{i}",
        "age": random.randint(18, 80),
        "city": random.choice(["NYC", "LA", "Chicago", "Houston", "Phoenix"]),
        "score": random.uniform(0, 100)
    })

with open("${DATA_DIR}/users.json", "w") as f:
    for record in records:
        f.write(json.dumps(record) + "\n")

print(f"Generated {len(records)} records")
EOF
    fi
    ;;

  trips)
    # Chicago Taxi - download sample data
    echo "  [download] Chicago taxi sample"
    FILE="taxi-trips-2025-01.parquet"
    URL="https://data.cityofchicago.org/resource/wrvz-psew.parquet?\$limit=10000"
    curl -sL "${URL}" -o "${DATA_DIR}/${FILE}" || {
      echo "  [fallback] Using NYC taxi data as alternative"
      for i in 1 2 3; do
        FILE="yellow_tripdata_2024-$(printf '%02d' $i).parquet"
        URL="https://d37ci6vzurychx.cloudfront.net/trip-data/${FILE}"
        curl -sL "${URL}" -o "${DATA_DIR}/${FILE}"
      done
    }
    ;;

  *)
    echo "ERROR: Unknown dataset '${DATASET}'"
    echo "Supported: nyc, nyt, trips"
    exit 1
    ;;
esac

echo ""
echo "Download complete."

# Create bucket in MinIO
echo ""
echo "Creating bucket in MinIO..."
kubectl exec -n "${NAMESPACE}" "${MINIO_POD}" -- \
  mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1

kubectl exec -n "${NAMESPACE}" "${MINIO_POD}" -- \
  mc mb --ignore-existing local/"${BUCKET}" >/dev/null 2>&1

kubectl exec -n "${NAMESPACE}" "${MINIO_POD}" -- \
  mc mb --ignore-existing local/"${BUCKET}"/"${DATASET}" >/dev/null 2>&1

# Copy files to MinIO
echo "Uploading files to MinIO..."
UPLOADED=0
for file in "${DATA_DIR}"/*; do
  if [[ -f "${file}" ]]; then
    filename=$(basename "${file}")
    echo "  Uploading ${filename}..."
    if cat "${file}" | kubectl exec -i -n "${NAMESPACE}" "${MINIO_POD}" -- \
      mc pipe local/"${BUCKET}"/"${DATASET}"/"${filename}" >/dev/null 2>&1; then
      ((UPLOADED++))
    else
      echo "  ERROR: Failed to upload ${filename}"
    fi
  fi
done

if [[ ${UPLOADED} -eq 0 ]]; then
  echo "ERROR: No files uploaded successfully"
  exit 1
fi

echo "  Uploaded ${UPLOADED} file(s) successfully"

# List uploaded files
echo ""
echo "Files in MinIO (s3://${BUCKET}/${DATASET}/):"
kubectl exec -n "${NAMESPACE}" "${MINIO_POD}" -- \
  mc ls local/"${BUCKET}"/"${DATASET}"/ 2>/dev/null || echo "  (list failed, but upload may have succeeded)"

echo ""
echo "=== Data loaded successfully ==="
echo "Path: s3a://${BUCKET}/${DATASET}/"
echo ""

# Generate test commands
echo "Test commands:"
echo ""
echo "1) Load parquet in PySpark:"
echo "   kubectl exec -n ${NAMESPACE} <jupyter-pod> -- python3 -c \\"
echo "     'from pyspark.sql import SparkSession'"
echo "     'spark = SparkSession.builder.remote(\\\"sc://spark-connect:15002\\\").getOrCreate()'"
echo "     'df = spark.read.parquet(\\\"s3a://${BUCKET}/${DATASET}/*.parquet\\\")'"
echo "     'df.printSchema()'"
echo "     'print(f\\\"Records: {df.count():,}\\\")'"
echo ""

echo "2) Run SQL query:"
echo "   kubectl exec -n ${NAMESPACE} <jupyter-pod> -- python3 -c \\"
echo "     'from pyspark.sql import SparkSession'"
echo "     'spark = SparkSession.builder.remote(\\\"sc://spark-connect:15002\\\").getOrCreate()'"
echo "     'df = spark.read.parquet(\\\"s3a://${BUCKET}/${DATASET}/*.parquet\\\")'"
echo "     'df.createOrReplaceTempView(\\\"data\\\")'"
echo "     'spark.sql(\\\"SELECT * FROM data LIMIT 10\\\").show()'"
echo ""

# Cleanup option
read -p "Delete temp files in ${DATA_DIR}? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "${DATA_DIR}"
  echo "Temp files deleted."
fi

echo "Done!"
