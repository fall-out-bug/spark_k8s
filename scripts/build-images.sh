#!/bin/bash
# Build all Docker images for the Spark platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Image registry (change for your registry)
REGISTRY="${REGISTRY:-localhost:5000}"
SPARK_VERSION="${SPARK_VERSION:-3.5.7}"

echo "Building Spark custom image..."
docker build \
    -t spark-custom:${SPARK_VERSION} \
    -t ${REGISTRY}/spark-custom:${SPARK_VERSION} \
    -t ${REGISTRY}/spark-custom:latest \
    ${PROJECT_DIR}/docker/spark

echo "Building Jupyter image..."
docker build \
    -t jupyter-spark:latest \
    -t ${REGISTRY}/jupyter-spark:latest \
    ${PROJECT_DIR}/docker/jupyter

echo "Building Airflow image..."
docker build \
    -t airflow-spark:latest \
    -t ${REGISTRY}/airflow-spark:latest \
    ${PROJECT_DIR}/docker/airflow

echo ""
echo "Images built successfully!"
echo ""
echo "To push to registry:"
echo "  docker push ${REGISTRY}/spark-custom:${SPARK_VERSION}"
echo "  docker push ${REGISTRY}/jupyter-spark:latest"
echo "  docker push ${REGISTRY}/airflow-spark:latest"
