# Archived — Deprecated 2026-03-06

These raw YAMLs were replaced by `charts/observability-demo` Helm chart.

**Use:** `scripts/tests/minikube/deploy-observability.sh` (Helm install observability-demo)

| File | Replaced by |
|------|-------------|
| prometheus-demo.yaml | charts/observability-demo (prometheus-spark subchart) |
| loki.yaml | charts/observability-demo (loki-spark subchart) |
| promtail.yaml | charts/observability-demo (loki-spark promtail) |
| demo-metrics-exporter.yaml | charts/observability-demo/templates/demo-metrics-exporter.yaml |
| grafana-*.yaml | charts/observability-demo (grafana-spark subchart) |

Kept for reference. Do not use.
