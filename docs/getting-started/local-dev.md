# Local Development Setup

Get Spark on Kubernetes running locally in under 5 minutes.

## Prerequisites

- Docker Desktop OR Docker Engine
- kubectl (v1.28+)
- helm (v3.12+)
- 8GB RAM minimum (16GB recommended)

## Option A: Minikube (Recommended for Beginners)

### 1. Start Minikube

```bash
minikube start --cpus=4 --memory=8192 --driver=docker
```

### 2. Verify Cluster

```bash
kubectl get nodes
```

Expected output:
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   10m   v1.28.x
```

### 3. Deploy Spark

```bash
helm repo add spark-k8s https://fall-out-bug.github.io/spark_k8s
helm repo update
helm install spark spark-k8s/spark-connect --set spark.connect.mode.k8s.backend=local
```

### 4. Port Forward Jupyter

```bash
kubectl port-forward svc/jupyter 8888:8888
```

### 5. Open Browser

Navigate to http://localhost:8888

That's it! You have Spark Connect running locally.

---

## Option B: Kind (For Advanced Users)

### 1. Create Kind Cluster

```bash
kind create cluster --name spark-dev --image=kindest/node:v1.28.0
```

### 2. Deploy Spark

```bash
helm repo add spark-k8s https://fall-out-bug.github.io/spark_k8s
helm install spark spark-k8s/spark-connect --set spark.connect.mode.k8s.backend=local
```

Follow steps 4-5 from Minikube guide above.

---

## Verify Installation

Run your first Spark job:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("LocalTest") \
    .remote("sc://localhost") \
    .getOrCreate()

df = spark.range(1000)
df.show()

spark.stop()
```

**Expected output:** DataFrame with numbers 0-999

---

## Troubleshooting

### Minikube won't start

```bash
# Check Docker status
docker ps

# Restart Docker Desktop
# Try with more resources
minikube start --cpus=2 --memory=4096
```

### Port 8888 already in use

```bash
# Find process using port 8888
lsof -ti:8888 | xargs kill -9

# Or use different port
kubectl port-forward svc/jupyter 8889:8888
```

### Spark Connect connection refused

```bash
# Verify Spark Connect is running
kubectl get pods -l app=spark-connect

# Check logs
kubectl logs -f deployment/spark-connect
```

---

## Next Steps

- [Your First Spark Job](first-spark-job.md) — Beyond "Hello World"
- [Choose Your Backend](choose-backend.md) — When to use K8s vs Standalone
- [Cloud Setup](cloud-setup.md) — Deploy to production

---

**Time:** 5 minutes
**Difficulty:** Beginner
**Last Updated:** 2026-02-04
