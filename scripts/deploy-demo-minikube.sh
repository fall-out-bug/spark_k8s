#!/usr/bin/env bash
# Deploy full demo to minikube (single release: spark-infra)
# Prerequisites: minikube running, helm 3, images built (spark-custom:3.5.7)
# Usage: ./scripts/deploy-demo-minikube.sh

set -euo pipefail

# Demo default credentials (local minikube only — MinIO default. Override via env for real deploys.)
: "${S3_ACCESS_KEY:=minioadmin}"
: "${S3_SECRET_KEY:=minioadmin}"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART_PATH="$PROJECT_ROOT/charts/spark-3.5"
NAMESPACE="spark-infra"

# shellcheck source=lib/helm-safe.sh
source "$SCRIPT_DIR/lib/helm-safe.sh"

echo "=== Deploying Demo to Minikube ==="

# Build deps
helm dependency build "$CHART_PATH" 2>/dev/null || true

# Create namespace + protect it
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate namespace "$NAMESPACE" \
  spark-k8s/owner-release=spark-infra \
  spark-k8s/owner-chart=spark-3.5 \
  spark-k8s/protected=true \
  --overwrite 2>/dev/null || true

# Deploy spark-infra with standalone + airflow + jupyter (via safe wrapper)
helm_safe_install spark-infra "$CHART_PATH" "$NAMESPACE" \
  -f "$CHART_PATH/presets/demo-full-spark-infra.yaml" \
  --set global.s3.accessKey=$S3_ACCESS_KEY \
  --set global.s3.secretKey=$S3_SECRET_KEY \
  --set spark-base.postgresql.auth.password=postgres \
  --set standalone.airflow.postgresql.auth.password=postgres \
  --timeout 15m \
  --wait

echo "Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE" --timeout=120s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=standalone-master -n "$NAMESPACE" --timeout=180s || true

# Deploy observability
"$PROJECT_ROOT/scripts/tests/minikube/deploy-observability.sh"

echo ""
echo "=== Demo deployed ==="
echo "Run: ./tests/observability/start-ui-portforwards.sh"
echo "Then: ./scripts/upload-spark-jobs-to-minio.sh $NAMESPACE"
kubectl get pods -n "$NAMESPACE"
kubectl get pods -n observability
