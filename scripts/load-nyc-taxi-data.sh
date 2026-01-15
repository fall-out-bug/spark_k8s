#!/bin/bash
# Download and load NYC Yellow Taxi data into MinIO
# Usage: ./scripts/load-nyc-taxi-data.sh [months]
# Example: ./scripts/load-nyc-taxi-data.sh 3  # Download 3 months
#          ./scripts/load-nyc-taxi-data.sh    # Download all 10 months

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

MONTHS=${1:-10}
DATA_DIR="/tmp/nyc-taxi"
BUCKET="raw-data"
PREFIX="nyc-taxi"

echo "=== NYC Yellow Taxi Data Loader ==="
echo "Months to download: $MONTHS"
echo ""

# Create temp directory
mkdir -p "$DATA_DIR"

# Download parquet files
echo "Downloading data..."
for i in $(seq -w 1 $MONTHS); do
    FILE="yellow_tripdata_2025-${i}.parquet"
    URL="https://d37ci6vzurychx.cloudfront.net/trip-data/${FILE}"

    if [ -f "$DATA_DIR/$FILE" ]; then
        echo "  [skip] $FILE already exists"
    else
        echo "  [download] $FILE"
        curl -sL "$URL" -o "$DATA_DIR/$FILE" &
    fi
done
wait
echo "Download complete."
echo ""

# Get network name
NETWORK=$(docker network ls --format '{{.Name}}' | grep spark | head -1)
if [ -z "$NETWORK" ]; then
    echo "ERROR: No spark network found. Run ./start.sh first."
    exit 1
fi

# Upload to MinIO
echo "Uploading to MinIO (s3://$BUCKET/$PREFIX/)..."
docker run --rm --network "$NETWORK" \
    -v "$DATA_DIR:/data" \
    --entrypoint="" \
    minio/mc:latest /bin/sh -c "
        mc alias set myminio http://minio:9000 minioadmin minioadmin
        mc mb --ignore-existing myminio/$BUCKET/$PREFIX
        mc cp /data/*.parquet myminio/$BUCKET/$PREFIX/
        echo ''
        echo 'Files in MinIO:'
        mc ls myminio/$BUCKET/$PREFIX/
    "

echo ""
echo "=== Data loaded successfully ==="
echo "Path: s3a://$BUCKET/$PREFIX/*.parquet"
echo ""
echo "Test with:"
echo "  docker exec jupyter python3 -c \\"
echo "    from pyspark.sql import SparkSession"
echo "    spark = SparkSession.builder.remote('sc://spark-connect:15002').getOrCreate()"
echo "    df = spark.read.parquet('s3a://$BUCKET/$PREFIX/*.parquet')"
echo "    print(f'Records: {df.count():,}')"
echo "  \""
echo ""

# Cleanup option
read -p "Delete temp files in $DATA_DIR? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$DATA_DIR"
    echo "Temp files deleted."
fi
