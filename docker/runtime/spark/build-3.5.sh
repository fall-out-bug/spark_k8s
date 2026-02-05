#!/bin/bash
set -e

# Build Spark 3.5 Runtime Images
# Usage: ./build-3.5.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Variants: baseline, gpu, iceberg, gpu-iceberg
VARIANTS=("baseline" "gpu" "iceberg" "gpu-iceberg")
VERSIONS=("3.5.7" "3.5.8")

# Base images from F10 (custom Spark builds)
BASE_357="spark-k8s:3.5.7-hadoop3.4.2"
BASE_358="spark-k8s:3.5.8-hadoop3.4.2"

# RAPIDS and Iceberg versions
RAPIDS_VERSION="24.10.0"
CUDA_VERSION="12"
ICEBERG_VERSION="1.6.1"
ICEBERG_SPARK_VERSION="3.5"
SCALA_VERSION="2.12"

echo "Building Spark 3.5 runtime images..."
echo "Base images: ${BASE_357}, ${BASE_358}"

# Check if base images exist
echo "Checking base images..."
if ! docker image inspect "${BASE_357}" &>/dev/null; then
    echo "ERROR: Base image ${BASE_357} not found. Please build F10 images first."
    exit 1
fi

if ! docker image inspect "${BASE_358}" &>/dev/null; then
    echo "WARNING: Base image ${BASE_358} not found. Skipping 3.5.8 builds."
    VERSIONS=("3.5.7")
fi

# Build images
for VERSION in "${VERSIONS[@]}"; do
    BASE_IMAGE="spark-k8s:${VERSION}-hadoop3.4.2"
    echo "Building for Spark ${VERSION} from base ${BASE_IMAGE}..."

    for VARIANT in "${VARIANTS[@]}"; do
        echo "Building spark-3.5-runtime:${VERSION}-${VARIANT}..."

        # Determine build args
        ENABLE_GPU="false"
        ENABLE_ICEBERG="false"

        case "${VARIANT}" in
            "gpu")
                ENABLE_GPU="true"
                ;;
            "iceberg")
                ENABLE_ICEBERG="true"
                ;;
            "gpu-iceberg")
                ENABLE_GPU="true"
                ENABLE_ICEBERG="true"
                ;;
        esac

        # Build image
        docker build \
            -t "spark-k8s-runtime:3.5-${VERSION}-${VARIANT}" \
            -t "spark-k8s-runtime:latest-3.5-${VARIANT}" \
            --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
            --build-arg "SPARK_VERSION=${VERSION}" \
            --build-arg "SCALA_VERSION=${SCALA_VERSION}" \
            --build-arg "ENABLE_GPU=${ENABLE_GPU}" \
            --build-arg "ENABLE_ICEBERG=${ENABLE_ICEBERG}" \
            --build-arg "RAPIDS_VERSION=${RAPIDS_VERSION}" \
            --build-arg "CUDA_VERSION=${CUDA_VERSION}" \
            --build-arg "ICEBERG_VERSION=${ICEBERG_VERSION}" \
            --build-arg "ICEBERG_SPARK_VERSION=${ICEBERG_SPARK_VERSION}" \
            -f "${SCRIPT_DIR}/Dockerfile" \
            "${SCRIPT_DIR}"

        # Tag also with version-only tag for convenience
        if [ "${VARIANT}" = "baseline" ]; then
            docker tag "spark-k8s-runtime:3.5-${VERSION}-${VARIANT}" "spark-k8s-runtime:3.5-${VERSION}"
        fi

        echo "Built spark-k8s-runtime:3.5-${VERSION}-${VARIANT}"
    done
done

echo "All Spark 3.5 runtime images built successfully!"

# Display images
echo ""
echo "Built images:"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep "spark-k8s-runtime:3.5"
