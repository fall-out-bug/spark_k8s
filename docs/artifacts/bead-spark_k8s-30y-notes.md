# Bead spark_k8s-30y: WS-034-04 Metrics Validation

**WS:** 00-034-04 (Test Matrix — History Server)

## Changes

1. **nyc_taxi_pipeline.py:** spark.eventLog.enabled=true, spark.eventLog.dir=s3a://spark-logs/events for load level
2. **run-matrix.sh:** History Server check after load (curl api/v1/applications, grep nyc-taxi-load)

## Verification

- **AC1:** run_load_test → curl History Server API — implemented; app may need 20-30s to appear
- **AC2:** Event log path s3a://spark-logs/events (3.5.x)
- **AC3:** History Server logDirectory s3a://spark-logs/events (shared-infra-values, spark-base)

## Classification

- **Test:** Pipeline writes event logs; run-matrix checks History Server
- **Infra:** Requires spark-infra with History Server + minio spark-logs
