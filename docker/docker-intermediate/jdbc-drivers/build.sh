#!/usr/bin/env bash
# Build script for JDBC drivers intermediate Docker image

set -euo pipefail

# Configuration
BASE_IMAGE=${BASE_IMAGE:-spark-k8s:3.5.7-hadoop3.4.2}
IMAGE_NAME="spark-k8s-jdbc-drivers:latest"

echo "Building JDBC drivers layer..."
echo "  Base image: $BASE_IMAGE"
echo "  Output: $IMAGE_NAME"

# Check if base image exists
if ! docker image inspect "$BASE_IMAGE" &>/dev/null; then
    echo "Error: Base image $BASE_IMAGE not found"
    echo "Available images:"
    docker images | grep "spark-k8s.*hadoop" || echo "  No Spark images found"
    echo ""
    echo "Build custom Spark image first:"
    if [[ "$BASE_IMAGE" == *"3.5.7"* ]]; then
        echo "  cd docker/spark-custom && docker build -f Dockerfile.3.5.7 -t $BASE_IMAGE ."
    elif [[ "$BASE_IMAGE" == *"3.5.8"* ]]; then
        echo "  cd docker/spark-custom && docker build -f Dockerfile.3.5.8 -t $BASE_IMAGE ."
    elif [[ "$BASE_IMAGE" == *"4.1.0"* ]]; then
        echo "  cd docker/spark-custom && docker build -f Dockerfile.4.1.0 -t $BASE_IMAGE ."
    elif [[ "$BASE_IMAGE" == *"4.1.1"* ]]; then
        echo "  cd docker/spark-custom && docker build -f Dockerfile.4.1.1 -t $BASE_IMAGE ."
    fi
    exit 1
fi

# Build image
docker build \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    -t "$IMAGE_NAME" \
    .

echo "Built: $IMAGE_NAME"
