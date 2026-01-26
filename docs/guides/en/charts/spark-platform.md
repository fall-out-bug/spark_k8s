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
2. **`sparkConnect.backendMode`** — Backend mode: `"k8s"` (K8s executors) or `"standalone"` (Standalone backend) (default: `"k8s"`)
3. **`sparkConnect.standalone.masterService`** — Standalone master service name (required when `backendMode=standalone`)
4. **`sparkConnect.standalone.masterPort`** — Standalone master port (default: `7077`)
5. **`sparkConnect.executor.memory`** — Memory per executor pod (default: `"1g"`)
6. **`sparkConnect.dynamicAllocation.maxExecutors`** — Max executor pods (default: `5`, only for K8s mode)
7. **`jupyterhub.enabled`** — Enable JupyterHub (default: `true`)
8. **`minio.enabled`** — Enable MinIO (default: `true`)
9. **`s3.endpoint`** — S3 endpoint URL (default: `"http://minio:9000"`)
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

Spark Connect supports two backend modes for both Spark 3.5 and 4.1:

#### 1. K8s Executors Mode (Default)

Connect creates executor pods dynamically via Kubernetes API. This is the recommended mode for most use cases.

**Configuration:**
```yaml
# Spark 3.5 (umbrella chart)
spark-connect:
  sparkConnect:
    backendMode: "k8s"  # Default
    executor:
      memory: "1g"
      cores: 1
    dynamicAllocation:
      enabled: true
      minExecutors: 0
      maxExecutors: 5

# Spark 4.1 (direct chart)
connect:
  backendMode: "k8s"  # Default
  executor:
    memory: "1Gi"
    cores: "1"
  dynamicAllocation:
    enabled: true
    minExecutors: 0
    maxExecutors: 10
```

**Deployment:**
```bash
# Spark 3.5
helm install spark-connect charts/spark-3.5 -n spark \
  -f docs/guides/en/overlays/values-connect-k8s.yaml \
  --set spark-connect.enabled=true

# Spark 4.1
helm install spark-connect charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=k8s
```

#### 2. Standalone Backend Mode

Connect submits jobs to an existing Spark Standalone cluster. Use this mode when you want to leverage existing Standalone workers.

**⚠️ Important:** The Standalone master service must be accessible from the Connect namespace. For same-namespace deployments, use the service name directly. For cross-namespace, use the full FQDN: `<service>.<namespace>.svc.cluster.local`.

**Configuration:**
```yaml
# Spark 3.5 (umbrella chart)
spark-connect:
  sparkConnect:
    backendMode: "standalone"
    standalone:
      masterService: "spark-sa-spark-standalone-master"  # Same namespace
      # masterService: "spark-standalone-master.spark-sa.svc.cluster.local"  # Cross-namespace
      masterPort: 7077

# Spark 4.1 (direct chart)
connect:
  backendMode: "standalone"
  standalone:
    masterService: "spark-sa-spark-standalone-master"  # Same namespace
    masterPort: 7077
```

**Deployment:**
```bash
# Spark 3.5 (same namespace)
helm install spark-connect charts/spark-3.5 -n spark \
  -f docs/guides/en/overlays/values-connect-standalone.yaml \
  --set spark-connect.enabled=true \
  --set spark-connect.sparkConnect.standalone.masterService=spark-sa-spark-standalone-master

# Spark 4.1 (same namespace)
helm install spark-connect charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-sa-spark-standalone-master
```

**Prerequisites:**
- Spark Standalone cluster must be deployed and running
- Standalone master service must be accessible (same namespace recommended)
- Standalone workers must be registered with the master

See overlay files for detailed configuration examples for both Spark 3.5 and 4.1.

## Smoke Tests

### Runtime Load Tests

For comprehensive validation under load, use the dedicated load test scripts:

**K8s Executors Mode:**
```bash
./scripts/test-spark-connect-k8s-load.sh <namespace> <release-name>

# Example:
./scripts/test-spark-connect-k8s-load.sh spark spark-connect-k8s

# With custom load parameters:
export LOAD_ROWS=2000000
export LOAD_PARTITIONS=100
export LOAD_ITERATIONS=5
export LOAD_EXECUTORS=5
./scripts/test-spark-connect-k8s-load.sh spark spark-connect-k8s
```

**Standalone Backend Mode:**
```bash
./scripts/test-spark-connect-standalone-load.sh <namespace> <release-name> [standalone-master]

# Example:
./scripts/test-spark-connect-standalone-load.sh spark spark-connect-standalone \
  spark://spark-sa-spark-standalone-master:7077
```

See [`docs/guides/en/validation.md`](../validation.md) for detailed documentation on load test scripts.

### Manual Validation

For quick manual checks:

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

### Standalone Backend Connection Issues

**Symptoms:**
- Connect fails to submit jobs to Standalone master
- Errors like `Connection refused` or `No route to host`

**Check:**
```bash
# Verify Standalone master service exists
kubectl get svc <standalone-master-service> -n <namespace>

# Check if Standalone master is accessible from Connect pod
kubectl exec -it deploy/<connect-deployment> -n <namespace> -- \
  nc -zv <standalone-master-service> 7077

# Check Standalone master logs
kubectl logs -n <namespace> <standalone-master-pod>
```

**Fix:**
- Ensure Standalone master service is in the same namespace (recommended) or use FQDN for cross-namespace
- Verify `sparkConnect.standalone.masterService` matches the actual service name
- Check network policies if using cross-namespace communication
- Ensure Standalone workers are registered with the master

## Reference

- **Full values:** `charts/spark-platform/values.yaml`
- **Shared overlay:** `charts/values-common.yaml`
- **Repository map:** [`docs/PROJECT_MAP.md`](../../../PROJECT_MAP.md)
- **Russian version:** [`docs/guides/ru/charts/spark-platform.md`](../../ru/charts/spark-platform.md)
