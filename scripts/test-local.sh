#!/bin/bash
# Quick test script for local docker-compose setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Starting minimal setup for testing..."

# Start core services
docker-compose up -d minio postgres minio-init

echo "Waiting for services to be ready..."
sleep 10

# Check MinIO
echo "Checking MinIO..."
curl -s http://localhost:9000/minio/health/ready && echo " MinIO OK" || echo " MinIO FAILED"

# Check PostgreSQL
echo "Checking PostgreSQL..."
docker-compose exec -T postgres pg_isready -U spark && echo " PostgreSQL OK" || echo " PostgreSQL FAILED"

# Build and start Spark
echo "Building Spark image..."
docker-compose build spark-connect

echo "Starting Spark Connect..."
docker-compose up -d spark-connect

sleep 30

# Test Spark Connect
echo "Testing Spark Connect..."
docker-compose exec -T spark-connect nc -z localhost 15002 && echo " Spark Connect OK" || echo " Spark Connect FAILED"

echo ""
echo "Core services are running. Access:"
echo "  - MinIO Console: http://localhost:9001 (minioadmin/minioadmin)"
echo "  - Spark UI: http://localhost:4040"
echo ""
echo "To start all services: docker-compose up -d"
echo "To start with Kafka: docker-compose --profile kafka up -d"
echo "To stop: docker-compose down"
