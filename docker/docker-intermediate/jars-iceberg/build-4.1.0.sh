#!/usr/bin/env bash
# Build script for Iceberg JARs layer - Spark 4.1.0 (Scala 2.13)

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_IMAGE="${BASE_IMAGE:-localhost/spark-k8s:4.1.0-hadoop3.4.2}"
# Iceberg 1.10.1+ required for Spark 4.0 support (1.6.1 only supports up to Spark 3.5)
readonly ICEBERG_VERSION="${ICEBERG_VERSION:-1.10.1}"
readonly IMAGE_NAME="spark-k8s-jars-iceberg:4.1.0"

echo "Building Iceberg JARs layer for Spark 4.1.0..."
echo "  Base image: $BASE_IMAGE"
echo "  Iceberg version: $ICEBERG_VERSION"
echo "  Output: $IMAGE_NAME"

# Check if base image exists
if ! docker image inspect "$BASE_IMAGE" &>/dev/null; then
    echo "Error: Base image $BASE_IMAGE not found"
    echo "Please build the custom Spark base image first:"
    echo "  cd docker/spark-custom && make build-4.1.0"
    exit 1
fi

docker build \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "SPARK_VERSION=4.1.0" \
    --build-arg "ICEBERG_SPARK_VERSION=4.0" \
    --build-arg "SCALA_VERSION=2.13" \
    --build-arg "ICEBERG_VERSION=${ICEBERG_VERSION}" \
    -t "$IMAGE_NAME" \
    "$SCRIPT_DIR"

echo "Built: $IMAGE_NAME"
