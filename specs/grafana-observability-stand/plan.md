# Implementation Plan: Grafana Observability Stand

**Branch**: `feature/grafana-observability-stand` | **Date**: 2026-06-14 | **Spec**: [spec.md](./spec.md)

## Summary

Extend existing `charts/observability-demo/` umbrella chart with reference dashboards (Spark JVM, Spark-Operator, DCGM GPU, MinIO bucket, Airflow statsd) + 3 new exporters (DCGM, MinIO metrics, Airflow statsd) + OpenLineage trace correlation. Single deploy script orchestrates everything on minikube.

## Technical Context

### Architecture

```
minikube (6 CPU / 16GB / 50GB)
│
├── namespace: spark-infra (existing)
│   ├── MinIO (S3 + bucket metrics scrape)
│   ├── Spark History Server
│   ├── Airflow (with statsd-exporter sidecar + OpenLineage provider)
│   └── Jupyter (optional)
│
├── namespace: observability (existing)
│   ├── Prometheus (existing) + new scrape targets:
│   │   ├── MinIO /minio/v2/metrics/{cluster,bucket,resource}
│   │   ├── DCGM Exporter (if GPU)
│   │   ├── Airflow statsd-exporter
│   │   └── Spark History /metrics/prometheus
│   ├── Grafana (existing) + new dashboards (ConfigMap sidecar)
│   ├── Loki (existing) + MinIO audit log webhook
│   ├── Jaeger (existing) + OTel collector
│   └── OTel Collector (existing)
│
└── namespace: gpu-system (conditional, GPU only)
    └── DCGM Exporter DaemonSet
```

### Components Touched

| Component | Status | Change |
|-----------|--------|--------|
| `charts/observability-demo/` | exists | Add ServiceMonitors for MinIO/Airflow, ConfigMaps for new dashboards |
| `charts/observability/grafana/dashboards/` | exists (14 dashboards) | Add 7 new: spark-jvm-performance.json (7890), jvm-overview.json (7727), spark-operator.json (23032), dcgm-exporter.json (12239), minio-bucket.json (19237), airflow-cluster.json (20994), airflow-statsd.json (14451) |
| `charts/observability-demo/values-demo.yaml` | exists | Enable Airflow statsd sidecar, MinIO ServiceMonitor, OpenLineage provider flag |
| `scripts/deploy-observability-stand.sh` | NEW | Orchestrator: minikube check → namespace → helm dependency update → helm upgrade --install → wait for Ready → import dashboards → smoke |
| `scripts/verify-observability-stand.sh` | NEW | AC1-AC13 checks, non-zero exit on failure |
| `scripts/tests/minikube/deploy-observability.sh` | exists | Keep as low-level helper; deploy-observability-stand.sh wraps it |

### Files to Create

- `scripts/deploy-observability-stand.sh` — main orchestrator
- `scripts/verify-observability-stand.sh` — acceptance test
- `charts/observability/grafana/dashboards/spark-jvm-performance.json` (#7890)
- `charts/observability/grafana/dashboards/jvm-overview.json` (#7727)
- `charts/observability/grafana/dashboards/spark-operator-scale.json` (#23032)
- `charts/observability/grafana/dashboards/dcgm-exporter.json` (#12239)
- `charts/observability/grafana/dashboards/minio-bucket.json` (#19237)
- `charts/observability/grafana/dashboards/airflow-cluster.json` (#20994)
- `charts/observability/grafana/dashboards/airflow-statsd.json` (#14451)
- `charts/observability-demo/templates/servicemonitor-minio.yaml` (NEW)
- `charts/observability-demo/templates/servicemonitor-airflow-statsd.yaml` (NEW)
- `charts/observability-demo/templates/dashboards-configmap.yaml` (NEW — wraps new dashboards for sidecar)

### Files to Modify

- `charts/observability-demo/values-demo.yaml` — enable statsd, OpenLineage, MinIO metrics
- `charts/observability-demo/templates/` (existing) — wire OpenLineage provider into Airflow subchart

### Test Strategy

- **Static**: `helm lint charts/observability-demo`
- **Integration**: `pytest tests/integration/test_observability_*.py` (existing) + new `test_observability_stand.py`
- **E2E**: `scripts/verify-observability-stand.sh` after deploy
- **Quality gate**: `./scripts/check-demo-health.sh` MUST still pass

### Risks

| Risk | Mitigation |
|------|------------|
| Grafana dashboard JSON IDs drift upstream | Pin dashboards in repo, version-tag in commit message |
| DCGM exporter fails on non-GPU minikube | Make DCGM Helm install conditional on `.Values.gpu.enabled` (default false) |
| MinIO Prometheus auth requires bearer token | Use `mc admin prometheus generate` at deploy time, inject into ServiceMonitor |
| OpenLineage provider breaks Airflow scheduler | Pin provider version, test in isolation before enabling |
| Existing `charts/observability-demo/` Helm dependency conflicts | Use `helm dependency update` explicitly; do not modify Chart.yaml dependency versions |
| 16GB minikube too tight for full stack | Tune requests; DCGM + extra dashboards add ~500MB; budget OK |
| MinIO audit log → Loki webhook requires MinIO restart | Document in deploy script |

## Dependencies

- minikube 6 CPU / 16GB / 50GB running
- Existing `charts/observability-demo/` umbrella chart
- Existing `scripts/tests/minikube/deploy-observability.sh`
- Internet access to download dashboard JSONs from grafana.com
- `mc` (MinIO client) for `mc admin prometheus generate`

## Open Questions (resolve via `/speckit.clarify`)

1. DCGM exporter — install only when GPU detected, or always install (DaemonSet that no-ops on CPU nodes)?
2. OpenLineage transport — push to existing Jaeger, or add Marquez container?
3. Dashboard JSONs — download live from grafana.com at deploy time, or commit vendored copies in repo?
4. Spark History Server metrics — already scraped, or need additional `/metrics/prometheus` endpoint config?
