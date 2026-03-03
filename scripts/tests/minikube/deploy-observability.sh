#!/usr/bin/env bash
# Deploy OpenTelemetry Collector + Grafana for Spark telemetry and dashboards (minikube).
# Run after scenario 0 (spark-infra). Connect presets expect otel-collector.observability.svc.cluster.local:4317.
# Usage: ./deploy-observability.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
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
        - containerPort: 8889
          name: prometheus
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
      prometheus:
        endpoint: "0.0.0.0:8889"
        namespace: otel
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [logging]
        metrics:
          receivers: [otlp]
          exporters: [prometheus, logging]
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
  - name: prometheus
    port: 8889
    targetPort: 8889
EOF
kubectl wait --for=condition=available deployment/otel-collector -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true

# Prometheus + demo-metrics-exporter + Grafana dashboard ConfigMaps
kubectl apply -f "$PROJECT_ROOT/tests/observability/prometheus-demo.yaml"
kubectl apply -f "$PROJECT_ROOT/tests/observability/demo-metrics-exporter.yaml"
kubectl apply -f "$PROJECT_ROOT/tests/observability/grafana-dashboards.yaml"
kubectl apply -f "$PROJECT_ROOT/tests/observability/grafana-dashboards-spark.yaml"
kubectl apply -f "$PROJECT_ROOT/tests/observability/grafana-dashboard-tech-lead.yaml"
kubectl apply -f "$PROJECT_ROOT/tests/observability/grafana-dashboard-logs-explorer.yaml"

# Loki + Promtail for log aggregation (Spark, Airflow)
kubectl apply -f "$PROJECT_ROOT/tests/observability/loki.yaml"
kubectl apply -f "$PROJECT_ROOT/tests/observability/promtail.yaml"
kubectl wait deployment/loki -n "${NAMESPACE}" --for=condition=available --timeout=120s 2>/dev/null || true
kubectl wait deployment/prometheus -n "${NAMESPACE}" --for=condition=available --timeout=120s 2>/dev/null || true

# Grafana with sidecar to load dashboards from ConfigMaps (label grafana_dashboard=1)
# Set spark-infra with monitoring.grafanaDashboards.namespace=observability so dashboards land here
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana 2>/dev/null || true
helm upgrade --install grafana grafana/grafana \
  -n "${NAMESPACE}" \
  --set adminPassword=admin \
  --set service.type=NodePort \
  --set service.nodePort=30030 \
  --set persistence.enabled=false \
  --set sidecar.dashboards.enabled=true \
  --set sidecar.dashboards.label="grafana_dashboard" \
  --set sidecar.dashboards.labelValue="1" \
  --set sidecar.dashboards.searchNamespace=ALL \
  --set-json 'datasources.datasources.yaml={"apiVersion":1,"datasources":[{"name":"Prometheus","type":"prometheus","uid":"PBFA97CFB590B2093","access":"proxy","url":"http://prometheus.observability.svc.cluster.local:9090","isDefault":true},{"name":"Loki","type":"loki","uid":"loki","access":"proxy","url":"http://loki.observability.svc.cluster.local:3100","editable":false}]}' \
  --wait --timeout 120s 2>/dev/null || echo "Grafana install skipped (add grafana helm repo if needed)."

echo ""
echo "=== Observability deployed ==="
echo "  OTEL Collector: otel-collector.${NAMESPACE}.svc.cluster.local:4317"
echo "  Prometheus: NodePort 30090"
echo "  Grafana: NodePort 30030 (admin/admin)"
echo "  Loki: http://loki.${NAMESPACE}.svc.cluster.local:3100"
echo "  demo-metrics-exporter: scrapes Spark Master + History + Airflow (requires spark-infra with standalone+airflow)"
kubectl get pods -n "${NAMESPACE}"
