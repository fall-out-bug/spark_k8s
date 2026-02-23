# Apache Spark 4.1 on Kubernetes

[![Spark Version](https://img.shields.io/badge/Spark-4.1.0-orange)](https://spark.apache.org/)
[![Helm](https://img.shields.io/badge/Helm-3.x-blue)](https://helm.sh)

Unified Helm chart for deploying Apache Spark 4.1.0 on Kubernetes with support for Spark Connect, GPU acceleration (RAPIDS), Apache Iceberg, Jupyter, and Airflow.

---

## Quick Start

### Core Components (Minimal Lakehouse Stack)

Deploy all core infrastructure components with a single command:

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-baseline.yaml
```

This enables:
- MinIO (S3-compatible storage)
- PostgreSQL (database)
- Hive Metastore (metadata catalog)
- History Server (job history UI)

### With GPU Support

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-gpu.yaml
```

### With Iceberg Support

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-iceberg.yaml
```

### With GPU + Iceberg

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-gpu-iceberg.yaml
```

### Jupyter + Spark Connect (K8s Backend)

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml
```

### Jupyter + Spark Connect (Standalone Backend)

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-standalone.yaml
```

### Airflow + Spark Connect (K8s Backend)

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml
```

### Airflow + Spark Connect (Standalone Backend)

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-airflow-connect-standalone.yaml
```

### Airflow + K8s Submit

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-airflow-k8s-submit.yaml
```

### Airflow + Spark Operator

```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-airflow-operator.yaml
```

---

## Core Components

The chart provides unified configuration for core infrastructure components under the `core:` section.

### Architecture Overview

```
┌─────────────────┐      ┌──────────┐
│  Spark Connect  │      │ Jupyter  │
└────────┬────────┘      └────┬─────┘
         │                    │
┌────────▼─────────────────────────────────┐
│         Core Infrastructure              │
├──────────────┬──────────────┬────────────┤
│    MinIO     │  PostgreSQL  │   Hive     │
│  (S3 Store)  │ (Metastore) │  Metastore │
└──────────────┴──────────────┴────────────┘
         │
┌────────▼────────┐      ┌──────────┐
│ History Server  │      │ Airflow  │
└─────────────────┘      └──────────┘
```

### Component Interaction

1. **Spark Connect** submits jobs to Kubernetes
2. **Jupyter** provides interactive notebook interface
3. **MinIO** stores event logs, warehouse data, and checkpoints
4. **PostgreSQL** persists Hive Metastore catalog
5. **Hive Metastore** manages table metadata for Spark SQL
6. **History Server** reads event logs from MinIO for UI display
7. **Airflow** orchestrates Spark job workflows

### MinIO (S3-compatible Storage)

Stores event logs, warehouse data, and checkpoints.

```yaml
core:
  minio:
    enabled: true
    fullnameOverride: "minio-spark-41"
    buckets:
      - warehouse          # Lakehouse warehouse
      - spark-logs         # Spark event logs
      - spark-jobs         # Job artifacts
      - raw-data           # Raw input data
      - processed-data     # Processed output
      - checkpoints        # Streaming checkpoints
```

**Access credentials:**
- Default console: `http://minio-spark-41:9001`
- Default API: `http://minio-spark-41:9000`
- Default access key: `minioadmin`
- Default secret key: `minioadmin`

**S3 Configuration in Spark:**
```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio-spark-41:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .getOrCreate()
```

### PostgreSQL (Database)

Backend database for Hive Metastore.

```yaml
core:
  postgresql:
    enabled: true
    fullnameOverride: "postgresql-metastore-41"
    auth:
      username: hive
      password: "hive123"
      database: metastore
```

**Connection string:**
```
jdbc:postgresql://postgresql-metastore-41:5432/metastore
```

### Hive Metastore

Centralized metadata catalog for Spark SQL and Lakehouse operations.

```yaml
core:
  hiveMetastore:
    enabled: true
    fullnameOverride: "hive-metastore-41"
    warehouseDir: "s3a://warehouse/spark-41"
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
    fullnameOverride: "history-server-41"
    eventLogDir: "s3a://spark-logs/"
```

**Access UI:**
```bash
kubectl port-forward service/history-server-41 18080:18080
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
    uri: "thrift://hive-metastore-41:9083"
```

3. **REST Catalog** (new in Spark 4.1):
```yaml
features:
  iceberg:
    enabled: true
    catalogType: "rest"
    warehouse: "s3a://warehouse/iceberg"
    uri: "http://iceberg-rest-catalog:8181"
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

# Using REST catalog (Spark 4.1+)
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
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-baseline.yaml
```

### Scenario Presets

| Scenario | File | Backend | Features |
|----------|------|---------|----------|
| Jupyter + Connect | `values-scenario-jupyter-connect-k8s.yaml` | Kubernetes | JupyterLab + Spark Connect |
| Jupyter + Connect | `values-scenario-jupyter-connect-standalone.yaml` | Standalone | JupyterLab + Spark Standalone |
| Airflow + Connect | `values-scenario-airflow-connect-k8s.yaml` | Kubernetes | Airflow + Connect |
| Airflow + Connect | `values-scenario-airflow-connect-standalone.yaml` | Standalone | Airflow + Standalone |
| Airflow + K8s Submit | `values-scenario-airflow-k8s-submit.yaml` | Kubernetes | Airflow + K8s Submit |
| Airflow + Operator | `values-scenario-airflow-operator.yaml` | Operator | Airflow + Spark Operator |
| Airflow + GPU + Connect | `values-scenario-airflow-gpu-connect-k8s.yaml` | Kubernetes | Airflow + GPU + Connect |
| Airflow + Iceberg + Connect | `values-scenario-airflow-iceberg-connect-k8s.yaml` | Kubernetes | Airflow + Iceberg + Connect |

**Usage:**
```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml
```

### Custom Values

Override specific values:
```bash
helm install my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-baseline.yaml \
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
    host: "postgresql-metastore-41"
    port: 5432
    user: "hive"
    password: "hive123"
```

### RBAC

```yaml
rbac:
  create: true
  serviceAccountName: "spark-41"
```

### Spark Connect

```yaml
connect:
  enabled: false
  replicas: 1
  image:
    repository: "apache/spark"
    tag: "4.1.0"
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

## Migration from Spark 3.5

Migrating from Spark 3.5 to Spark 4.1 requires several changes due to API updates and new features.

### Key Differences

| Feature | Spark 3.5 | Spark 4.1 |
|---------|-----------|-----------|
| Python API | `pyspark` | `pyspark` (updated) |
| Connect Client | `spark://` | `sc://` (recommended) |
| Catalog API | `spark.catalog` | `spark.catalog` (enhanced) |
| Iceberg | 1.4.x | 1.5+ (with REST catalog) |
| GPU Support | RAPIDS 23.x | RAPIDS 24.x |

### Migration Steps

#### 1. Update Image Tags

```yaml
# Before (Spark 3.5)
connect:
  image:
    tag: "3.5.8"

# After (Spark 4.1)
connect:
  image:
    tag: "4.1.0"
```

#### 2. Update Connect Client URL

```python
# Before (Spark 3.5)
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .remote("spark://spark-connect-35:15002") \
    .getOrCreate()

# After (Spark 4.1)
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .remote("sc://spark-connect-41:15002") \
    .getOrCreate()
```

#### 3. Update Service Names

```yaml
# Before
fullnameOverride: "spark-connect-35"

# After
fullnameOverride: "spark-connect-41"
```

#### 4. Update RBAC Service Account

```yaml
# Before
rbac:
  serviceAccountName: "spark-35"

# After
rbac:
  serviceAccountName: "spark-41"
```

#### 5. Update Warehouse Directory (optional but recommended)

```yaml
# Before
warehouseDir: "s3a://warehouse/spark-35"

# After
warehouseDir: "s3a://warehouse/spark-41"
```

#### 6. Update GPU Configuration

```yaml
# Spark 3.5
features:
  gpu:
    rapids:
      plugins: "com.nvidia.spark.SQLPlugin"
      sql:
        enabled: true

# Spark 4.1 (additional shuffle options)
features:
  gpu:
    rapids:
      plugins: "com.nvidia.spark.SQLPlugin,com.nvidia.spark.ShufflePlugin"
      sql:
        enabled: true
      shuffle:
        enabled: true  # New in 4.1
```

#### 7. Update Iceberg REST Catalog (optional, new in 4.1)

```yaml
# Spark 3.5 (Hadoop or Hive catalog only)
features:
  iceberg:
    catalogType: "hadoop"

# Spark 4.1 (can use REST catalog)
features:
  iceberg:
    catalogType: "rest"
    uri: "http://iceberg-rest-catalog:8181"
```

### Data Migration

Data stored in MinIO and PostgreSQL is compatible between versions. However, you should:

1. **Backup existing data:**
```bash
kubectl exec -it deployment/minio-spark-35 -- mc mirror minio/ /backup/
kubectl exec -it deployment/postgresql-metastore-35 -- pg_dump metastore > metastore_backup.sql
```

2. **Migrate warehouse data (if changing paths):**
```bash
# Copy data from old to new location
kubectl exec -it deployment/minio-spark-41 -- mc cp --recursive minio/warehouse/spark-35/ minio/warehouse/spark-41/
```

3. **Update Hive Metastore pointers:**
```sql
-- In PostgreSQL
UPDATE DBS
SET DB_LOCATION_URI = REPLACE(DB_LOCATION_URI, 'spark-35', 'spark-41')
WHERE DB_LOCATION_URI LIKE '%spark-35%';

UPDATE SDS
SET LOCATION = REPLACE(LOCATION, 'spark-35', 'spark-41')
WHERE LOCATION LIKE '%spark-35%';
```

### Rollback Plan

If migration fails, rollback to Spark 3.5:

```bash
# Uninstall Spark 4.1
helm uninstall my-spark

# Restore from backup
kubectl exec -it deployment/minio-spark-35 -- mc mirror /backup/ minio/

# Reinstall Spark 3.5
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-baseline.yaml
```

### Testing Migration

Test the migration in a development environment first:

```bash
# Install Spark 4.1 in test namespace
helm install spark-test charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-baseline.yaml \
  --namespace test

# Run test jobs
kubectl exec -it deployment/spark-test-connect -- spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode client \
  /path/to/test_job.py

# Verify results
kubectl exec -it deployment/spark-test-connect -- spark-sql \
  -e "SELECT * FROM test_table LIMIT 10"
```

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
kubectl exec -it deployment/history-server-41 -- ls -la /spark-events
```

**Solution:** Verify MinIO is accessible and event logs are being written:
```bash
kubectl exec -it deployment/minio-spark-41 -- mc ls minio/spark-logs
```

#### 3. GPU tasks not running

**Check GPU availability:**
```bash
kubectl describe node <node-name> | grep nvidia.com/gpu
```

**Verify RAPIDS configuration:**
```bash
kubectl logs deployment/spark-connect-41 | grep rapids
```

#### 4. Hive Metastore connection failed

**Check database:**
```bash
kubectl exec -it deployment/postgresql-metastore-41 -- psql -U hive -d metastore
```

**Verify Metastore logs:**
```bash
kubectl logs deployment/hive-metastore-41
```

#### 5. Iceberg table creation failed

**Check S3 access:**
```python
spark.sparkContext.hadoopConfiguration.set("fs.s3a.access.key", "minioadmin")
spark.sparkContext.hadoopConfiguration.set("fs.s3a.secret.key", "minioadmin")
```

**Verify warehouse location:**
```bash
kubectl exec -it deployment/minio-spark-41 -- mc ls minio/warehouse
```

#### 6. Migration issues from 3.5

**Check compatibility:**
```bash
# Verify Spark version
kubectl exec -it deployment/spark-connect-41 -- spark-submit --version

# Check Connect client compatibility
python -c "from pyspark.sql import SparkSession; print(SparkSession.version)"
```

**Solution:** Use backward-compatible APIs and gradual migration strategy.

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
kubectl port-forward service/spark-connect-41 15002:15002

# History Server
kubectl port-forward service/history-server-41 18080:18080

# MinIO Console
kubectl port-forward service/minio-spark-41-console 9001:9001

# Jupyter
kubectl port-forward service/jupyter-41 8888:8888

# Airflow Web UI
kubectl port-forward service/airflow-41-web 8080:8080
```

---

## Upgrading

```bash
helm upgrade my-spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-baseline.yaml
```

**Warning:** Back up your data before upgrading:
```bash
kubectl exec -it deployment/minio-spark-41 -- mc mirror minio/ /backup/
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
- [Spark 3.5 Chart](../spark-3.5/README.md) - Spark 3.5 documentation
- [Usage Guide](../../docs/guides/en/spark-k8s-constructor.md) - Complete user guide
- [Quick Reference](../../docs/guides/en/quick-reference.md) - Command cheat sheet
- [Architecture](../../docs/architecture/spark-k8s-charts.md) - System architecture

---

**Chart Version:** 0.1.0
**Spark Version:** 4.1.0
**Application Version:** 4.1.0
