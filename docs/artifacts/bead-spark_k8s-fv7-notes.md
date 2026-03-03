# Bead spark_k8s-fv7: WS-034-03 Full Critical Path

**WS:** 00-034-03 (Test Matrix — Deploy+Smoke+E2E+Load+Metrics)

## Verification

- **AC1:** run-matrix all for one scenario — PASS (SCENARIO-0013 baseline, smoke+e2e+load) when spark-infra + nyc-taxi
- **AC2:** S3_ENDPOINT passed at all levels — run-matrix env + nyc_taxi_pipeline spark.hadoop.fs.s3a
- **AC3:** Load test S3 only — run_load uses s3a://nyc-taxi/raw/, no in-memory fallback
- **AC4:** Event logs + MinIO init spark-logs/4.1/events — runbook bootstrap (1xt.5), minio init job in spark-base

## Classification

- **Test:** run-matrix works for baseline when image exists
- **Infra:** Requires spark-infra with minio + nyc-taxi bucket for load
- **Chart:** run-matrix uses minimal deploy (no minio per-ns), shared infra

## Artifacts

- `tests/run-matrix.sh` — get_runtime_image, run_smoke/e2e/load
- `tests/scripts/nyc_taxi_pipeline.py` — S3 config, _list_parquet_paths
