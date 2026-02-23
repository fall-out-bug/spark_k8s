# Quick Start Guide - Spark K8s Constructor

Get started with Spark on Kubernetes in 15 minutes.

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud)
- `kubectl` configured
- `helm` v3.x installed

## Step 1: Deploy Spark (2 min)

```bash
# Add Helm repo (if needed)
# helm repo add spark-k8s https://charts.spark-k8s.io

# Install Spark
helm install spark charts/spark-4.1 \
  --values charts/spark-4.1/environments/dev/values.yaml \
  --namespace spark \
  --create-namespace

# Wait for pods ready
kubectl wait --for=condition=ready pod -l app=spark-connect -n spark --timeout=300s
```

## Step 1.5: Use Presets (Optional)

Spark K8s Constructor includes ready-to-use presets for common use cases:

```bash
# GPU acceleration (NVIDIA RAPIDS)
helm install spark charts/spark-4.1 \
  --values charts/spark-4.1/presets/gpu-values.yaml \
  --namespace spark --create-namespace

# Apache Iceberg (ACID tables, time travel)
helm install spark charts/spark-4.1 \
  --values charts/spark-4.1/presets/iceberg-values.yaml \
  --namespace spark --create-namespace

# Cost-optimized (spot instances, auto-scaling)
helm install spark charts/spark-4.1 \
  --values charts/spark-4.1/presets/cost-optimized-values.yaml \
  --namespace spark --create-namespace
```

See guides:
- **GPU**: `docs/recipes/gpu/gpu-guide.md`
- **Iceberg**: `docs/recipes/data-management/iceberg-guide.md`
- **Auto-scaling**: `docs/recipes/cost-optimization/auto-scaling-guide.md`

## Step 2: Port Forward (1 min)

```bash
# Forward Spark Connect port
kubectl port-forward -n spark svc/spark-spark-41-connect 15002:15002

# In another terminal, forward Jupyter
kubectl port-forward -n spark svc/spark-spark-41-jupyter 8888:8888
```

## Step 3: Run First Query (2 min)

### Option A: PySpark Shell

```bash
kubectl exec -it -n spark spark-spark-41-connect-0 -- \
  /opt/spark/bin/pyspark \
  --master spark://spark-spark-41-connect:15002

# In PySpark:
df = spark.read.csv("s3a://warehouse/data.csv")
df.show()
```

### Option B: Jupyter

```bash
# Get token
kubectl logs -n spark spark-spark-41-jupyter-0 | grep "token="

# Open: http://localhost:8888/?token=YOUR_TOKEN

# Create new notebook and run:
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("QuickStart").getOrCreate()
df = spark.range(1000).toDF("id")
df.show()
```

## Step 4: Verify Monitoring (2 min)

```bash
# Install Prometheus (if not present)
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Open: http://localhost:3000 (admin/prom-operator)
```

## Step 5: Run Test Job (3 min)

```bash
# Submit test job
kubectl exec -it -n spark spark-spark-41-connect-0 -- \
  /opt/spark/bin/spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode cluster \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.container.image=spark-custom:4.1.0 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-41 \
  examples/src/main/python/pi.py 100
```

## Step 6: Check Logs (1 min)

```bash
# Spark Connect logs
kubectl logs -n spark spark-spark-41-connect-0 -f

# Executor logs
kubectl logs -n spark -l spark-role=executor --tail=10

# History Server
kubectl port-forward -n spark svc/spark-spark-41-history-server 18080:18080
# Open: http://localhost:18080
```

## Next Steps

- **Configure S3**: Update `values.yaml` with S3 credentials
- **Enable monitoring**: Set `monitoring.serviceMonitor.enabled=true`
- **Setup CI/CD**: See `.github/workflows/promote-to-staging.yml`
- **Custom image**: Build with custom JARs
- **Production**: Use `charts/spark-4.1/environments/prod/values.yaml`

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod -n spark <pod-name>
kubectl logs -n spark <pod-name>
```

### Connection refused

```bash
# Check Spark Connect is ready
kubectl get pods -n spark -l app=spark-connect
```

### Out of memory

```bash
# Increase resources in values.yaml
connect.resources.limits.memory: "8Gi"
```

## Success Criteria

✅ Spark Connect pods running
✅ Can run PySpark queries
✅ Jupyter accessible
✅ Monitoring metrics visible
✅ Test job completed

**Time:** ~15 minutes
