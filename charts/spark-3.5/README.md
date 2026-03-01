# Apache Spark 3.5 on Kubernetes

[![Spark Version](https://img.shields.io/badge/Spark-3.5.7%20%7%203.5.8-orange)](https://spark.apache.org/)
[![Helm](https://img.shields.io/badge/Helm-3.x-blue)](https://helm.sh)

Modular Helm chart for deploying Apache Spark 3.5.7/3.5.8 on Kubernetes with support for Spark Connect, GPU acceleration (RAPIDS), and Apache Iceberg.

---

## Quick Start

### Core Components (Minimal Lakehouse Stack)

Deploy all core infrastructure components with a single command:

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-baseline.yaml
```

This enables:
- MinIO (S3-compatible storage)
- PostgreSQL (database)
- Hive Metastore (metadata catalog)
- History Server (job history UI)

### With GPU Support

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-gpu.yaml
```

### With Iceberg Support

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-iceberg.yaml
```

### With GPU + Iceberg

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-gpu-iceberg.yaml
```

### Jupyter + Spark Connect (K8s Backend)

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/jupyter-connect-k8s-3.5.8.yaml
```

### Jupyter + Spark Connect (Standalone Backend)

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/jupyter-connect-standalone-3.5.8.yaml
```

### Airflow + Spark Connect + GPU

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/airflow-gpu-connect-k8s-3.5.8.yaml
```

### Airflow + Spark Connect + Iceberg

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/airflow-iceberg-connect-k8s-3.5.8.yaml
```

---

## Core Components

The chart provides unified configuration for core infrastructure components under the `core:` section.

### Architecture Overview

```
┌─────────────────┐
│  Spark Connect  │
└────────┬────────┘
         │
┌────────▼─────────────────────────────────┐
│         Core Infrastructure              │
├──────────────┬──────────────┬────────────┤
│    MinIO     │  PostgreSQL  │   Hive     │
│  (S3 Store)  │ (Metastore) │  Metastore │
└──────────────┴──────────────┴────────────┘
         │
┌────────▼────────┐
│ History Server  │
└─────────────────┘
```

### Component Interaction

1. **Spark Connect** submits jobs to Kubernetes
2. **MinIO** stores event logs, warehouse data, and checkpoints
3. **PostgreSQL** persists Hive Metastore catalog
4. **Hive Metastore** manages table metadata for Spark SQL
5. **History Server** reads event logs from MinIO for UI display

### MinIO (S3-compatible Storage)

Stores event logs, warehouse data, and checkpoints.

```yaml
core:
  minio:
    enabled: true
    fullnameOverride: "minio-spark-35"
    buckets:
      - warehouse          # Lakehouse warehouse
      - spark-logs         # Spark event logs
      - spark-jobs         # Job artifacts
      - raw-data           # Raw input data
      - processed-data     # Processed output
      - checkpoints        # Streaming checkpoints
```

**Access credentials:**
- Default console: `http://minio-spark-35:9001`
- Default API: `http://minio-spark-35:9000`
- Default access key: `minioadmin`
- Default secret key: `minioadmin`

**S3 Configuration in Spark:**
```bash
spark.sparkContext.hadoopConfiguration.set("fs.s3a.endpoint", "http://minio-spark-35:9000")
spark.sparkContext.hadoopConfiguration.set("fs.s3a.access.key", "minioadmin")
spark.sparkContext.hadoopConfiguration.set("fs.s3a.secret.key", "minioadmin")
spark.sparkContext.hadoopConfiguration.set("fs.s3a.path.style.access", "true")
```

### PostgreSQL (Database)

Backend database for Hive Metastore.

```yaml
core:
  postgresql:
    enabled: true
    fullnameOverride: "postgresql-metastore-35"
    auth:
      username: hive
      password: "hive123"
      database: metastore
```

**Connection string:**
```
jdbc:postgresql://postgresql-metastore-35:5432/metastore
```

### Hive Metastore

Centralized metadata catalog for Spark SQL and Lakehouse operations.

```yaml
core:
  hiveMetastore:
    enabled: true
    fullnameOverride: "hive-metastore-35"
    warehouseDir: "s3a://warehouse/spark-35"
```

**Key features:**
- Table metadata management
- Partition discovery
- Schema enforcement
- ACID transaction support (with Iceberg)

### History Server

Web UI for viewing completed Spark application history.

```yaml
core:
  historyServer:
    enabled: true
    fullnameOverride: "history-server-35"
    eventLogDir: "s3a://spark-logs/"
```

**Access UI:**
```bash
kubectl port-forward service/history-server-35 18080:18080
# Open http://localhost:18080
```

---

## Features

### GPU Support (RAPIDS Accelerator)

Enable NVIDIA RAPIDS plugin for GPU-accelerated Spark operations.

**Requirements:**
- Kubernetes nodes with NVIDIA GPUs
- NVIDIA Device Plugin installed
- CUDA 12.0 compatible drivers

**Configuration:**
```yaml
features:
  gpu:
    enabled: true
    cudaVersion: "12.0"
    nvidiaVisibleDevices: "all"
    taskResourceAmount: "0.25"  # Fraction of GPU per task
    rapids:
      plugins: "com.nvidia.spark.SQLPlugin"
      sql:
        enabled: true
        python:
          enabled: true
        fallback:

## Monitoring & Alerting (Phase 2)

Comprehensive monitoring with Grafana dashboards and Prometheus alerts:
- **Grafana Dashboards:** Executor metrics, Job performance, Streaming metrics, ML training metrics
- **Prometheus Alerts:** Executor OOM, High GC, Consumer lag

## Examples Catalog

Production-ready examples for Apache Spark on Kubernetes:

### Batch Processing
- `etl_pipeline.py` - Complete ETL pipeline (Extract, Transform, Load) - `data_quality.py` - Data quality validation framework

### Machine Learning
- `classification_catboost.py` - Binary classification with CatBoost/MLlib
- `regression_spark_ml.py` - Regression with Spark MLlib

### Streaming
- `file_stream_basic.py` - Rate source, windowed aggregations
- `kafka_stream_backpressure.py` - Kafka streaming with backpressure
- `kafka_exactly_once.py` - Exactly-once semantics

## Cloud Provider Presets
- `aws.yaml` - AWS S3 with IAM Roles (IRSA)
- `azure.yaml` - Azure Blob/ADLS with Managed Identity
- `gcp.yaml` - GCS with Workload Identity

## Integration Presets
- `kafka-external.yaml` - External Kafka cluster (no operators)

## Helper Scripts
- `spark-submit.sh` - Simplified job submission with presets
- `collect-metrics.sh` - Export metrics to Prometheus PushGateway
- `monitor-resources.sh` - Cluster resource monitoring
- `test-examples.sh` - Validation test suite


          enabled: true  # Fall back to CPU if GPU fails
      memory:
        allocFraction: "0.8"
        maxAllocFraction: "0.9"
        minAllocFraction: "0.3"
      shuffle:
        enabled: true
      format:
        parquet:
          read: true
          write: true
        orc:
          read: true
        csv:
          read: true
        json:
          read: true
```

**Verifying GPU:**
```python
# In PySpark
spark.conf.get("spark.rapids.sql.enabled")
# Should return 'true'

spark.conf.get("spark.task.resource.gpu.amount")
# Should return '0.25'
```

### Iceberg Support (Lakehouse Tables)

Enable Apache Iceberg for ACID transactions, time travel, and schema evolution.

**Catalog Types:**

1. **Hadoop Catalog** (default, recommended for S3):
```yaml
features:
  iceberg:
    enabled: true
    catalogType: "hadoop"
    warehouse: "s3a://warehouse/iceberg"
    ioImpl: "org.apache.iceberg.hadoop.HadoopFileIO"
```

2. **Hive Catalog** (requires Hive Metastore):
```yaml
features:
  iceberg:
    enabled: true
    catalogType: "hive"
    warehouse: "s3a://warehouse/iceberg"
    uri: "thrift://hive-metastore-35:9083"
```

**Creating Iceberg Tables:**
```python
# Using Hadoop catalog
spark.sql("""
CREATE TABLE my_table (
  id LONG,
  name STRING
)
USING iceberg
LOCATION 's3a://warehouse/iceberg/my_table'
""")

# Using Hive catalog
spark.sql("""
CREATE TABLE my_catalog.my_db.my_table (
  id LONG,
  name STRING
)
USING iceberg
""")
```

**Additional buckets for Iceberg:**
```yaml
core:
  minio:
    buckets:
      - warehouse
      - spark-logs
      - iceberg-metadata  # Iceberg metadata files
```

---

## Presets

Pre-configured values files for common scenarios.

### Base Presets

| Preset | Description | Features |
|--------|-------------|----------|
| `core-baseline` | Core Components only | MinIO, PostgreSQL, Hive Metastore, History Server |
| `core-gpu` | Core + GPU | All core components + RAPIDS GPU acceleration |
| `core-iceberg` | Core + Iceberg | All core components + Apache Iceberg Lakehouse |
| `core-gpu-iceberg` | Core + GPU + Iceberg | All components + GPU + Iceberg |

**Usage:**
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-baseline.yaml
```

### Scenario Presets

| Scenario | File | Backend | Features |
|----------|------|---------|----------|
| Jupyter + Connect | `jupyter-connect-k8s-3.5.8.yaml` | Kubernetes | JupyterLab + Spark Connect |
| Jupyter + Connect | `jupyter-connect-standalone-3.5.8.yaml` | Standalone | JupyterLab + Spark Standalone |
| Airflow + Connect + GPU | `airflow-gpu-connect-k8s-3.5.8.yaml` | Kubernetes | Airflow + GPU + Connect |
| Airflow + Connect + Iceberg | `airflow-iceberg-connect-k8s-3.5.8.yaml` | Kubernetes | Airflow + Iceberg + Connect |
| Airflow + Connect | `airflow-connect-k8s-3.5.8.yaml` | Kubernetes | Airflow + Connect |

**Usage:**
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/jupyter-connect-k8s-3.5.8.yaml
```

### Custom Values

Override specific values:
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-baseline.yaml \
  --set core.minio.persistence.size=100Gi \
  --set core.historyServer.resources.requests.memory=2Gi
```

---

## Configuration Reference

### Global Settings

```yaml
global:
  imagePullSecrets: []
  s3:
    endpoint: "http://minio:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
    pathStyleAccess: true
    sslEnabled: false
    existingSecret: "s3-credentials"
  postgresql:
    host: "postgresql-metastore-35"
    port: 5432
    user: "hive"
    password: "hive123"
```

### RBAC

```yaml
rbac:
  create: true
  serviceAccountName: "spark-35"
```

### Spark Connect

```yaml
connect:
  enabled: false
  replicas: 1
  image:
    repository: "apache/spark"
    tag: "3.5.8"
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"
```

### Jupyter

```yaml
jupyter:
  enabled: false
  replicas: 1
  image:
    repository: "jupyter/scipy-notebook"
    tag: "latest"
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
```

### Airflow

```yaml
airflow:
  enabled: false
  replicas: 1
  image:
    repository: "apache/airflow"
    tag: "2.8.0-python3.10"
```

See [values.yaml](values.yaml) for complete configuration reference.

---

## Troubleshooting

### Common Issues

#### 1. Pods stuck in Pending state

**Check resource requests:**
```bash
kubectl describe pod <pod-name>
```

**Solution:** Increase resource limits or add more nodes to the cluster.

#### 2. History Server shows no applications

**Check event logs:**
```bash
kubectl exec -it deployment/history-server-35 -- ls -la /spark-events
```

**Solution:** Verify MinIO is accessible and event logs are being written:
```bash
kubectl exec -it deployment/minio-spark-35 -- mc ls minio/spark-logs
```

#### 3. GPU tasks not running

**Check GPU availability:**
```bash
kubectl describe node <node-name> | grep nvidia.com/gpu
```

**Verify RAPIDS configuration:**
```bash
kubectl logs deployment/spark-connect-35 | grep rapids
```

#### 4. Hive Metastore connection failed

**Check database:**
```bash
kubectl exec -it deployment/postgresql-metastore-35 -- psql -U hive -d metastore
```

**Verify Metastore logs:**
```bash
kubectl logs deployment/hive-metastore-35
```

#### 5. Iceberg table creation failed

**Check S3 access:**
```python
spark.sparkContext.hadoopConfiguration.set("fs.s3a.access.key", "minioadmin")
spark.sparkContext.hadoopConfiguration.set("fs.s3a.secret.key", "minioadmin")
```

**Verify warehouse location:**
```bash
kubectl exec -it deployment/minio-spark-35 -- mc ls minio/warehouse
```

### Debug Mode

Enable debug logging:
```yaml
connect:
  sparkConf:
    "spark.executor.extraJavaOptions": "-Dlog4j.debug=true"
    "spark.driver.extraJavaOptions": "-Dlog4j.debug=true"
```

### Port Forwarding

Access services locally:
```bash
# Spark Connect
kubectl port-forward service/spark-connect-35 15002:15002

# History Server
kubectl port-forward service/history-server-35 18080:18080

# MinIO Console
kubectl port-forward service/minio-spark-35-console 9001:9001

# Jupyter
kubectl port-forward service/jupyter-35 8888:8888
```

---

## Upgrading

```bash
helm upgrade my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-baseline.yaml
```

**Warning:** Back up your data before upgrading:
```bash
kubectl exec -it deployment/minio-spark-35 -- mc mirror minio/ /backup/
```

---

## Uninstalling

```bash
helm uninstall my-spark
```

**Note:** PVCs are not deleted by default. Delete manually:
```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-spark
```

---

## See Also

- [Main README](../../README.md) - Project overview
- [Usage Guide](../../docs/guides/en/spark-k8s-constructor.md) - Complete user guide
- [Quick Reference](../../docs/guides/en/quick-reference.md) - Command cheat sheet
- [Architecture](../../docs/architecture/spark-k8s-charts.md) - System architecture

---

**Chart Version:** 0.1.0
**Spark Version:** 3.5.7 | 3.5.8
**Application Version:** 3.5.7 | 3.5.8
