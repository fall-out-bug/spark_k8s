# Migrating from Standalone Spark to Kubernetes

This guide helps you migrate Spark workloads from standalone mode to Kubernetes.

## Overview

Migrating to Kubernetes provides:
- Better resource isolation
- Dynamic scaling
- Improved fault tolerance
- Cloud-native integration

## Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured
- Spark Operator installed
- Existing Spark applications

## Comparison: Standalone vs Kubernetes

| Aspect | Standalone | Kubernetes |
|--------|-----------|------------|
| **Deployment** | Manual scripts | YAML manifests |
| **Scaling** | Static | Dynamic (HPA) |
| **Resource mgmt** | Manual | Requests/Limits |
| **Fault tolerance** | Limited | Native |
| **Monitoring** | Manual | Prometheus |
| **Logs** | File-based | Centralized |

## Step-by-Step Migration

### Step 1: Assess Current Workloads

```bash
# List all Spark applications
spark-submit --list

# Analyze resource usage
for app in $(spark-submit --list | grep running | awk '{print $1}'); do
    echo "App: $app"
    spark-submit --status $app
done
```

### Step 2: Create Kubernetes Manifests

Convert spark-submit commands to SparkApplication resources:

**Before (standalone):**
```bash
spark-submit \
  --master spark://master:7077 \
  --class com.example.MyJob \
  --driver-memory 4g \
  --executor-memory 8g \
  --executor-cores 4 \
  --num-executors 10 \
  my-job.jar arg1 arg2
```

**After (Kubernetes):**
```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: my-job
  namespace: spark-prod
spec:
  type: Scala
  mode: cluster
  image: my-registry/spark-apps:latest
  mainClass: com.example.MyJob
  mainApplicationFile: local:///app/my-job.jar
  arguments:
    - arg1
    - arg2
  sparkVersion: "3.5.0"

  driver:
    cores: 2
    memory: "4g"
    serviceAccount: spark

  executor:
    cores: 4
    instances: 10
    memory: "8g"
```

### Step 3: Build Docker Images

```dockerfile
# Dockerfile for Spark applications
FROM apache/spark:3.5.0

# Install dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy application
COPY my-job.jar /app/
COPY --from=builder /src/dependencies /app/dependencies

WORKDIR /app
```

```bash
# Build and push
docker build -t my-registry/spark-apps:latest .
docker push my-registry/spark-apps:latest
```

### Step 4: Configure Resources

Map standalone resources to Kubernetes:

| Standalone | Kubernetes |
|------------|------------|
| `--driver-memory` | `driver.memory` |
| `--executor-memory` | `executor.memory` |
| `--executor-cores` | `executor.cores` |
| `--num-executors` | `executor.instances` |
| `--total-executor-cores` | `executor.cores * instances` |

### Step 5: Handle Dependencies

**Before (standalone with --packages):**
```bash
spark-submit \
  --packages com.amazonaws:aws-java-sdk:1.11.375 \
  --jars /path/to/dependency.jar \
  my-job.jar
```

**After (Kubernetes):**
```yaml
spec:
  deps:
    jars:
      - local:///app/dependencies/dependency.jar
    packages:
      - com.amazonaws:aws-java-sdk:1.11.375
    pyPackages:
      - boto3
      - requests
```

### Step 6: Configure Storage

Standalone local paths → Kubernetes volumes:

```yaml
spec:
  volumes:
    - name: data-volume
      persistentVolumeClaim:
        claimName: spark-data-pvc

  driver:
    volumeMounts:
      - name: data-volume
        mountPath: /data

  executor:
    volumeMounts:
      - name: data-volume
        mountPath: /data
```

### Step 7: Environment Variables

```yaml
spec:
  driver:
    env:
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: access-key-id
      - name: DATABASE_URL
        value: "postgresql://db:5432/mydb"
```

### Step 8: Deploy and Verify

```bash
# Deploy
kubectl apply -f my-job.yaml

# Watch status
kubectl get sparkapplication -w

# View logs
kubectl logs -f $(kubectl get pods -l spark-app-name=my-job,spark-role=driver -o name)

# Check metrics
kubectl port-forward $(kubectl get pods -l spark-app-name=my-job,spark-role=driver -o name) 4040:4040
# Visit http://localhost:4040
```

## Common Migration Patterns

### Pattern 1: Batch Jobs

**Standalone:**
```bash
# Cron job
0 2 * * * spark-submit --class ETLJob etl.jar
```

**Kubernetes:**
```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: etl-job
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: spark
          containers:
          - name: spark
            image: spark-submission:latest
            # ... spark-submit equivalent
```

### Pattern 2: Streaming Jobs

**Standalone:**
```bash
spark-submit \
  --master spark://master:7077 \
  --deploy-mode cluster \
  --supervise \
  streaming.jar
```

**Kubernetes:**
```yaml
spec:
  restartPolicy:
    type: OnFailure
    onFailureRetries: 3
    onFailureRetryInterval: 60
    onSubmissionFailureRetries: 5
```

### Pattern 3: Interactive Jobs

**Standalone:**
```bash
pyspark --master spark://master:7077
```

**Kubernetes:**
```bash
spark-shell \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode client \
  --conf spark.kubernetes.container.image=spark:3.5.0 \
  --conf spark.executor.instances=3
```

## Validation Checklist

- [ ] All jobs deployed successfully
- [ ] Logs are accessible
- [ ] Metrics are collected
- [ ] Resource usage is as expected
- [ ] Jobs complete within SLA
- [ ] Data quality verified

## Troubleshooting

| Issue | Standalone | Kubernetes | Fix |
|-------|-----------|------------|-----|
| Driver OOM | Check logs | Check driver pod | Increase `driver.memory` |
| Executor lost | Restart cluster | Auto-restarts | Check `restartPolicy` |
| File not found | Local path | Need ConfigMap/Volume | Use `local:///` or volumes |
| Permission denied | Check user | Check serviceAccount | RBAC permissions |

## Rollback Plan

If migration fails:

```bash
# Stop Kubernetes jobs
kubectl delete sparkapplication --all -n spark-prod

# Resume on standalone
spark-submit --master spark://standby-master:7077 my-job.jar
```

## Related

- [From EMR Migration](./from-emr.md)
- [From Databricks Migration](./from-databricks.md)
- [Version Upgrade Guide](./version-upgrade.md)
