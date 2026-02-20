#!/bin/bash
# Build and load into minikube images required for Spark 3.5.7 minikube scenarios.
# Run from repo root. Requires: docker, minikube, eval $(minikube docker-env) for same daemon.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SPARK_VERSION="3.5.7"

cd "$PROJECT_ROOT"

# Use minikube's docker so images stay in minikube
if ! minikube status &>/dev/null; then
  echo "Start minikube first: minikube start --cpus=4 --memory=8g"
  exit 1
fi
eval "$(minikube docker-env)"

echo "=== Building Hive Metastore (3.1.3-pg) ==="
# Build hive with PostgreSQL driver; tag as chart expects
docker build -f docker/hive/Dockerfile \
  --build-arg HIVE_VERSION=3.1.3 \
  -t spark-k8s/hive:3.1.3-pg \
  docker/hive

echo "=== Building Spark (spark-custom) ==="
docker build -f docker/spark-custom/Dockerfile.3.5.7 \
  -t spark-custom:${SPARK_VERSION}-new \
  docker/spark-custom

echo "=== Loading into minikube (if not using same daemon) ==="
minikube image load spark-k8s/hive:3.1.3-pg 2>/dev/null || true
minikube image load spark-custom:${SPARK_VERSION}-new 2>/dev/null || true

echo "=== Built and ready ==="
echo "  spark-k8s/hive:3.1.3-pg"
echo "  spark-custom:${SPARK_VERSION}-new"
echo "For History Server the chart uses historyServer.image (spark-custom:3.5.x). Override to spark-custom:${SPARK_VERSION}-new when installing, or tag: docker tag spark-custom:${SPARK_VERSION}-new spark-custom:3.5.x"
