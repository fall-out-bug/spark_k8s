# Test Results - 2026-03-01

## Summary

| Test Suite | Passed | Failed | Skipped | Notes |
|------------|--------|--------|---------|-------|
| Smoke Tests | 5 | 1 | 0 | spark-submit timeout (resource constraints) |
| Preset Validation | 29 | 0 | 0 | All presets pass helm lint |
| Examples Validation | 10 | 0 | 0 | All Python examples compile |
| Load Tests | 0 | 3 | 0 | Executor startup issues (resource constraints) |

## Details

### 1. Smoke Tests

| Test | Status | Notes |
|------|--------|-------|
| k8s-connect | ✓ PASS | Cluster accessible |
| namespace-exists | ✓ PASS | spark-airflow namespace active |
| master-pod-running | ✓ PASS | airflow-sc-standalone-master running |
| worker-pods-running | ✓ PASS | 1 worker running |
| services-endpoints | ✓ PASS | Master service available |
| monitoring-resources | ✓ PASS | 8 dashboards, 1 prometheus rule |
| spark-submit-basic | ✗ FAIL | Executor timeout (resource constraints) |

### 2. Preset Validation

All 29 presets pass `helm lint`:
- **Cloud**: aws, azure, gcp (3)
- **Integration**: kafka-external (1)
- **OpenShift**: anyuid, restricted, demo-nyc-taxi-* (5)
- **Scenarios**: airflow-*, jupyter-* (7)
- **Tuning**: etl, streaming, small-cluster, large-cluster, ml-classification, ml-regression (6)
- **Core**: core-baseline, core-gpu, core-iceberg, core-gpu-iceberg (4)
- **Other**: gpu-values, iceberg-values, shared-infrastructure, spark-infra (4)

### 3. Examples Validation

All 10 Python examples compile successfully:
- **Batch**: etl_pipeline.py, data_quality.py (2)
- **ML**: classification_catboost.py, regression_spark_ml.py (2)
- **Streaming**: file_stream_basic.py, kafka_stream_backpressure.py, kafka_exactly_once.py (3)
- **Init files**: 3

### 4. Load Tests

| Test | Data Size | Status | Notes |
|------|-----------|--------|-------|
| Throughput | 100K rows | ✗ FAIL | Executor startup timeout |
| Aggregation | 50K rows | ✗ FAIL | Executor startup timeout |
| Sort | 10K rows | ✗ FAIL | Executor startup timeout |

**Root Cause**: Load tests fail due to executor startup issues. The cluster has limited resources (1 worker with 1 CPU, 2GB RAM). Executors are being created but timing out before completing the job.

**Recommendation**: For load testing, use a larger cluster with:
- Multiple workers (3+)
- More resources per worker (4+ CPU, 8+ GB RAM)
- Higher resource limits

## Test Environment

- **Kubernetes**: Minikube
- **Namespace**: spark-airflow
- **Release**: airflow-sc
- **Spark Version**: 3.5.7
- **Worker Resources**: 1 CPU, 2GB RAM
- **Master Resources**: 0.5 CPU, 1GB RAM

## Conclusion

1. **Code Quality**: ✓ All code compiles and validates
2. **Configuration**: ✓ All presets are valid
3. **Monitoring**: ✓ Dashboards and alerts deployed
4. **Runtime**: ⚠ Resource constraints prevent load testing

For production use:
- Increase worker resources
- Test with actual data in representative environment
- Run load tests on dedicated cluster
