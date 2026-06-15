#!/usr/bin/env bash
# Deploy Grafana observability stand on minikube.
# Wraps existing scripts/tests/minikube/deploy-observability.sh with pre-requisites
# that are NOT handled by the Helm chart on K8s 1.22+:
#   1. prometheus-operator CRDs (apiextensions/v1beta1 removed in K8s 1.22+)
#   2. grafana-admin secret (chart expects existingSecret)
#   3. Helm install with --skip-crds + post-renderer for deprecated -logtostderr flag
#
# Usage: ./scripts/deploy-observability-stand.sh
# Prerequisites: minikube running, helm 3, kubectl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="${OBSERVABILITY_NS:-observability}"
CHART_PATH="$PROJECT_ROOT/charts/observability-demo"
VALUES_DEMO="$CHART_PATH/values-demo.yaml"
POST_RENDERER="$PROJECT_ROOT/scripts/tests/minikube/helm-post-render-remove-logtostderr.sh"

CRD_BASE="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd"
CRDS=(
  monitoring.coreos.com_alertmanagerconfigs.yaml
  monitoring.coreos.com_alertmanagers.yaml
  monitoring.coreos.com_podmonitors.yaml
  monitoring.coreos.com_probes.yaml
  monitoring.coreos.com_prometheusagents.yaml
  monitoring.coreos.com_prometheuses.yaml
  monitoring.coreos.com_prometheusrules.yaml
  monitoring.coreos.com_scrapeconfigs.yaml
  monitoring.coreos.com_servicemonitors.yaml
  monitoring.coreos.com_thanosrulers.yaml
)

echo "=== Grafana Observability Stand deploy ==="
echo "Project: $PROJECT_ROOT"
echo "Namespace: $NAMESPACE"
echo "Start: $(date -Iseconds)"

# Step 0: minikube running?
if ! minikube status >/dev/null 2>&1; then
  echo "ERROR: minikube not running. Start with: minikube start --cpus=6 --memory=16g --disk-size=50g"
  exit 1
fi

# Step 1: install prometheus-operator CRDs (idempotent, server-side apply)
echo ""
echo "=== Step 1/4: prometheus-operator CRDs ==="
for crd in "${CRDS[@]}"; do
  echo "  applying $crd"
  kubectl apply --server-side --force-conflicts -f "$CRD_BASE/$crd" >/dev/null 2>&1 || {
    echo "  WARN: failed $crd (may already exist)"
  }
done
echo "  CRDs installed: $(kubectl get crd -l app.kubernetes.io/name=prometheus 2>/dev/null | wc -l) (expected 10+)"

# Step 2: namespace + grafana-admin secret
echo ""
echo "=== Step 2/4: namespace + grafana-admin secret ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

if ! kubectl get secret grafana-admin -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  creating grafana-admin secret (admin/admin)"
  kubectl create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin=admin \
    -n "$NAMESPACE"
else
  echo "  grafana-admin secret already exists"
fi

# Step 3: helm dependency update + install
echo ""
echo "=== Step 3/4: helm install observability-demo ==="
helm dependency update "$CHART_PATH" >/dev/null 2>&1 || true

# Wait for previous prometheus-operator deployment to clear (if upgrading)
kubectl delete pod -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-operator --force >/dev/null 2>&1 || true

helm upgrade --install observability-demo "$CHART_PATH" \
  -n "$NAMESPACE" \
  -f "$VALUES_DEMO" \
  --set targetNamespace=spark-infra \
  --timeout 300s \
  --skip-crds \
  --post-renderer "$POST_RENDERER"

# Step 4: wait for key deployments
echo ""
echo "=== Step 4/4: wait for Ready ==="
for deploy in \
  observability-demo-grafana \
  observability-demo-loki-gateway \
  observability-demo-prometh-operator; do
  echo "  waiting for $deploy"
  kubectl wait deployment/"$deploy" -n "$NAMESPACE" \
    --for=condition=available --timeout=300s 2>/dev/null || \
    echo "  WARN: $deploy not ready after 300s"
done

kubectl wait deployment/otel-collector -n "$NAMESPACE" \
  --for=condition=available --timeout=120s 2>/dev/null || true
kubectl wait deployment/demo-metrics-exporter -n "$NAMESPACE" \
  --for=condition=available --timeout=120s 2>/dev/null || true

# StatefulSets (prometheus, alertmanager, loki)
for sts in \
  prometheus-observability-demo-prometh-prometheus \
  observability-demo-loki-0; do
  echo "  waiting for $sts rollout"
  kubectl rollout status statefulset/"$sts" -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
    echo "  WARN: $sts not rolled out"
done

# Step 5: deploy reference dashboards as ConfigMaps
echo ""
echo "=== Step 5: import reference dashboards ==="
DASHBOARDS_DIR="$PROJECT_ROOT/charts/observability/grafana/dashboards"

# Spark folder dashboards
SPARK_DASHBOARDS=(
  spark-overview.json
  performance-analysis.json
  spark-jvm-performance.json
  jvm-overview.json
  spark-operator-scale.json
  spark-job-anatomy.json
  demo-spark-overview.json
)
OPS_DASHBOARDS=(
  cost-by-job.json
  cost-by-team.json
  cost-breakdown.json
  cost-trends.json
  incident-metrics.json
  slo-forecast.json
  budget-status.json
  backup-status.json
  rto-rpo.json
  chaos-metrics.json
  dcgm-exporter.json
  minio-overview.json
  airflow-cluster.json
  airflow-statsd.json
)

CM_SPARK_ARGS=()
for f in "${SPARK_DASHBOARDS[@]}"; do
  path="$DASHBOARDS_DIR/$f"
  [[ -f "$path" ]] && CM_SPARK_ARGS+=(--from-file="$path")
done
if [[ ${#CM_SPARK_ARGS[@]} -gt 0 ]]; then
  kubectl create configmap grafana-dashboards-spark \
    --namespace="$NAMESPACE" \
    "${CM_SPARK_ARGS[@]}" \
    --dry-run=client -o yaml | \
    kubectl apply --server-side --force-conflicts -f - >/dev/null
  kubectl label configmap grafana-dashboards-spark -n "$NAMESPACE" \
    grafana_dashboard=1 --overwrite >/dev/null
  echo "  grafana-dashboards-spark: ${#SPARK_DASHBOARDS[@]} dashboards"
fi

CM_OPS_ARGS=()
for f in "${OPS_DASHBOARDS[@]}"; do
  path="$DASHBOARDS_DIR/$f"
  [[ -f "$path" ]] && CM_OPS_ARGS+=(--from-file="$path")
done
if [[ ${#CM_OPS_ARGS[@]} -gt 0 ]]; then
  kubectl create configmap grafana-dashboards-ops \
    --namespace="$NAMESPACE" \
    "${CM_OPS_ARGS[@]}" \
    --dry-run=client -o yaml | \
    kubectl apply --server-side --force-conflicts -f - >/dev/null
  kubectl label configmap grafana-dashboards-ops -n "$NAMESPACE" \
    grafana_dashboard=1 --overwrite >/dev/null
  echo "  grafana-dashboards-ops: ${#OPS_DASHBOARDS[@]} dashboards"
fi

# Trigger Grafana sidecar reload by restarting grafana deployment
echo "  restarting grafana to pick up dashboards"
kubectl rollout restart deployment/observability-demo-grafana -n "$NAMESPACE" >/dev/null
kubectl rollout status deployment/observability-demo-grafana -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

# Done
echo ""
echo "=== Stand deployed ==="
echo "Grafana: $(minikube service observability-demo-grafana -n "$NAMESPACE" --url 2>/dev/null || echo "NodePort 30030")"
echo "Prometheus: $(minikube service observability-demo-prometh-prometheus -n "$NAMESPACE" --url 2>/dev/null || echo "ClusterIP only")"
echo ""
echo "Verify: ./scripts/verify-observability-stand.sh"
