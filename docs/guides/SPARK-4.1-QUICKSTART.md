# Spark 4.1.0 Quickstart (5 Minutes)

Deploy Apache Spark 4.1.0 with Spark Connect and Jupyter on Minikube.

## Prerequisites

- Minikube running
- Helm 3.x installed
- Docker images built:
  - `spark-custom:4.1.0`
  - `jupyter-spark:4.1.0`

Quick check:

```bash
minikube status
helm version
docker images | grep -E 'spark-custom|jupyter-spark'
```

## 1. Deploy Spark 4.1.0

```bash
helm install spark-41 charts/spark-4.1 \
  --set spark-base.enabled=true \
  --set connect.enabled=true \
  --set jupyter.enabled=true \
  --set hiveMetastore.enabled=true \
  --set historyServer.enabled=true \
  --wait
```

## 2. Verify Deployment

```bash
kubectl get pods -l app.kubernetes.io/instance=spark-41
# All pods should be Running/Ready
```

## 3. Access Jupyter

```bash
kubectl port-forward svc/spark-41-spark-41-jupyter 8888:8888
# Open http://localhost:8888
```

## 4. Run Your First Spark Job

In Jupyter, create a new notebook and run:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("Quickstart") \
    .remote("sc://spark-41-spark-41-connect:15002") \
    .getOrCreate()

df = spark.range(1000000).selectExpr("id", "id * 2 as doubled")
df.show(5)

print(f"Spark version: {spark.version}")
```

## 5. (Optional) History Server

```bash
kubectl port-forward svc/spark-41-spark-41-history 18080:18080
# Open http://localhost:18080
```

## Next Steps

- [Production Deployment Guide](SPARK-4.1-PRODUCTION.md)
- [Celeborn Integration](CELEBORN-GUIDE.md)
- [Spark Operator Guide](SPARK-OPERATOR-GUIDE.md)
