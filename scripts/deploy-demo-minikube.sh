#!/usr/bin/env bash
# Deploy full demo to minikube (single release: spark-infra)
# Prerequisites: minikube running, helm 3, images built (spark-custom:3.5.7)
# Usage: ./scripts/deploy-demo-minikube.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART_PATH="$PROJECT_ROOT/charts/spark-3.5"
NAMESPACE="spark-infra"

echo "=== Deploying Demo to Minikube ==="

# Build deps
helm dependency build "$CHART_PATH" 2>/dev/null || true

# Create namespace
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Deploy spark-infra with standalone + airflow + jupyter
helm upgrade --install spark-infra "$CHART_PATH" \
  -n "$NAMESPACE" \
  -f "$CHART_PATH/presets/demo-full-spark-infra.yaml" \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --set spark-base.postgresql.auth.password=postgres \
  --set standalone.airflow.postgresql.auth.password=airflow \
  --timeout 15m \
  --wait

echo "Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE" --timeout=120s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=spark-master -n "$NAMESPACE" --timeout=180s || true

# Deploy observability
"$PROJECT_ROOT/scripts/tests/minikube/deploy-observability.sh"

echo ""
echo "=== Demo deployed ==="
echo "Run: ./tests/observability/start-ui-portforwards.sh"
echo "Then: ./scripts/upload-spark-jobs-to-minio.sh $NAMESPACE"
kubectl get pods -n "$NAMESPACE"
kubectl get pods -n observability
