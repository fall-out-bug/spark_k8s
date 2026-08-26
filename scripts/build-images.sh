#!/bin/bash
# Build canonical runtime images locally.
#
# spark-custom builds are self-contained: docker/spark-custom/Dockerfile.<ver>
# compiles Spark from source with pinned Hadoop 3.4.2 + AWS SDK v2 bundle, so
# no prebuilt dist/*.tgz is needed. Tag naming mirrors publish-images.yml
# (ghcr.io/fall-out-bug/spark-k8s-*) so local images are interchangeable
# with published ones.
#
# Usage:
#   ./scripts/build-images.sh                          # SPARK_VERSION=3.5.7 default
#   SPARK_VERSION=4.1.1 ./scripts/build-images.sh
#   AIRFLOW=1 ./scripts/build-images.sh                # also build optional airflow image

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SPARK_VERSION="${SPARK_VERSION:-3.5.7}"
GHCR_OWNER="fall-out-bug"

if [[ ! -f "${PROJECT_DIR}/docker/spark-custom/Dockerfile.${SPARK_VERSION}" ]]; then
    echo "No such Dockerfile: docker/spark-custom/Dockerfile.${SPARK_VERSION}" >&2
    echo "Available:" >&2
    ls "${PROJECT_DIR}"/docker/spark-custom/Dockerfile.* >&2
    exit 1
fi

echo "Building spark-custom ${SPARK_VERSION}..."
docker build \
    -t "spark-custom:${SPARK_VERSION}" \
    -t "ghcr.io/${GHCR_OWNER}/spark-k8s-spark-custom:${SPARK_VERSION}" \
    -f "docker/spark-custom/Dockerfile.${SPARK_VERSION}" \
    docker/spark-custom

echo "Building jupyter-spark image..."
JUPYTER_CONTEXT="docker/jupyter"
[[ "${SPARK_VERSION}" == 4.* ]] && JUPYTER_CONTEXT="docker/jupyter-4.1"
docker build \
    -t "jupyter-spark:${SPARK_VERSION}" \
    -t "ghcr.io/${GHCR_OWNER}/spark-k8s-jupyter-spark:${SPARK_VERSION}" \
    "${JUPYTER_CONTEXT}"

if [[ "${AIRFLOW:-0}" == "1" ]]; then
    echo "Building airflow-spark image (optional)..."
    docker build \
        -t "airflow-spark:latest" \
        -t "ghcr.io/${GHCR_OWNER}/spark-k8s-airflow-spark:latest" \
        docker/optional/airflow
fi

echo ""
echo "Images built:"
echo "  spark-custom:${SPARK_VERSION}"
echo "  jupyter-spark:${SPARK_VERSION}"
echo ""
echo "Official publishing runs via .github/workflows/publish-images.yml."
echo "Manual push example:"
echo "  docker push ghcr.io/${GHCR_OWNER}/spark-k8s-spark-custom:${SPARK_VERSION}"
