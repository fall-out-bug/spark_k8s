## UAT: F01 Spark Standalone Helm Chart

### Overview

This feature provides `charts/spark-standalone` for deploying Spark Standalone (master/workers) with optional MinIO and Airflow.

### Prerequisites

- Kubernetes cluster (Minikube/k3s for local validation)
- `kubectl`, `helm`
- Image `spark-custom:3.5.7` available to the cluster

### Quick Smoke Test (30 sec)

```bash
./scripts/test-sa-prodlike-all.sh spark-sa-prodlike spark-prodlike
```

### Detailed Scenarios (5–10 min)

1. **Standalone Spark**
   - Verify master UI: `kubectl exec -n spark-sa-prodlike deploy/spark-prodlike-spark-standalone-master -- curl -fsS http://localhost:8080/`
   - Run a sample job (SparkPi) via `scripts/test-spark-standalone.sh`.

2. **Airflow**
   - Trigger DAGs and confirm `success`:
     - `example_bash_operator`
     - `spark_etl_synthetic`
   - Use: `scripts/test-prodlike-airflow.sh`.

### Red Flags

- Spark job fails with missing `s3a://...` directories (bucket/prefix not initialized)
- Airflow DAG parsing errors (ConfigMap symlink recursion)
- PSS/SCC violations (`runAsNonRoot`, missing `seccompProfile`, `privileged`)

### Sign-off

- [ ] `helm lint` passes for both charts
- [ ] `scripts/test-sa-prodlike-all.sh` passes
- [ ] No unexpected restarts / CrashLoopBackOff

