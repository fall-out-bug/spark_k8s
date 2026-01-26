# Spark K8s Constructor — Quick Reference

**Date:** 2025-01-26
**Version:** 0.1.0
**Spark:** 3.5.7, 4.1.0

> Quick reference for Spark K8s Constructor commands, recipes, and presets

## Table of Contents

- [Helm Commands](#helm-commands)
- [Component Management](#component-management)
- [Troubleshooting](#troubleshooting)
- [Useful kubectl Commands](#useful-kubectl-commands)
- [Environment Variables](#environment-variables)
- [Recipe Index](#recipe-index)
- [Preset Catalog](#preset-catalog)

---

## Helm Commands

### Basic Operations

```bash
# Install Spark 4.1
helm install spark charts/spark-4.1 -n spark --create-namespace

# Install Spark 3.5 Connect
helm install spark-connect charts/spark-3.5/charts/spark-connect -n spark

# Install Spark 3.5 Standalone
helm install spark-standalone charts/spark-3.5/charts/spark-standalone -n spark

# Upgrade release
helm upgrade spark charts/spark-4.1 -n spark

# Uninstall
helm uninstall spark -n spark

# Get values
helm get values spark -n spark
```

### Installation with Presets

```bash
# Spark 4.1
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark

# Spark 3.5
helm install spark-connect charts/spark-3.5/charts/spark-connect \
  -f charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml \
  -n spark
```

### Override Values

```bash
# Enable components
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set jupyter.enabled=true

# Configure resources
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.resources.requests.memory=2Gi \
  --set connect.resources.limits.memory=4Gi

# S3 configuration
helm upgrade spark charts/spark-4.1 -n spark \
  --set global.s3.endpoint=http://minio:9000 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin
```

### Validation

```bash
# Local validation (without installation)
helm template test charts/spark-4.1 -f values.yaml --dry-run

# Check presets
./scripts/validate-presets.sh

# Check security policies
./scripts/validate-policy.sh
```

### Debugging

```bash
# Show all values
helm show values charts/spark-4.1

# Render manifests to file
helm template spark charts/spark-4.1 -n spark > rendered.yaml

# Render with debug output
helm template spark charts/spark-4.1 -n spark --debug

# Release status
helm status spark -n spark

# Release history
helm history spark -n spark
```

---

## Component Management

### Spark Connect Server

```bash
# Enable/Disable
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.enabled=true

# Backend mode: k8s (dynamic executors)
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.backendMode=k8s

# Backend mode: standalone (fixed cluster)
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-sa-spark-standalone-master

# Backend mode: operator (Spark Operator)
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.backendMode=operator
```

### Spark Standalone

```bash
# Spark 3.5 - Master + Workers
helm install spark-standalone charts/spark-3.5/charts/spark-standalone \
  -n spark \
  --set sparkMaster.enabled=true \
  --set sparkWorker.replicas=3

# Spark 4.1 - via Connect
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set standalone.enabled=true
```

### History Server

```bash
# Enable
helm upgrade spark charts/spark-4.1 -n spark \
  --set historyServer.enabled=true

# Configure event log
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events
```

### Jupyter

```bash
# Enable
helm upgrade spark charts/spark-4.1 -n spark \
  --set jupyter.enabled=true

# Set Connect URL
helm upgrade spark charts/spark-4.1 -n spark \
  --set jupyter.env.SPARK_CONNECT_URL=sc://spark-connect:15002
```

---

## Troubleshooting

### Driver Not Starting

```bash
# Check driver logs
kubectl logs -n spark spark-driver-xxx -c spark-kubernetes-driver

# Describe driver pod
kubectl describe pod -n spark spark-driver-xxx

# Check events
kubectl get events -n spark --sort-by='.lastTimestamp'

# Diagnostic script
./scripts/recipes/troubleshoot/check-driver-logs.sh spark
```

### S3/MinIO Issues

```bash
# Test connection
./scripts/recipes/troubleshoot/test-s3-connection.sh spark

# Check secret
kubectl get secret -n spark s3-credentials -o yaml

# Test from pod
kubectl exec -n spark spark-connect-0 -- curl -sf http://minio:9000/minio/health/live
```

### Memory Issues (OOM)

```bash
# Find OOMKilled pods
./scripts/recipes/troubleshoot/check-executor-logs.sh spark

# Increase executor memory
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.sparkConf.'spark.executor.memory'=4g \
  --set connect.sparkConf.'spark.executor.memoryOverhead'=1g
```

### History Server Empty

```bash
# Check event log
kubectl exec -n spark spark-history-server-0 -- ls -la /spark-events

# Check configuration
kubectl logs -n spark spark-history-server-0

# See recipe
cat docs/recipes/troubleshoot/history-server-empty.md
```

### RBAC Issues

```bash
# Check permissions
./scripts/recipes/troubleshoot/check-rbac.sh spark spark

# Test can-i
kubectl auth can-i create pods -n spark \
  --as=system:serviceaccount:spark:spark
```

---

## Useful kubectl Commands

### Working with Pods

```bash
# List all Spark pods
kubectl get pods -n spark -l 'app in (spark-connect,spark-standalone)'

# Driver pods
kubectl get pods -n spark -l spark-role=driver

# Executor pods
kubectl get pods -n spark -l spark-role=executor

# Pods with errors
kubectl get pods -n spark | grep -E '(Error|CrashLoopBackOff|OOMKilled)'

# Logs (last 100 lines)
kubectl logs -n spark <pod> --tail=100

# Follow logs
kubectl logs -n spark <pod> -f

# All containers logs
kubectl logs -n spark <pod> --all-containers=true
```

### Port Forwarding

```bash
# Spark UI (driver on 4040)
kubectl port-forward -n spark <driver-pod> 4040:4040

# Spark Connect (15002)
kubectl port-forward -n spark svc/spark-connect 15002:15002

# Jupyter (8888)
kubectl port-forward -n spark svc/jupyter 8888:8888

# History Server (18080)
kubectl port-forward -n spark svc/spark-history-server 18080:18080

# MinIO Console (9001)
kubectl port-forward -n spark svc/minio 9001:9001
```

### Services and Endpoints

```bash
# All services
kubectl get svc -n spark

# Service endpoints
kubectl get endpoints -n spark spark-connect

# Ingress
kubectl get ingress -n spark
```

### Configuration

```bash
# ConfigMap
kubectl get cm -n spark spark-connect-configmap -o yaml

# Secrets
kubectl get secrets -n spark

# Show expanded ConfigMap
kubectl get cm -n spark spark-connect-configmap -o jsonpath='{.data.spark-defaults\.conf}' | jq -r .
```

---

## Environment Variables

### Spark Connect

| Variable | Description |
|----------|-------------|
| `SPARK_CONNECT_URL` | Spark Connect URL (sc://host:port) |
| `SPARK_REMOTE` | Alias for SPARK_CONNECT_URL |
| `SPARK_HOME` | Path to Spark |

### S3/MinIO

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |
| `SPARK_S3_ACCESS_KEY` | Spark S3 access key |
| `SPARK_S3_SECRET_KEY` | Spark S3 secret key |
| `SPARK_S3_ENDPOINT` | S3 endpoint URL |

### Hive Metastore

| Variable | Description |
|----------|-------------|
| `HIVE_METASTORE_URIS` | Metastore thrift URIs |
| `HIVE_METASTORE_WAREHOUSE_DIR` | Warehouse location |

---

## Recipe Index

### Operations (B)

| Recipe | Description |
|--------|-------------|
| [configure-event-log-prefix.md](../recipes/operations/configure-event-log-prefix.md) | Configure event log for MinIO |
| [enable-event-log-41.md](../recipes/operations/enable-event-log-41.md) | Event log for Spark 4.1 |
| [initialize-metastore.md](../recipes/operations/initialize-metastore.md) | Initialize Hive Metastore |

### Troubleshooting (D)

| Recipe | Description |
|--------|-------------|
| [s3-connection-failed.md](../recipes/troubleshoot/s3-connection-failed.md) | S3/MinIO connection issues |
| [history-server-empty.md](../recipes/troubleshoot/history-server-empty.md) | History Server shows no jobs |
| [properties-syntax.md](../recipes/troubleshoot/properties-syntax.md) | Spark properties syntax |
| [compression-library-missing.md](../recipes/troubleshoot/compression-library-missing.md) | Missing compression libraries |
| [driver-not-starting.md](../recipes/troubleshoot/driver-not-starting.md) | Driver not starting |
| [driver-host-resolution.md](../recipes/troubleshoot/driver-host-resolution.md) | Driver FQDN resolution |
| [helm-installation-label-validation.md](../recipes/troubleshoot/helm-installation-label-validation.md) | Helm "N/A" label validation error (ISSUE-030) |
| [s3-credentials-secret-missing.md](../recipes/troubleshoot/s3-credentials-secret-missing.md) | S3 credentials secret missing (ISSUE-031) |
| [connect-crashloop-rbac-configmap.md](../recipes/troubleshoot/connect-crashloop-rbac-configmap.md) | RBAC ConfigMaps permission (ISSUE-032/033) |
| [jupyter-python-dependencies-missing.md](../recipes/troubleshoot/jupyter-python-dependencies-missing.md) | Jupyter Python dependencies missing (ISSUE-034) |

### Deployment (A)

| Recipe | Description |
|--------|-------------|
| [deploy-spark-connect-new-team.md](../recipes/deployment/deploy-spark-connect-new-team.md) | Deploy for new team |
| [migrate-standalone-to-k8s.md](../recipes/deployment/migrate-standalone-to-k8s.md) | Migrate Standalone → K8s |
| [add-history-server-ha.md](../recipes/deployment/add-history-server-ha.md) | Setup History Server HA |
| [setup-resource-quotas.md](../recipes/deployment/setup-resource-quotas.md) | Configure resource quotas |

### Integration (C)

| Recipe | Description |
|--------|-------------|
| [airflow-spark-connect.md](../recipes/integration/airflow-spark-connect.md) | Airflow integration |
| [mlflow-spark-connect.md](../recipes/integration/mlflow-spark-connect.md) | MLflow experiments |
| [external-hive-metastore.md](../recipes/integration/external-hive-metastore.md) | External Metastore |
| [kerberos-authentication.md](../recipes/integration/kerberos-authentication.md) | Kerberos authentication |
| [prometheus-monitoring.md](../recipes/integration/prometheus-monitoring.md) | Prometheus monitoring |

---

## Preset Catalog

### Spark 4.1 Presets

| Preset | Description | Components |
|--------|-------------|------------|
| `values-scenario-jupyter-connect-k8s.yaml` | Jupyter + Connect + K8s backend | Connect, Jupyter |
| `values-scenario-jupyter-connect-standalone.yaml` | Jupyter + Connect + Standalone | Connect, Jupyter, Standalone |
| `values-scenario-airflow-connect-k8s.yaml` | Airflow + Connect + K8s backend | Connect, Airflow |
| `values-scenario-airflow-connect-standalone.yaml` | Airflow + Connect + Standalone | Connect, Airflow, Standalone |
| `values-scenario-airflow-k8s-submit.yaml` | Airflow + K8s submit mode | Airflow |
| `values-scenario-airflow-operator.yaml` | Airflow + Spark Operator | Airflow, Operator |

### Spark 3.5 Presets

#### Spark Connect

| Preset | Description | Components |
|--------|-------------|------------|
| `values-scenario-jupyter-connect-k8s.yaml` | Jupyter + Connect + K8s | Connect, Jupyter |
| `values-scenario-jupyter-connect-standalone.yaml` | Jupyter + Connect + Standalone | Connect, Jupyter, Standalone |

#### Spark Standalone

| Preset | Description | Components |
|--------|-------------|------------|
| `values-scenario-airflow-connect.yaml` | Airflow + Standalone | Standalone, Airflow |
| `values-scenario-airflow-k8s-submit.yaml` | Airflow + K8s submit | Airflow |
| `values-scenario-airflow-operator.yaml` | Airflow + Operator | Airflow |

---

## Quick Copy Commands

```bash
# Copy local script to pod
kubectl cp ./script.py spark-driver-xxx:/tmp/script.py -n spark

# Copy from pod
kubectl cp spark-driver-xxx:/tmp/output.csv ./output.csv -n spark

# Execute in pod
kubectl exec -n spark spark-connect-0 -- python -c "print('test')"

# Interactive shell
kubectl exec -n spark spark-connect-0 -it -- /bin/bash

# Edit ConfigMap in vi
kubectl edit cm -n spark spark-connect-configmap
```

---

## Useful Links

- [Full Guide](./spark-k8s-constructor.md)
- [Architecture](../architecture/spark-k8s-charts.md)
- [Spark Documentation](https://spark.apache.org/docs/latest/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
