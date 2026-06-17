#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

require_image() {
  local image="$1"
  minikube image ls 2>/dev/null | grep -q "$image"
}

build_hive() {
  docker build -f "$PROJECT_ROOT/docker/hive/Dockerfile" \
    --build-arg HIVE_VERSION=3.1.3 \
    -t spark-k8s/hive:3.1.3-pg \
    "$PROJECT_ROOT/docker/hive"
  minikube image load spark-k8s/hive:3.1.3-pg
}

build_spark() {
  "$PROJECT_ROOT/docker/spark-custom/build-and-load.sh"
}

build_jupyter() {
  docker build -f "$PROJECT_ROOT/docker/jupyter/Dockerfile" \
    --build-arg SPARK_VERSION=3.5.7 \
    -t spark-k8s-jupyter:3.5-3.5.7 \
    "$PROJECT_ROOT/docker/jupyter"
  minikube image load spark-k8s-jupyter:3.5-3.5.7
}

require_image "spark-custom:3.5.7" || build_spark
require_image "spark-k8s/hive:3.1.3-pg" || build_hive
require_image "spark-k8s-jupyter:3.5-3.5.7" || build_jupyter
