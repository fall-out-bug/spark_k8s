# Demo Repeatability Fixes — 2026-03-15

## Root Causes

1. The demo preset overrode Jupyter to `jupyter/all-spark-notebook:latest`, drifting from the repo-supported Spark `3.5.7` image.
2. Jupyter notebooks lived on `emptyDir`, so pod replacement discarded notebook state.
3. `upload-spark-jobs-to-minio.sh` uploaded Airflow DAG definitions instead of the Spark job scripts under `dags/spark_jobs/`.
4. Airflow DAGs expected `spark-standalone`, but the preset did not create or own that service account.
5. Grafana used a Prometheus service name that could exist without endpoints; `prometheus-operated` was the stable endpoint-backed service.
6. Promtail existed only as a manual patch, so log collection disappeared on redeploy.
7. Port-forwards used stale service names and did not self-heal after pod churn.
8. Spark Connect was enabled without limiting cluster core usage, starving batch DAGs.

## Permanent Fixes

- `charts/spark-3.5/presets/demo-full-spark-infra.yaml` now uses `spark-k8s-jupyter:3.5-3.5.7`, creates/owns `spark-standalone`, persists notebooks, publishes dashboards into `observability`, enables bounded Spark Connect, and keeps demo-safe rollout strategies.
- `charts/spark-3.5/templates/jupyter-pvc.yaml` adds declarative notebook persistence.
- Airflow deployments inject Spark/MinIO env so DAGs stop relying on unmanaged cluster state.
- DAGs use `spark-custom:3.5.7`; the extra `spark-custom-ml:3.5.7` runtime dependency was removed.
- `scripts/seed-demo-data.sh` became the canonical idempotent step for Spark job scripts plus real datasets.
- `scripts/deploy-demo-minikube.sh` and `scripts/restore-demo.sh` now ensure demo images, seed data, redeploy observability, and restart port-forwards.
- Observability now uses `prometheus-operated`, includes the ServiceMonitor release label, provisions Promtail declaratively, and applies the existing Prometheus operator post-renderer.
- `tests/observability/start-ui-portforwards.sh` now points at the correct services and restarts stale forwards.

## Verified State

- `./scripts/check-demo-health.sh` passes.
- `./scripts/validate-demo-reality.sh` passes.
- Grafana returns Spark metrics and lists Spark dashboards.
- Jupyter imports `pyspark 3.5.7`, sees 6 seeded notebooks, and executes `SparkSession.builder.getOrCreate()` successfully.
- Successful Airflow manual runs were verified for:
  - `spark_standalone_load_demo`
  - `citibike_analytics_pipeline`
  - `movielens_recommendation_pipeline`
  - `nyc_taxi_ml_full_pipeline`
- MinIO contains 24 months of real NYC Taxi parquet files in `nyc-taxi/raw/`.
