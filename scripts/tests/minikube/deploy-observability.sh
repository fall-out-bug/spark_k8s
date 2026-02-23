#!/usr/bin/env bash
# Deploy OpenTelemetry Collector + Grafana for Spark telemetry and dashboards (minikube).
# Run after scenario 0 (spark-infra). Connect presets expect otel-collector.observability.svc.cluster.local:4317.
# Usage: ./deploy-observability.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${OBSERVABILITY_NS:-observability}"

echo "=== Deploying Observability (OTEL Collector + Grafana) into ${NAMESPACE} ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# OpenTelemetry Collector: receive gRPC 4317, export to logging (no Helm dependency)
echo "Deploying OTEL Collector..."
kubectl apply -f - -n "${NAMESPACE}" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:0.96.0
        args: ["--config=/etc/otel/config.yaml"]
        ports:
        - containerPort: 4317
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /etc/otel
      volumes:
      - name: config
        configMap:
          name: otel-collector-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    exporters:
      logging:
        verbosity: normal
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [logging]
        metrics:
          receivers: [otlp]
          exporters: [logging]
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
spec:
  selector:
    app: otel-collector
  ports:
  - name: grpc
    port: 4317
    targetPort: 4317
EOF
kubectl wait --for=condition=available deployment/otel-collector -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true

# Grafana with sidecar to load dashboards from ConfigMaps (label grafana_dashboard=1)
# Set spark-infra with monitoring.grafanaDashboards.namespace=observability so dashboards land here
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana 2>/dev/null || true
helm upgrade --install grafana grafana/grafana \
  -n "${NAMESPACE}" \
  --set adminPassword=admin \
  --set service.type=NodePort \
  --set persistence.enabled=false \
  --set sidecar.dashboards.enabled=true \
  --set sidecar.dashboards.label="grafana_dashboard" \
  --set sidecar.dashboards.labelValue="1" \
  --set sidecar.dashboards.searchNamespace=ALL \
  --wait --timeout 120s 2>/dev/null || echo "Grafana install skipped (add grafana helm repo if needed)."

echo ""
echo "=== Observability deployed ==="
echo "  OTEL Collector: otel-collector.${NAMESPACE}.svc.cluster.local:4317"
echo "  Grafana: kubectl port-forward svc/grafana 3000:3000 -n ${NAMESPACE}  -> http://localhost:3000 (admin/admin)"
echo "  Spark dashboards: enable in spark-infra with monitoring.grafanaDashboards.enabled=true and monitoring.grafanaDashboards.namespace=${NAMESPACE}; Grafana sidecar will load them."
kubectl get pods -n "${NAMESPACE}"
