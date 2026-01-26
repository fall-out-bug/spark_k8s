# Spark K8s Constructor: User Guide

**Date:** 2025-01-26
**Version:** 0.1.0
**Spark:** 3.5.7, 4.1.0

---

## Overview

The Spark K8s Constructor provides modular Helm charts for deploying Apache Spark on Kubernetes. Components can be combined like LEGO blocks to create optimal configurations for your team's needs.

**Two architectures:**
- **Spark 3.5:** Modular subcharts (spark-base, spark-connect, spark-standalone)
- **Spark 4.1:** Unified chart with toggle-flags

---

## Table of Contents

1. [LEGO Blocks](#lego-blocks)
2. [Quick Start](#quick-start)
3. [Preset Catalog](#preset-catalog)
4. [Using --set Flags](#using-set-flags)
5. [Operations Recipes](#operations-recipes)
6. [Troubleshooting Recipes](#troubleshooting-recipes)
7. [Deployment Recipes](#deployment-recipes)
8. [Integration Recipes](#integration-recipes)
9. [History Server](#history-server-complete-guide)

---

## LEGO Blocks

### Spark 3.5 (Modular Charts)

```
charts/spark-3.5/charts/
├── spark-base/          # Base image, shared configs
├── spark-connect/       # Spark Connect server
└── spark-standalone/    # Master/Workers + Airflow + MLflow
```

### Spark 4.1 (Unified Chart)

```
charts/spark-4.1/
├── templates/
│   ├── spark-connect.yaml
│   ├── hive-metastore.yaml
│   ├── history-server.yaml
│   ├── jupyter.yaml
│   └── ...
└── values.yaml          # All components in one file
```

### Components

| Component | Target Users | Purpose |
|-----------|--------------|---------|
| spark-connect | Data Scientists, Engineers | Interactive work, remote jobs |
| spark-standalone | Data Engineers | Batch processing, Airflow DAGs |
| hive-metastore | All | Table metadata warehouse |
| history-server | DataOps, Engineers | Job monitoring and metrics |
| jupyter | Data Scientists | Notebooks with remote Spark |
| airflow | Data Engineers | Pipeline orchestration |
| mlflow | Data Scientists | Experiment tracking |
| minio | Dev/Test | S3-compatible storage |

---

## Quick Start

### Scenario: Deploy Spark Connect for Data Science team

**Step 1: Choose your chart**

```bash
# For Spark 3.5
cd charts/spark-3.5/charts/spark-connect

# For Spark 4.1
cd charts/spark-4.1
```

**Step 2: Copy preset**

```bash
# Spark 3.5
cp values.yaml values-datascience-dev.yaml

# Spark 4.1
cp values.yaml values-datascience-dev.yaml
```

**Step 3: Customize for your team**

```yaml
# values-datascience-dev.yaml
connect:
  enabled: true
  replicas: 1
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2"

hiveMetastore:
  enabled: true

jupyter:
  enabled: true
  env:
    SPARK_CONNECT_URL: "sc://spark-connect:15002"

historyServer:
  enabled: true
```

**Step 4: Validate**

```bash
helm template spark-datascience . -f values-datascience-dev.yaml --dry-run
```

**Step 5: Deploy**

```bash
helm install spark-datascience . -f values-datascience-dev.yaml --namespace datascience
```

**Step 6: Verify**

```bash
# Check pods
kubectl get pods -n datascience

# Check Spark Connect
kubectl exec -n datascience deploy/spark-connect -- /opt/spark/bin/spark-submit --help

# Open Jupyter
kubectl port-forward -n datascience svc/jupyter 8888:8888
```

---

## Preset Catalog

### Production-Ready Presets

| Preset | File | Version | Size | Components |
|--------|------|--------|------|------------|
| Jupyter + Connect (K8s) | `values-scenario-jupyter-connect-k8s.yaml` | 4.1 | Small | Connect + Jupyter + MinIO |
| Jupyter + Connect (Standalone) | `values-scenario-jupyter-connect-standalone.yaml` | 4.1 | Medium | Connect + Jupyter + Standalone + MinIO |
| Airflow + Connect (K8s) | `values-scenario-airflow-connect-k8s.yaml` | 4.1 | Medium | Airflow + Connect + MinIO |
| Airflow + Connect (Standalone) | `values-scenario-airflow-connect-standalone.yaml` | 4.1 | Medium | Airflow + Connect + Standalone + MinIO |
| Airflow + K8s Submit | `values-scenario-airflow-k8s-submit.yaml` | 4.1 | Small | Airflow + MinIO |
| Airflow + Spark Operator | `values-scenario-airflow-operator.yaml` | 4.1 | Medium | Airflow + Spark Operator + MinIO |
| Jupyter + Connect (K8s) | `values-scenario-jupyter-connect-k8s.yaml` | 3.5 | Small | Connect + Jupyter + MinIO |
| Jupyter + Connect (Standalone) | `values-scenario-jupyter-connect-standalone.yaml` | 3.5 | Medium | Connect + Jupyter + Standalone + MinIO |
| Airflow + Connect | `values-scenario-airflow-connect.yaml` | 3.5 | Medium | Airflow + Connect + MinIO |
| Airflow + K8s Submit | `values-scenario-airflow-k8s-submit.yaml` | 3.5 | Small | Airflow + MinIO |
| Airflow + Operator | `values-scenario-airflow-operator.yaml` | 3.5 | Medium | Airflow + Spark Operator + MinIO |

### Using Presets

**Spark 4.1:**
```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace
```

**Spark 3.5:**
```bash
helm install spark-connect charts/spark-3.5/charts/spark-connect \
  -f charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace
```

---

## Using --set Flags

### Pattern: Test scripts as reference

**Step 1: Find your test scenario**

```bash
# Data Science: Jupyter + Connect
scripts/test-e2e-jupyter-connect.sh

# Data Engineering: Airflow + Connect
scripts/test-e2e-airflow-connect.sh

# Data Engineering: Airflow + K8s submit
scripts/test-e2e-airflow-k8s-submit.sh

# Data Engineering: Airflow + Spark Operator
scripts/test-e2e-airflow-operator.sh
```

**Step 2: Extract helm command**

From the test script, find the `helm upgrade` command:

```bash
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n "${NAMESPACE}" \
  --set sparkConnect.enabled=true \
  --set sparkConnect.backendMode=k8s \
  --set sparkConnect.driver.host="${CONNECT_SERVICE_NAME}.${NAMESPACE}.svc.cluster.local" \
  --set jupyter.enabled=true \
  ...
```

**Step 3: Adapt for your use case**

```bash
# Change namespace
--set sparkConnect.driver.host="spark-connect.prod.svc.cluster.local"

# Add S3 configuration
--set global.s3.endpoint="https://s3.amazonaws.com"
```

---

## Operations Recipes

See [docs/recipes/operations](../recipes/operations/):

- **Configure Event Log for MinIO** - Set up event log storage
- **Enable Event Log (Spark 4.1)** - Configure event logging
- **Initialize Hive Metastore** - Set up metadata warehouse

**Quick Links:**
- [Configure Event Log Prefix](../recipes/operations/configure-event-log-prefix.md)
- [Enable Event Log 4.1](../recipes/operations/enable-event-log-41.md)
- [Initialize Metastore](../recipes/operations/initialize-metastore.md)

---

## Troubleshooting Recipes

See [docs/recipes/troubleshoot](../recipes/troubleshoot/):

### Common Issues

1. **S3 Connection Failed** - Diagnose S3/MinIO connectivity
2. **History Server Empty** - Jobs not showing up
3. **Spark Properties Syntax** - Configuration format issues
4. **Zstandard Library Missing** - Compression library not found
5. **Driver Not Starting** - Connection problems
6. **Driver Host Resolution** - FQDN resolution issues

### Installation Issues

7. **Helm Installation Label Validation** - "N/A" label error (ISSUE-030)
8. **S3 Credentials Secret Missing** - Auto-creation (ISSUE-031)

### Runtime Issues

9. **Connect CrashLoop (RBAC)** - ConfigMaps permission (ISSUE-032/033)
10. **Jupyter Python Dependencies** - grpcio/grpcio-status/zstandard missing (ISSUE-034)

**Diagnostic Scripts:**
```bash
# Check RBAC
scripts/recipes/troubleshoot/check-rbac.sh spark spark

# Check driver logs
scripts/recipes/troubleshoot/check-driver-logs.sh spark

# Test S3 connection
scripts/recipes/troubleshoot/test-s3-connection.sh spark

# Analyze Spark UI
scripts/recipes/troubleshoot/analyze-spark-ui.sh spark <driver-pod>
```

---

## Deployment Recipes

See [docs/recipes/deployment](../recipes/deployment/):

1. **Deploy Spark Connect for New Team** - Onboarding setup
2. **Migrate Standalone to K8s** - Backend migration guide
3. **Add History Server HA** - High availability setup
4. **Setup Resource Quotas** - Resource management

---

## Integration Recipes

See [docs/recipes/integration](../recipes/integration):

1. **Airflow + Spark Connect** - DAG examples and configuration
2. **MLflow Experiment Tracking** - ML workflow integration
3. **External Hive Metastore** - AWS Glue, EMR, HDInsight integration
4. **Kerberos Authentication** - Security setup
5. **Prometheus Monitoring** - Metrics collection and dashboards

---

## History Server: Complete Guide

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Spark Application                      │
│  ├─ Event Log (s3a://spark-logs/4.1/events/*.eventlog)    │
│  └─ Logs written to: /opt/spark/events                          │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              History Server (Stateless)                   │
│  ├─ Polls MinIO for new logs                                  │
│  ├─ Parses event log files                                    │
│  └─ Serves UI at http://localhost:18080                    │
└─────────────────────────────────────────────────────────┘
```

### Configuration

```yaml
historyServer:
  enabled: true

# Event log configuration (on Spark side)
connect:
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/4.1/events"
    compress: true
```

### Quick Start

**Step 1: Enable History Server**
```bash
helm upgrade spark charts/spark-4.1 -n spark \
  --set historyServer.enabled=true \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events
```

**Step 2: Access UI**
```bash
# Port forward
kubectl port-forward -n spark svc/spark-4-1-spark-41-history-server 18080:18080

# Open browser
open http://localhost:18080
```

**Step 3: Verify**
```bash
# Check History Server pod
kubectl get pods -n spark -l app.kubernetes.io/component=history-server

# Check logs
kubectl logs -n spark -l app.kubernetes.io/component=history-server
```

### Features

- **Incomplete Applications**: Shows apps that haven't finished
- **SQL Tab**: Run SQL queries on event logs
- **Metrics Tab**: JVM metrics, Shuffle Read/Write metrics
- **Executor Timeline**: Visualize executor lifecycle
- **Download Logs**: Download event logs locally

---

## Advanced Topics

### Backend Modes

**K8s (Default):** Dynamic executors via Kubernetes API
```yaml
connect:
  backendMode: k8s
  sparkConf:
    spark.executor.instances: "3"
    spark.dynamicAllocation.enabled: "true"
```

**Standalone:** Fixed cluster (master/workers)
```yaml
connect:
  backendMode: standalone
  standalone:
    masterService: "spark-sa-spark-standalone-master"
  sparkConf:
    spark.executor.instances: "1"
    spark.dynamicAllocation.enabled: "false"
```

**Operator:** Spark Operator CRD-based
```yaml
connect:
  backendMode: operator
```

### S3 Configuration

```yaml
global:
  s3:
    endpoint: "http://minio:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin"

# Or use existing secret
spark-base:
  s3:
    existingSecret: "my-s3-credentials"
```

### Resource Management

```yaml
connect:
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2"
```

---

## Validation

### Preset Validation
```bash
./scripts/validate-presets.sh
```

### Policy Validation
```bash
./scripts/validate-policy.sh
```

### Linting
```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/values-scenario-*.yaml --dry-run
```

---

## Support

| Resource | Link |
|----------|------|
| **Issues** | [docs/issues/](../issues/) |
| **Architecture** | [Architecture](../architecture/spark-k8s-charts.md) |
| **Quick Reference** | [Quick Reference](../guides/ru/quick-reference.md) |
| **Repository Map** | [Project Map](../PROJECT_MAP.md) |

---

**Version:** 0.1.0
**Last Updated:** 2025-01-26
**Spark Versions:** 3.5.7, 4.1.0
