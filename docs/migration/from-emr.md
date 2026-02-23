# Migrating from Amazon EMR to Kubernetes

This guide helps you migrate Spark workloads from Amazon EMR to Kubernetes.

## Overview

Migrating from EMR to Kubernetes provides:
- Lower operational overhead
- Better cloud portability
- More granular resource control
- Consistent dev/prod environments

## Prerequisites

- Kubernetes cluster with S3 access
- EMR cluster access (for comparison)
- Spark Operator installed
- AWS credentials configured

## Key Differences

| Aspect | EMR | Kubernetes |
|--------|-----|------------|
| **Cluster mgmt** | AWS-managed | Self-managed |
| **Scaling** | Instance fleets | HPA/Cluster Autoscaler |
| **Storage** | HDFS + S3 | S3 + PV/PVC |
| **Scheduling** | YARN | Kubernetes scheduler |
| **Cost** | Instance hours | Pod resource usage |
| **Security** | IAM roles | IRSA + RBAC |

## Step-by-Step Migration

### Step 1: Audit Current EMR Jobs

```bash
# List EMR steps
aws emr list-steps --cluster-id j-XXXXXXXX --status RUNNING

# Analyze step configuration
aws emr describe-step --cluster-id j-XXXXXXXX --step-id s-XXXXXXXX

# Export job configuration
aws emr create-studio --name "Migration Analysis" \
  --description "Analyze EMR workloads"
```

### Step 2: Map EMR Configurations

Convert EMR configuration to Kubernetes:

**EMR step configuration:**
```json
{
  "Name": "Spark Application",
  "ActionOnFailure": "TERMINATE_CLUSTER",
  "HadoopJarStep": {
    "Jar": "command-runner.jar",
    "Args": [
      "spark-submit",
      "--deploy-mode", "cluster",
      "--executor-memory", "8g",
      "--executor-cores", "4",
      "--num-executors", "50",
      "--conf", "spark.dynamicAllocation.enabled=true",
      "s3://my-bucket/jobs/my-job.jar"
    ]
  }
}
```

**Kubernetes equivalent:**
```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: my-job
spec:
  type: Java
  mode: cluster
  image: my-registry/spark:3.5.0
  mainApplicationFile: s3a://my-bucket/jobs/my-job.jar
  sparkVersion: "3.5.0"

  # EMR instance mapping
  driver:
    cores: 4           # From --driver-cores
    memory: "16g"      # From --driver-memory
    memoryOverhead: "2g"

  executor:
    cores: 4           # From --executor-cores
    instances: 50      # From --num-executors (or max with dynamic allocation)
    memory: "8g"       # From --executor-memory
    memoryOverhead: "1g"

  # EMR configuration
  sparkConf:
    spark.dynamicAllocation.enabled: "true"
    spark.dynamicAllocation.minExecutors: "10"
    spark.dynamicAllocation.maxExecutors: "100"
    spark.dynamicAllocation.initialExecutors: "50"
```

### Step 3: Handle S3 Access

**EMR:** Uses IAM role implicitly
**Kubernetes:** Needs explicit configuration

```yaml
# Option 1: IRSA (Recommended)
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/SparkRole

# Option 2: AWS Secrets
spec:
  driver:
    env:
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: access-key-id
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: secret-access-key
      - name: AWS_REGION
        value: "us-west-2"

# Configure S3 connector
  sparkConf:
    spark.hadoop.fs.s3a.access.key: "${AWS_ACCESS_KEY_ID}"
    spark.hadoop.fs.s3a.secret.key: "${AWS_SECRET_ACCESS_KEY}"
    spark.hadoop.fs.s3a.endpoint: "s3.us-west-2.amazonaws.com"
```

### Step 4: Handle Dependencies

**EMR:** Pre-installed libraries
**Kubernetes:** Must be included in image

```dockerfile
# Include EMR libraries
FROM apache/spark:3.5.0

# EMR libraries
RUN pip install \
    boto3 \
    sagemaker-pyspark \
    awsglue-libs \
    pyspark==3.5.0

# Copy job dependencies
COPY --from=builder /app /app
```

### Step 5: Handle Glue Catalog

**EMR:** Direct Glue integration
**Kubernetes:** Configure connector

```yaml
spec:
  sparkConf:
    spark.hadoop.hive.metastore.client.factory.class: com.amazonaws.glue.catalog.metastore.GlueCatalogClientFactory
    spark.hadoop.hive.metastore.glue.catalogid: "123456789012"
    spark.sql.catalogImplementation: "hive"
```

### Step 6: Handle EMRFS

EMRFS features → Kubernetes equivalents:

| EMRFS Feature | Kubernetes Equivalent |
|---------------|----------------------|
| Consistent view | S3 GuardDuty + versioning |
| S3 encryption | IAM policies + KMS |
| S3 multipart | Default in S3A connector |

```yaml
spec:
  sparkConf:
    # S3 encryption
    spark.hadoop.fs.s3a.server-side-encryption-algorithm: "AES256"
    spark.hadoop.fs.s3a.acl.default: "BucketOwnerFullControl"

    # Performance
    spark.hadoop.fs.s3a.multipart.size: "104857600"
    spark.hadoop.fs.s3a.fast.upload: "true"
```

### Step 7: Cost Comparison

Calculate cost differences:

```python
# EMR cost
emr_cost = (instance_hourly_rate * hours * instances) + ebs_cost

# Kubernetes cost
k8s_cost = (pod_hourly_rate * hours * pods) + storage_cost + network_cost

# Typically: K8s 30-50% cheaper for variable workloads
```

### Step 8: Deploy and Validate

```bash
# Deploy to Kubernetes
kubectl apply -f emr-migrated-job.yaml

# Compare execution time
emr_time=$(aws emr describe-step --cluster-id j-XXX --step-id s-XXX --query 'Step.Status.Timeline.EndDateTime')
k8s_time=$(kubectl get sparkapplication my-job -o jsonpath='{.status.applicationStatus.lastSubmissionAttemptTime}')

# Compare data quality
# Run validation queries on both outputs
```

## EMR Instance Type Mapping

| EMR Instance | Kubernetes Equivalent |
|--------------|----------------------|
| m5.xlarge (4 vCPU, 16GB) | 4 cores, 16GB memory |
| m5.2xlarge (8 vCPU, 32GB) | 8 cores, 32GB memory |
| m5.4xlarge (16 vCPU, 64GB) | 16 cores, 64GB memory |
| r5.xlarge (4 vCPU, 32GB) | 4 cores, 32GB memory |

## Common EMR Features → Kubernetes

| EMR Feature | Kubernetes Implementation |
|-------------|--------------------------|
| EMR Steps | SparkApplication resources |
| EMR Notebooks | JupyterHub + Spark operator |
| EMR Studio | Custom dashboard |
| EMR Managed Scaling | Kubernetes HPA |
| EMR Auto Scaling | Cluster Autoscaler |
| S3 Event Notification | S3 EventBridge → K8s |
| EMRFS Consistent View | S3 Versioning |

## Troubleshooting EMR Migration

| Issue | EMR | Kubernetes | Fix |
|-------|-----|------------|-----|
| S3 access denied | Works | Fails | Check IAM/IRSA |
| Glue table not found | Works | Fails | Configure Glue catalog |
| Slower performance | Normal | Slower | Check resource limits |
| Out of memory | Works | Fails | Increase memory overhead |
| EMRFS inconsistency | S3EMR | N/A | Enable S3 versioning |

## Rollback Plan

```bash
# If migration fails, resume on EMR
aws emr add-steps --cluster-id j-XXXXXXXX --steps file://steps.json

# Keep EMR cluster available until migration verified
```

## Best Practices

1. **Parallel run**: Run on both EMR and K8s for validation period
2. **Feature parity**: Ensure all EMRFS features have equivalents
3. **Monitoring**: Compare metrics between platforms
4. **Cost tracking**: Monitor actual vs expected costs
5. **Gradual cutover**: Migrate non-critical jobs first

## Related

- [From Standalone Migration](./from-standalone.md)
- [From Databricks Migration](./from-databricks.md)
- [S3 Configuration Guide](../../guides/storage/s3-setup.md)
