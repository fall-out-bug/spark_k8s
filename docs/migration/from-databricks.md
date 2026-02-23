# Migrating from Databricks to Kubernetes

This guide helps you migrate Spark workloads from Databricks to Kubernetes.

## Overview

Migrating from Databricks to Kubernetes provides:
- Elimination of vendor lock-in
- Lower costs at scale
- Better control over infrastructure
- Multi-cloud portability

## Prerequisites

- Kubernetes cluster with cloud storage access
- Databricks workspace access
- Spark Operator installed
- Docker registry access

## Key Differences

| Aspect | Databricks | Kubernetes |
|--------|-----------|------------|
| **Notebooks** | Databricks Notebooks | JupyterHub + custom |
| **Jobs** | Databricks Jobs | SparkApplications + CronJobs |
| **Clusters** | Managed clusters | Pod-based executors |
| **Storage** | DBFS + Cloud | Direct cloud storage |
| **Libraries** | Workspace library | Docker image |
| **Secrets** | Databricks Secrets | Kubernetes Secrets |
| **UC** | Unity Catalog | External catalog |

## Step-by-Step Migration

### Step 1: Analyze Databricks Workspace

```python
# Export notebook list
import databricks.workspace as ws

notebooks = ws.list(workspace_path='/')
for nb in notebooks:
    print(f"{nb.path}: {nb.object_type}")

# Export job definitions
import databricks.jobs as jobs

job_list = jobs.list_jobs()
for job in job_list:
    print(f"Job: {job.settings.name}")
    print(f"  Schedule: {job.settings.schedule}")
```

### Step 2: Convert Notebooks

**Databricks notebook (.dbspark):**
```python
# Databricks magic commands
%sql
SELECT * FROM table

%python
df = spark.read.table("table")

%run ./shared_utils
```

**Convert to standard Jupyter:**
```python
# Standard Python with pyspark
from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()

# SQL via spark.sql
df = spark.sql("SELECT * FROM table")

# Import shared utilities
import sys
sys.path.append('./utils')
from shared_utils import my_function
```

### Step 3: Handle DBFS

**Databricks:**
```python
# DBFS paths
df = spark.read.parquet("/dbfs/mnt/data/")
df.write.parquet("/dbfs/mnt/output/")
```

**Kubernetes:**
```python
# Direct cloud storage paths
df = spark.read.parquet("s3a://my-bucket/data/")
df.write.parquet("s3a://my-bucket/output/")
```

### Step 4: Handle Databricks Widgets

**Databricks:**
```python
dbutils.widgets.text("name", "default")
name = dbutils.widgets.get("name")
```

**Kubernetes:**
```python
# Use environment variables or arguments
import os

name = os.getenv("NAME", "default")
# Or pass as SparkApplication arguments
```

### Step 5: Handle Unity Catalog

**Databricks:**
```python
df = spark.table("catalog.schema.table")
```

**Kubernetes:**
```yaml
# Configure external catalog
spec:
  sparkConf:
    spark.sql.catalog.catalog: "org.apache.iceberg.spark.SparkCatalog"
    spark.sql.catalog.catalog.type: "hadoop"
    spark.sql.catalog.catalog.warehouse: "s3a://my-bucket/warehouse"

# Then use:
# df = spark.table("catalog.schema.table")
```

### Step 6: Convert Databricks Jobs

**Databricks job:**
```json
{
  "name": "ETL Job",
  "email_notifications": {
    "on_start": ["team@example.com"],
    "on_success": ["team@example.com"],
    "on_failure": ["alerts@example.com"]
  },
  "timeout_seconds": 3600,
  "max_retries": 3,
  "schedule": {
    "quartz_cron_expression": "0 2 * * *",
    "timezone_id": "UTC"
  },
  "notebook_task": {
    "notebook_path": "/Users/user@example.com/etl"
  }
}
```

**Kubernetes equivalent:**
```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: etl-job
  namespace: spark-prod
spec:
  type: Python
  mode: cluster
  image: my-registry/spark-jobs:latest
  mainApplicationFile: local:///app/jobs/etl.py
  schedule: "0 2 * * *"

  sparkVersion: "3.5.0"
  timeLimit: 3600
  restartPolicy:
    type: OnFailure
    onFailureRetries: 3
    onFailureRetryInterval: 60

  driver:
    cores: 2
    memory: "4g"
    serviceAccount: spark
    env:
      - name: NOTIFY_ON_SUCCESS
        value: "team@example.com"
      - name: NOTIFY_ON_FAILURE
        value: "alerts@example.com"

  executor:
    cores: 4
    instances: 10
    memory: "8g"
```

### Step 7: Handle Databricks Libraries

**Databricks:**
```python
# Library in workspace
dbutils.library.installPyPI("boto3")
dbutils.library.restartPython()
```

**Kubernetes:**
```dockerfile
# Include in Docker image
FROM apache/spark:3.5.0

RUN pip install boto3

COPY job.py /app/jobs/
```

### Step 8: Handle Delta Lake

**Databricks:**
```python
# Built-in Delta Lake
df.write.format("delta").save("/dbfs/delta/table")
```

**Kubernetes:**
```yaml
spec:
  deps:
    pyPackages:
      - delta-spark==2.4.0
  sparkConf:
    spark.sql.extensions: "io.delta.sql.DeltaSparkSessionExtension"
    spark.sql.catalog.spark_catalog: "org.apache.spark.sql.delta.catalog.DeltaCatalog"
```

### Step 9: Handle Secrets

**Databricks:**
```python
# Databricks Secrets
key = dbutils.secrets.get("scope", "key")
```

**Kubernetes:**
```yaml
# Create secret
apiVersion: v1
kind: Secret
metadata:
  name: my-secrets
type: Opaque
stringData:
  key: value

---
# Mount in SparkApplication
spec:
  driver:
    env:
      - name: KEY
        valueFrom:
          secretKeyRef:
            name: my-secrets
            key: key
```

### Step 10: Handle MLflow

**Databricks:**
```python
# Managed MLflow
import mlflow
mlflow.set_experiment("/Users/user@example.com/exp")
```

**Kubernetes:**
```yaml
spec:
  driver:
    env:
      - name: MLFLOW_TRACKING_URI
        value: "http://mlflow.mlflow.svc.cluster.local:5000"
      - name: MLFLOW_S3_ENDPOINT_URL
        value: "https://s3.amazonaws.com"
```

## Databricks Features → Kubernetes

| Databricks | Kubernetes | Notes |
|------------|-----------|-------|
| DBFS | S3/GS/Azure Blob | Direct cloud storage |
| Delta Lake | delta-spark | Same functionality |
| MLflow | Self-hosted MLflow | Same API |
| Jobs API | SparkApplication + CronJob | Equivalent |
| Delta Live Tables | dbt / custom | Need adaptation |
| AutoML | Custom or Ray | Need adaptation |
| Feature Store | Feast | Alternative |
| SQL Warehouse | Spark Thrift Server | Alternative |

## Validation Checklist

- [ ] Notebooks execute successfully
- [ ] Jobs complete within SLA
- [ ] Data output matches exactly
- [ ] ML models produce same results
- [ ] All integrations working
- [ ] Monitoring and alerting configured

## Cost Comparison

| Factor | Databricks | Kubernetes |
|--------|-----------|------------|
| Compute | Premium instance rates | Standard pod rates |
| Storage | DBFS premium | Direct cloud storage |
| Network | VNet egress charges | Standard network |
| Support | Included | Self-managed |
| **Typical savings** | - | **30-50%** |

## Rollback Plan

Keep Databricks workspace available during transition:

```python
# Run validation queries comparing outputs
def validate_outputs(databricks_path, k8s_path):
    df_db = spark.read.parquet(databricks_path)
    df_k8s = spark.read.parquet(k8s_path)

    # Compare row counts
    assert df_db.count() == df_k8s.count()

    # Compare schemas
    assert df_db.schema == df_k8s.schema

    # Sample comparison
    sample_db = df_db.sample(0.01).collect()
    sample_k8s = df_k8s.sample(0.01).collect()
    # Compare values...
```

## Best Practices

1. **Notebook conversion**: Use automated tools like nbconvert
2. **Library management**: Pin versions in Docker image
3. **Secret management**: Use Kubernetes Secrets + external vault
4. **Incremental migration**: Migrate one job at a time
5. **Parallel operation**: Keep Databricks for comparison

## Related

- [From EMR Migration](./from-emr.md)
- [From Standalone Migration](./from-standalone.md)
- [Delta Lake on K8s](../../guides/delta-lake/setup.md)
