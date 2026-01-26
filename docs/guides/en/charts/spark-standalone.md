# Spark Standalone Chart Guide

**Chart:** `charts/spark-standalone`  
**Tested on:** Minikube  
**Prepared for:** OpenShift-like constraints (PSS `restricted` / SCC `restricted`)

## Overview

Deploys **Spark Standalone** cluster (master + workers) with optional Airflow, MLflow, MinIO, Hive Metastore, and External Shuffle Service.

### What It Deploys

- **Spark Master** — Cluster coordinator (port 7077)
- **Spark Workers** — Executor nodes (configurable replicas)
- **External Shuffle Service** — Stable shuffle data serving (optional)
- **Airflow** — Workflow orchestration with KubernetesExecutor (optional)
- **MLflow** — ML lifecycle tracking server (optional)
- **MinIO** — S3-compatible object storage (optional)
- **Hive Metastore** — Metadata repository for Spark SQL tables (optional)

## Quickstart

### Prerequisites

- Kubernetes cluster (Minikube/k3s for local)
- `kubectl`, `helm`
- Docker image `spark-custom:3.5.7` available to cluster

### Install

```bash
# Create namespace
kubectl create namespace spark-sa

# Install with defaults
helm install spark-standalone charts/spark-standalone -n spark-sa

# Or with shared values overlay
helm install spark-standalone charts/spark-standalone -n spark-sa \
  -f charts/values-common.yaml

# Or with prod-like profile (tested on Minikube)
helm install spark-standalone charts/spark-standalone -n spark-sa \
  -f charts/spark-standalone/values-prod-like.yaml
```

### Verify

```bash
# Wait for master
kubectl wait --for=condition=ready pod -l app=spark-master -n spark-sa --timeout=120s

# Check status
kubectl get pods -n spark-sa
```

### Access

- **Spark Master UI:** `kubectl port-forward svc/spark-standalone-master 8080:8080 -n spark-sa` → http://localhost:8080
- **Airflow UI:** `kubectl port-forward svc/spark-standalone-airflow-webserver 8080:8080 -n spark-sa` → http://localhost:8080 (admin / admin)
- **MLflow UI:** `kubectl port-forward svc/spark-standalone-mlflow 5000:5000 -n spark-sa` → http://localhost:5000
- **MinIO Console:** `kubectl port-forward svc/spark-standalone-minio 9001:9001 -n spark-sa` → http://localhost:9001 (minioadmin / minioadmin)

## Key Configuration Values

### Top 10 Values to Know

1. **`sparkMaster.enabled`** — Enable Spark Master (default: `true`)
2. **`sparkMaster.ha.enabled`** — Enable High Availability (PVC-backed recovery) (default: `false`)
3. **`sparkWorker.replicas`** — Number of worker pods (default: `2`)
4. **`sparkWorker.memory`** — Memory per worker (default: `"2g"`)
5. **`airflow.enabled`** — Enable Airflow (default: `true`)
6. **`airflow.fernetKey`** — Shared Fernet key for Variables/Connections (required if Airflow enabled)
7. **`mlflow.enabled`** — Enable MLflow (default: `true`)
8. **`minio.enabled`** — Enable MinIO (default: `true`)
9. **`s3.endpoint`** — S3 endpoint URL (default: `"http://minio:9000"`)
10. **`security.podSecurityStandards`** — Enable PSS hardening (default: `true`)

### Example: Enable HA and Scale Workers

```yaml
# my-values.yaml
sparkMaster:
  ha:
    enabled: true
    persistence:
      enabled: true
      size: 1Gi

sparkWorker:
  replicas: 5
  memory: "4g"
```

```bash
helm upgrade spark-standalone charts/spark-standalone -n spark-sa -f my-values.yaml
```

## Values Overlays

See [`docs/guides/en/overlays/`](../overlays/) for copy-pasteable overlays:
- `values-anyk8s.yaml` — Generic baseline for any Kubernetes
- `values-sa-prodlike.yaml` — Prod-like profile (tested on Minikube, references `charts/spark-standalone/values-prod-like.yaml`)

## Smoke Tests

The repository provides smoke test scripts:

### Spark Standalone E2E

```bash
# Test Spark cluster health + SparkPi job
./scripts/test-spark-standalone.sh <namespace> <release-name>

# Example:
./scripts/test-spark-standalone.sh spark-sa spark-standalone
```

**Expected:** SparkPi job completes successfully, workers register with master.

### Airflow DAG Tests

```bash
# Test Airflow DAGs (example + ETL)
./scripts/test-prodlike-airflow.sh <namespace> <release-name>

# Example:
./scripts/test-prodlike-airflow.sh spark-sa-prodlike spark-prodlike
```

**Expected:** DAGs reach `success` state.

**Airflow Variables:**
The test script automatically sets required Airflow Variables for DAGs:
- `spark_image` — Spark Docker image (default: `spark-custom:3.5.7`)
- `spark_namespace` — Kubernetes namespace for Spark jobs (default: script namespace argument)
- `spark_standalone_master` — Spark Master URL (default: `spark://<release>-spark-standalone-master:7077`)
- `s3_endpoint` — S3 endpoint URL (default: `http://minio:9000`)
- `s3_access_key` — S3 access key (from `s3-credentials` secret if available)
- `s3_secret_key` — S3 secret key (from `s3-credentials` secret if available)

To override defaults, set environment variables before running the script:
```bash
export SPARK_NAMESPACE_VALUE=my-namespace
export SPARK_MASTER_VALUE=spark://custom-master:7077
export S3_ENDPOINT_VALUE=http://custom-s3:9000
./scripts/test-prodlike-airflow.sh spark-sa-prodlike spark-prodlike
```

See [`docs/guides/en/validation.md`](../validation.md) for full environment variable reference.

### Combined Smoke (Recommended)

```bash
# Run all tests (Spark E2E + Airflow)
./scripts/test-sa-prodlike-all.sh <namespace> <release-name>

# Example:
./scripts/test-sa-prodlike-all.sh spark-sa-prodlike spark-prodlike
```

**Expected:** All checks pass.

## Troubleshooting

### Workers Not Registering

**Check:**
```bash
# Master logs
kubectl logs deploy/spark-standalone-master -n spark-sa | grep -i worker

# Worker logs
kubectl logs deploy/spark-standalone-worker -n spark-sa
```

**Fix:** Verify `sparkMaster.service.ports.spark: 7077` and worker can reach master service.

### Airflow Variables Not Decrypting

**Symptom:** `ERROR - Can't decrypt _val for key=...`

**Fix:** Set `airflow.fernetKey` to a shared value across all Airflow pods. Generate with:
```bash
python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

### Airflow DAGs Failing Due to Missing Variables

**Symptom:** DAGs fail with errors like `Variable spark_namespace not found` or incorrect Spark Master URL.

**Fix:** Ensure Airflow Variables are set. The test script (`test-prodlike-airflow.sh`) auto-populates them, but for manual runs:
```bash
# Set variables via Airflow CLI (in scheduler pod)
kubectl exec -n <namespace> <scheduler-pod> -- \
  airflow variables set spark_namespace <namespace>
kubectl exec -n <namespace> <scheduler-pod> -- \
  airflow variables set spark_standalone_master spark://<release>-spark-standalone-master:7077
kubectl exec -n <namespace> <scheduler-pod> -- \
  airflow variables set s3_endpoint http://minio:9000
# ... (set other required variables)
```

See DAG source files in `charts/spark-standalone/files/airflow/dags/` for complete variable list.

### Spark Job Stuck in WAITING

**Check:**
```bash
# Worker resources
kubectl describe pod -l app=spark-worker -n spark-sa | grep -A 5 "Requests:"

# Job resource requests
kubectl logs <spark-driver-pod> -n spark-sa | grep -i "executor\|memory"
```

**Fix:** Ensure executor memory/cores requested by job ≤ worker capacity.

## Reference

- **Full values:** `charts/spark-standalone/values.yaml`
- **Prod-like values:** `charts/spark-standalone/values-prod-like.yaml`
- **Shared overlay:** `charts/values-common.yaml`
- **Repository map:** [`docs/PROJECT_MAP.md`](../../../PROJECT_MAP.md)
- **Russian version:** [`docs/guides/ru/charts/spark-standalone.md`](../../ru/charts/spark-standalone.md)
