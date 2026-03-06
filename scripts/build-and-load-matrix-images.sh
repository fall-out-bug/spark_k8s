#!/usr/bin/env bash
# Build matrix images and load into minikube.
# Usage: ./scripts/build-and-load-matrix-images.sh [--96|--all|--quick] [--load-only]
#   --96:   build 3.5.7..4.1.1 (all variants) + hive — for 96 and 320 scenarios
#   --all:  same as --96
#   --quick: build 3.5.7 + hive only (fastest, for smoke)
#   --load-only: skip build, load existing images from host docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_VERSIONS="all"
LOAD_ONLY=""

for arg in "$@"; do
  case "$arg" in
    --96|--all) BUILD_VERSIONS="all" ;;
    --quick) BUILD_VERSIONS="3.5.7" ;;
    --load-only) LOAD_ONLY=1 ;;
    *) echo "Unknown: $arg"; exit 1 ;;
  esac
done

cd "$PROJECT_ROOT"

if ! minikube status &>/dev/null; then
  echo "Start minikube first: minikube start --cpus=6 --memory=12g"
  exit 1
fi

if [[ -z "$LOAD_ONLY" ]]; then
  echo "=== Building into minikube docker (eval minikube docker-env) ==="
  eval "$(minikube docker-env)"

  echo "=== Building Hive Metastore ==="
  docker build -f docker/hive/Dockerfile \
    --build-arg HIVE_VERSION=3.1.3 \
    -t spark-k8s/hive:3.1.3-pg \
    docker/hive

  echo "=== Building matrix images (spark-custom:*) ==="
  ./scripts/build-all-matrix-images.sh "$BUILD_VERSIONS"
  echo "Images built into minikube (docker-env)."
else
  echo "=== Load-only: loading from host docker into minikube ==="
  images=(
    "spark-k8s/hive:3.1.3-pg"
    "spark-custom:3.5.7" "spark-custom:3.5.8" "spark-custom:4.1.0" "spark-custom:4.1.1"
    "spark-custom:3.5.7-gpu" "spark-custom:3.5.8-gpu" "spark-custom:4.1.0-gpu" "spark-custom:4.1.1-gpu"
    "spark-custom:3.5.7-iceberg" "spark-custom:3.5.8-iceberg" "spark-custom:4.1.0-iceberg" "spark-custom:4.1.1-iceberg"
    "spark-custom:3.5.7-gpu-iceberg" "spark-custom:3.5.8-gpu-iceberg" "spark-custom:4.1.0-gpu-iceberg" "spark-custom:4.1.1-gpu-iceberg"
  )
  for img in "${images[@]}"; do
    if docker image inspect "$img" &>/dev/null; then
      echo "  Loading $img..."
      minikube image load "$img" 2>/dev/null || true
    else
      echo "  Skip $img (not found)"
    fi
  done
fi

echo ""
echo "=== Done ==="
minikube image ls 2>/dev/null | grep -E "spark-custom|spark-k8s/hive" || true
