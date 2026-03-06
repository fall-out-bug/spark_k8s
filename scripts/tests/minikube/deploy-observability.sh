#!/usr/bin/env bash
# Deploy Observability stack for Spark demo (minikube).
# Single Helm chart: observability-demo (Prometheus, Loki, Grafana, demo-metrics-exporter, OTEL).
# Run after scenario 0 (spark-infra). Connect presets expect otel-collector.observability.svc.cluster.local:4317.
# Usage: ./deploy-observability.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
NAMESPACE="${OBSERVABILITY_NS:-observability}"
CHART_PATH="$PROJECT_ROOT/charts/observability-demo"
VALUES_DEMO="$CHART_PATH/values-demo.yaml"

echo "=== Deploying Observability (Helm) into ${NAMESPACE} ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm dependency update "$CHART_PATH" 2>/dev/null || true
helm upgrade --install observability-demo "$CHART_PATH" \
  -n "${NAMESPACE}" \
  -f "$VALUES_DEMO" \
  --set targetNamespace=spark-infra \
  --wait --timeout 300s 2>/dev/null || echo "Helm install may need retry."

# Wait for key deployments
kubectl wait deployment/observability-demo-loki-gateway -n "${NAMESPACE}" --for=condition=available --timeout=120s 2>/dev/null || true
kubectl wait deployment/observability-demo-grafana -n "${NAMESPACE}" --for=condition=available --timeout=120s 2>/dev/null || true
kubectl wait deployment/otel-collector -n "${NAMESPACE}" --for=condition=available --timeout=120s 2>/dev/null || true
kubectl wait deployment/demo-metrics-exporter -n "${NAMESPACE}" --for=condition=available --timeout=120s 2>/dev/null || true

echo ""
echo "=== Observability deployed ==="
echo "  OTEL Collector: otel-collector.${NAMESPACE}.svc.cluster.local:4317"
echo "  Prometheus: observability-demo-prometh-prometheus.${NAMESPACE}.svc.cluster.local:9090"
echo "  Grafana: NodePort 30030 (admin/admin)"
echo "  Loki: http://observability-demo-loki.${NAMESPACE}.svc.cluster.local:3100"
echo "  demo-metrics-exporter: scrapes Spark Master + History + Airflow (spark-infra)"
kubectl get pods -n "${NAMESPACE}"
