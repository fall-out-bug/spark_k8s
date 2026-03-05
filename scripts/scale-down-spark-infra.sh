#!/usr/bin/env bash
# Scale down: Standalone, Airflow, Jupyter to 0 replicas (saves ~2 CPU, ~5Gi)
# Re-apply observability with reduced CPU
# Usage: ./scripts/scale-down-spark-infra.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="spark-infra"

echo "=== Scaling down Standalone, Airflow, Jupyter ==="

# Standalone + Airflow
kubectl scale deployment spark-infra-standalone-master -n "$NAMESPACE" --replicas=0 2>/dev/null || true
kubectl scale deployment spark-infra-standalone-worker -n "$NAMESPACE" --replicas=0 2>/dev/null || true
kubectl scale deployment spark-infra-airflow-webserver -n "$NAMESPACE" --replicas=0 2>/dev/null || true
kubectl scale deployment spark-infra-airflow-scheduler -n "$NAMESPACE" --replicas=0 2>/dev/null || true
kubectl scale statefulset spark-infra-airflow-postgresql -n "$NAMESPACE" --replicas=0 2>/dev/null || true

# Jupyter
kubectl scale deployment spark-infra-spark-35-jupyter -n "$NAMESPACE" --replicas=0 2>/dev/null || true

echo "Waiting for pods to terminate..."
sleep 10

echo ""
echo "=== Re-applying observability with reduced CPU ==="
kubectl apply -f "$PROJECT_ROOT/tests/observability/prometheus-demo.yaml" 2>/dev/null || true
kubectl apply -f "$PROJECT_ROOT/tests/observability/loki.yaml" 2>/dev/null || true
kubectl apply -f "$PROJECT_ROOT/tests/observability/promtail.yaml" 2>/dev/null || true
kubectl apply -f "$PROJECT_ROOT/tests/observability/demo-metrics-exporter.yaml" 2>/dev/null || true

# OTEL and Grafana - need full deploy
"$PROJECT_ROOT/scripts/tests/minikube/deploy-observability.sh" 2>/dev/null || true

echo ""
echo "=== Done. Freed ~2 CPU, ~5Gi. Observability CPU reduced. ==="
kubectl get pods -n "$NAMESPACE"
kubectl get pods -n observability
