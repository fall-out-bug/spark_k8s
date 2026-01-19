# Spark Platform Chart Guide

**Chart:** `charts/spark-platform`  
**Tested on:** Minikube  
**Prepared for:** OpenShift-like constraints (PSS `restricted` / SCC `restricted`)

## Overview

Deploys **Spark Connect** (gRPC server) with dynamic Kubernetes executor pods, plus optional JupyterHub, MinIO, Hive Metastore, and History Server.

### What It Deploys

- **Spark Connect Server** — gRPC API (port 15002) for client connections; creates executor pods dynamically via K8s API
- **JupyterHub** — Multi-user Jupyter environment with KubeSpawner (optional)
- **MinIO** — S3-compatible object storage (optional)
- **Hive Metastore** — Metadata repository for Spark SQL tables (optional)
- **Spark History Server** — Web UI for viewing completed Spark applications (optional)

## Quickstart

### Prerequisites

- Kubernetes cluster (Minikube/k3s for local)
- `kubectl`, `helm`
- Docker image `spark-custom:3.5.7` available to cluster

### Install

```bash
# Create namespace
kubectl create namespace spark

# Install with defaults
helm install spark-platform charts/spark-platform -n spark

# Or with shared values overlay
helm install spark-platform charts/spark-platform -n spark \
  -f charts/values-common.yaml
```

### Verify

```bash
# Wait for pods
kubectl wait --for=condition=ready pod -l app=spark-connect -n spark --timeout=120s

# Check status
kubectl get pods -n spark
```

### Access

- **JupyterHub:** `kubectl port-forward svc/spark-platform-jupyterhub 8000:8000 -n spark` → http://localhost:8000 (admin / admin123)
- **Spark UI:** `kubectl port-forward svc/spark-platform-spark-connect 4040:4040 -n spark` → http://localhost:4040
- **History Server:** `kubectl port-forward svc/spark-platform-history-server 18080:18080 -n spark` → http://localhost:18080
- **MinIO Console:** `kubectl port-forward svc/spark-platform-minio 9001:9001 -n spark` → http://localhost:9001 (minioadmin / minioadmin)

## Key Configuration Values

### Top 10 Values to Know

1. **`sparkConnect.enabled`** — Enable Spark Connect Server (default: `true`)
2. **`sparkConnect.master`** — Spark master mode: `"local"` or `"k8s"` (default: `"k8s"`)
3. **`sparkConnect.executor.memory`** — Memory per executor pod (default: `"1g"`)
4. **`sparkConnect.dynamicAllocation.maxExecutors`** — Max executor pods (default: `5`)
5. **`jupyterhub.enabled`** — Enable JupyterHub (default: `true`)
6. **`minio.enabled`** — Enable MinIO (default: `true`)
7. **`s3.endpoint`** — S3 endpoint URL (default: `"http://minio:9000"`)
8. **`s3.accessKey`** / **`s3.secretKey`** — S3 credentials
9. **`historyServer.logDirectory`** — Event log directory (default: `"s3a://spark-logs/events"`)
10. **`serviceAccount.name`** — ServiceAccount name (default: `"spark"`)

### Example: Customize Executor Resources

```yaml
# my-values.yaml
sparkConnect:
  executor:
    memory: "2g"
    cores: 2
  dynamicAllocation:
    maxExecutors: 10
```

```bash
helm upgrade spark-platform charts/spark-platform -n spark -f my-values.yaml
```

## Values Overlays

See [`docs/guides/en/overlays/`](../overlays/) for copy-pasteable overlays:
- `values-anyk8s.yaml` — Generic baseline for any Kubernetes
- `values-sa-prodlike.yaml` — Prod-like profile (tested on Minikube)
- `values-connect-k8s.yaml` — Connect-only mode (K8s executors, default)
- `values-connect-standalone.yaml` — Connect + Standalone backend mode

### Connect Backend Modes

Spark Connect supports two backend modes:

1. **K8s executors mode** (default) — Connect creates executor pods dynamically via Kubernetes API
   ```bash
   helm install spark-connect charts/spark-3.5 -n spark \
     -f docs/guides/en/overlays/values-connect-k8s.yaml \
     --set spark-connect.enabled=true
   ```

2. **Standalone backend mode** — Connect submits jobs to an existing Spark Standalone cluster
   ```bash
   helm install spark-connect charts/spark-3.5 -n spark \
     -f docs/guides/en/overlays/values-connect-standalone.yaml \
     --set spark-connect.enabled=true \
     --set spark-connect.sparkConnect.standalone.masterService=<standalone-master-service>
   ```

See overlay files for detailed configuration examples for both Spark 3.5 and 4.1.

## Smoke Tests

No dedicated smoke scripts exist for `spark-platform` yet. Manual validation:

```bash
# 1. Check Spark Connect is reachable
kubectl exec -it deploy/spark-platform-spark-connect -n spark -- \
  curl -fsS http://localhost:4040/api/v1/applications

# 2. Check JupyterHub UI
kubectl port-forward svc/spark-platform-jupyterhub 8000:8000 -n spark &
# Open http://localhost:8000 and verify login works
```

## Troubleshooting

### Executor Pods Not Created

**Check:**
```bash
# RBAC
kubectl auth can-i create pods --as=system:serviceaccount:spark:spark -n spark

# Driver logs
kubectl logs deploy/spark-platform-spark-connect -n spark | grep -i executor
```

**Fix:** Ensure `rbac.create: true` and `serviceAccount.create: true` in values.

### S3 Connection Errors

**Check:**
```bash
kubectl get pods -n spark -l app=minio
kubectl logs deploy/spark-platform-minio -n spark
```

**Fix:** Verify `s3.endpoint` matches MinIO service name and `s3.sslEnabled: false` for MinIO.

## Reference

- **Full values:** `charts/spark-platform/values.yaml`
- **Shared overlay:** `charts/values-common.yaml`
- **Repository map:** [`docs/PROJECT_MAP.md`](../../../PROJECT_MAP.md)
- **Russian version:** [`docs/guides/ru/charts/spark-platform.md`](../../ru/charts/spark-platform.md)
