#!/bin/bash
set -e

# Build Jupyter Runtime Images for Spark 4.1
# Usage: ./build-4.1.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Variants: baseline, gpu, iceberg, gpu-iceberg
VARIANTS=("baseline" "gpu" "iceberg" "gpu-iceberg")
VERSIONS=("4.1.0")

echo "Building Jupyter runtime images for Spark 4.1..."

# Build images
for VERSION in "${VERSIONS[@]}"; do
    for VARIANT in "${VARIANTS[@]}"; do
        echo "Building spark-k8s-jupyter:4.1-${VERSION}-${VARIANT}..."

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

        # Spark runtime image to extend
        SPARK_RUNTIME_IMAGE="spark-k8s-runtime:4.1-${VERSION}-${VARIANT}"

        # Check if Spark runtime image exists
        if ! docker image inspect "${SPARK_RUNTIME_IMAGE}" &>/dev/null; then
            echo "WARNING: Spark runtime image ${SPARK_RUNTIME_IMAGE} not found. Skipping."
            continue
        fi

        # Build Jupyter image
        docker build \
            -t "spark-k8s-jupyter:4.1-${VERSION}-${VARIANT}" \
            -t "spark-k8s-jupyter:latest-4.1-${VARIANT}" \
            --build-arg "SPARK_RUNTIME_IMAGE=${SPARK_RUNTIME_IMAGE}" \
            --build-arg "SPARK_VERSION=${VERSION}" \
            --build-arg "ENABLE_GPU=${ENABLE_GPU}" \
            --build-arg "ENABLE_ICEBERG=${ENABLE_ICEBERG}" \
            -f "${SCRIPT_DIR}/Dockerfile" \
            "${SCRIPT_DIR}"

        # Tag also with version-only tag for convenience
        if [ "${VARIANT}" = "baseline" ]; then
            docker tag "spark-k8s-jupyter:4.1-${VERSION}-${VARIANT}" "spark-k8s-jupyter:4.1-${VERSION}"
        fi

        echo "Built spark-k8s-jupyter:4.1-${VERSION}-${VARIANT}"
    done
done

echo "All Jupyter runtime images for Spark 4.1 built successfully!"

# Display images
echo ""
echo "Built images:"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep "spark-k8s-jupyter:4.1"
