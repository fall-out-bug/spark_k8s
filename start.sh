#!/bin/bash
# Spark K8s Platform - Start Script
# Запуск локального окружения для разработки и тестирования

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Spark K8s Platform - Starting ==="
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running"
    exit 1
fi

# Build images if needed
echo "Building images (this may take a while on first run)..."
docker-compose build

# Start services
echo ""
echo "Starting services..."
docker-compose up -d

# Wait for services to be healthy
echo ""
echo "Waiting for services to start..."
sleep 10

# Check service status
echo ""
echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Available Services ==="
echo "JupyterLab:        http://localhost:8888"
echo "Spark UI:          http://localhost:4040"
echo "MinIO Console:     http://localhost:9001 (minioadmin/minioadmin)"
echo ""
echo "Spark Connect:     sc://localhost:15002"
echo ""
echo "=== Quick Start ==="
echo "1. Open http://localhost:8888 in your browser"
echo "2. Navigate to notebooks/ folder"
echo "3. Open 00_spark_connect_guide.ipynb"
echo ""
echo "=== Usage Example ==="
cat << 'EOF'
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MyApp") \
    .remote("sc://spark-connect:15002") \
    .getOrCreate()

# Create DataFrame
df = spark.createDataFrame([("Alice", 25), ("Bob", 30)], ["name", "age"])
df.show()

# Write to S3
df.write.mode("overwrite").parquet("s3a://warehouse/mydata")
EOF
echo ""
echo "Platform started successfully!"
