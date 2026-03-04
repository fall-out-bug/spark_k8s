# Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `SPARK_HOME` | Spark installation path | `/opt/spark` |
| `SPARK_MASTER` | Master URL | `k8s://https://...` |
| `SPARK_DRIVER_MEMORY` | Driver heap | `2g` |
| `SPARK_EXECUTOR_MEMORY` | Executor heap | `4g` |
| `AWS_ACCESS_KEY_ID` | S3 access | — |
| `AWS_SECRET_ACCESS_KEY` | S3 secret | — |

See [spark-defaults.conf](spark-3.5-defaults.md) for config equivalents.
