# Implementation Plan: Spark Load Tests with 10GB NYC Taxi

**Branch**: `025-load-tests-10gb-nyc-taxi` | **Date**: 2026-06-14 | **Spec**: [spec.md](./spec.md)

**Note**: Initial plan migrated from `WS-025-11`. Run `/speckit.plan` to refine.

## Summary

Validate that `charts/spark-3.5/` Helm chart handles a realistic 10GB NYC Taxi pipeline across 4 deployment scenarios (jupyter-k8s, jupyter-standalone, airflow-k8s, airflow-standalone). Capture metrics, verify Grafana dashboards, produce comparative report.

## Technical Context

### Pipeline Topology

```
┌─────────────────────────────────────────────────────┐
│                    Data Pipeline                      │
│                                                       │
│  MinIO (raw-data)                                     │
│       │                                               │
│       ▼                                               │
│  [1] Read Parquet ──► [2] GroupBy/Agg                │
│       │                      │                        │
│       ▼                      ▼                        │
│  [3] Join (zones) ──► [4] Window (running avg)       │
│                              │                        │
│                              ▼                        │
│                     [5] Write Parquet (partitioned)   │
│                              │                        │
│                              ▼                        │
│                     MinIO (processed-data)            │
└─────────────────────────────────────────────────────┘
```

### Components

- **Helm chart**: `charts/spark-3.5/` (Spark 3.5.7 base)
- **Image pyramid**: `spark-k8s-runtime:3.5-7-baseline` (no GPU, no Iceberg)
- **Storage**: MinIO (S3-compatible, `s3a://`, path-style)
- **Orchestrators**: Jupyter notebook OR Airflow DAG (per scenario)
- **Observability**: Grafana + Prometheus + Loki + Spark History Server
- **Event log**: persisted to `s3a://spark-logs/3.5.7/events/`

### Test Scenarios (matrix slices)

| Scenario                         | Orchestrator | Mode       | Image                              |
|----------------------------------|--------------|------------|------------------------------------|
| `jupyter-connect-k8s-3.5.7`      | Jupyter      | k8s        | spark-k8s-jupyter:3.5-7-baseline   |
| `jupyter-connect-standalone-3.5.7` | Jupyter    | standalone | spark-k8s-jupyter:3.5-7-baseline   |
| `airflow-connect-k8s-3.5.7`      | Airflow DAG  | k8s        | spark-k8s-runtime:3.5-7-baseline   |
| `airflow-connect-standalone-3.5.7` | Airflow DAG | standalone | spark-k8s-runtime:3.5-7-baseline   |

### Files to Create

- `scripts/tests/load/prepare-nyc-taxi-data.sh` — download + upload to MinIO (idempotent)
- `scripts/tests/load/spark-35-load-test.py` — PySpark job: 5 operations, metrics capture
- `scripts/tests/load/run-load-tests.sh` — orchestrator across 4 scenarios
- `scripts/tests/load/report-template.md` — comparative report skeleton
- `docs/reports/F25-load-test-report.md` — final report (filled at execution)

### Test Strategy

- **Unit-level**: N/A (script-based, no Python module)
- **Integration**: `helm template` for each scenario's values file
- **E2E**: `pytest -m e2e` running each scenario against Minikube; assertions on exit code + metric presence
- **Quality gate**: `helm lint charts/spark-3.5` + `./scripts/check-demo-health.sh` pre/post

### Risks

| Risk | Mitigation |
|------|------------|
| 10GB download bandwidth | Mirror to internal S3 or use pre-built MinIO image with data |
| MinIO bucket prefix dir marker | Use `mc mb -p` + `mc cp` to ensure proper markers |
| Dynamic allocation not observed on small cluster | Pin executor count to 3 for k8s; document expected scale events |
| Airflow DAG runtime > smoke budget | Run Airflow scenarios in nightly matrix (P1), not PR (P0) |

## Dependencies

- `charts/spark-3.5/` chart (F01, F06 — completed)
- MinIO deployment (`charts/spark-3.5/templates/minio/`)
- Spark History Server (F03 — completed)
- Grafana dashboards (F31 — completed): `spark-overview`, `executor-metrics`, `job-performance`
- Minikube with 6 CPU / 16GB / 50GB

## Open Questions (resolve via `/speckit.clarify`)

1. Source data: NYC TLC direct download vs pre-built bundle in GHCR image?
2. Window function scope: per-driver running avg vs per-zone rank?
3. Report format: markdown table only, or also embed Grafana snapshots?
4. Should this WS extend to Spark 4.1.0 baseline, or strict 3.5.7?
