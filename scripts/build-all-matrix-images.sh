#!/usr/bin/env bash
# Build all Docker images required for test matrix (baseline, gpu, iceberg, gpu-iceberg)
# Produces spark-custom:* tags expected by run-matrix.sh
#
# Usage: ./scripts/build-all-matrix-images.sh [3.5.7|3.5.8|4.1.0|4.1.1|all]
# Default: 3.5.7 (fastest for local validation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS="${1:-3.5.7}"
[[ "$VERSIONS" == "all" ]] && VERSIONS="3.5.7 3.5.8 4.1.0 4.1.1"

cd "$PROJECT_ROOT"

# Step 1: Build spark-custom base images (spark-k8s:V-hadoop3.4.2)
build_base() {
    local v="$1"
    local base="spark-k8s:${v}-hadoop3.4.2"
    if docker image inspect "$base" &>/dev/null; then
        echo "Base $base exists, skipping"
        return 0
    fi
    echo "Building base $base..."
    docker build -f "docker/spark-custom/Dockerfile.${v}" \
        -t "$base" \
        docker/spark-custom
}

# Step 2: Build runtime variants and tag as spark-custom:*
build_runtime_and_tag() {
    local v="$1"
    local base="spark-k8s:${v}-hadoop3.4.2"
    local spark_major scala_ver iceberg_spark_ver iceberg_ver
    case "$v" in
        3.5.7|3.5.8) spark_major="3.5"; scala_ver="2.12"; iceberg_spark_ver="3.5"; iceberg_ver="1.6.1" ;;
        4.1.0|4.1.1) spark_major="4.1"; scala_ver="2.13"; iceberg_spark_ver="4.0"; iceberg_ver="1.10.1" ;;
        *) echo "Unknown version $v"; return 1 ;;
    esac

    for variant in baseline gpu iceberg gpu-iceberg; do
        local runtime_tag="spark-k8s-runtime:${spark_major}-${v}-${variant}"
        local matrix_tag="spark-custom:${v}"
        [[ "$variant" != "baseline" ]] && matrix_tag="spark-custom:${v}-${variant}"

        if docker image inspect "$matrix_tag" &>/dev/null; then
            echo "  $matrix_tag exists, skipping"
            continue
        fi

        local enable_gpu="false" enable_iceberg="false"
        [[ "$variant" == "gpu" || "$variant" == "gpu-iceberg" ]] && enable_gpu="true"
        [[ "$variant" == "iceberg" || "$variant" == "gpu-iceberg" ]] && enable_iceberg="true"

        echo "  Building $runtime_tag -> $matrix_tag..."
        docker build -q \
            -t "$runtime_tag" \
            --build-arg "BASE_IMAGE=$base" \
            --build-arg "SPARK_VERSION=$v" \
            --build-arg "SCALA_VERSION=$scala_ver" \
            --build-arg "ENABLE_GPU=$enable_gpu" \
            --build-arg "ENABLE_ICEBERG=$enable_iceberg" \
            --build-arg "ICEBERG_VERSION=$iceberg_ver" \
            --build-arg "ICEBERG_SPARK_VERSION=$iceberg_spark_ver" \
            -f docker/runtime/spark/Dockerfile \
            docker/runtime/spark

        docker tag "$runtime_tag" "$matrix_tag"
        echo "  Tagged $matrix_tag"
    done
}

echo "=== Building matrix images (spark-custom:*) ==="
for ver in $VERSIONS; do
    echo ""
    echo "--- Spark $ver ---"
    build_base "$ver"
    build_runtime_and_tag "$ver"
done

echo ""
echo "=== Done. Images for run-matrix: ==="
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "spark-custom|spark-k8s" | head -30
