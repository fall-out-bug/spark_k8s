# Metrics Reference

Key Prometheus metrics for Spark on Kubernetes.

| Metric | Description |
|--------|-------------|
| `spark_executor_metrics_memoryUsed` | Executor memory used |
| `spark_task_duration_max` | Max task duration |
| `spark_shuffle_read_bytes` | Shuffle read |
| `spark_shuffle_write_bytes` | Shuffle write |

Run `scripts/docs/generate-metrics-reference.sh` to regenerate from Prometheus.
