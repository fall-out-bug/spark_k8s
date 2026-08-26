# Matrix with Shared Infra (History, MinIO, Hive, Observability)

## Prerequisites

1. **Deploy shared infra** (one-time):
   ```bash
   ./scripts/deploy-shared-infra-minikube.sh
   ```
   This creates:
   - `spark-infra` namespace: MinIO, PostgreSQL, Hive Metastore, History Server (no Standalone/Airflow/Jupyter)
   - `observability` namespace: OTEL Collector, Grafana, Prometheus, Loki

   > Use `deploy-shared-infra-minikube.sh` for matrix — lighter than demo. `deploy-demo-minikube.sh` also works but deploys full demo (Standalone, Airflow, Jupyter).

2. **Build images** (if not done):
   ```bash
   ./scripts/build-and-load-matrix-images.sh --quick   # 3.5.7 only, fastest
   # or
   ./scripts/build-and-load-matrix-images.sh --96     # all variants for 96/320
   ```

## Run Matrix with Shared Infra

```bash
# Quick smoke: one scenario (SCENARIO-0036 by default)
./scripts/smoke-one-matrix-scenario.sh

# 96 scenarios (gpu=false, k8s)
./scripts/run-matrix-96.sh --shared-infra

# All scenarios (full 320-scenario matrix)
./scripts/run-matrix.sh --shared-infra all
```

## What Shared Infra Does

| Component | Per-scenario (default) | Shared infra |
|-----------|------------------------|--------------|
| MinIO | `${RELEASE}-minio.${NS}` | `minio.spark-infra` |
| History Server | `${RELEASE}-history.${NS}` | `spark-infra-spark-35-history.spark-infra` |
| Hive Metastore | `${RELEASE}-metastore` | `spark-infra-spark-35-metastore.spark-infra` |
| OTEL telemetry | — | `otel-collector.observability` |

- **Faster**: No per-scenario MinIO/Hive/History deploy
- **Telemetry**: All scenarios send traces to observability stack
- **Event logs**: All in `s3a://spark-logs/events` (shared MinIO)

## Results

Same as default: `tests/results/scenario-*.json`, `matrix-96-summary.json` / `matrix-320-summary.json`.
