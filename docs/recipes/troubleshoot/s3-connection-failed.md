# S3 Connection Failed

**Related Issue:** ISSUE-007

## Symptoms

```
com.amazonaws.AmazonClientException: Unable to execute HTTP request
java.net.UnknownHostException: minio:9000
Error accessing s3a://bucket/path
```

## Diagnosis

```bash
# Проверить endpoint
kubectl exec -n <namespace> deploy/spark-connect -- \
  curl -v http://minio:9000/minio/health/live

# Проверить credentials
kubectl get secret s3-credentials -n <namespace> -o yaml

# Проверить конфигурацию
kubectl exec -n <namespace> deploy/spark-connect -- \
  printenv | grep -E "AWS_|S3_"
```

## Solution

### Spark 4.1: Исправить global.s3 конфигурацию

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set global.s3.endpoint=http://minio:9000 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --set global.s3.pathStyleAccess=true \
  --set global.s3.sslEnabled=false \
  --reuse-values
```

### Spark 3.5: Исправить s3 конфигурацию

```bash
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set s3.endpoint=http://minio:9000 \
  --set s3.accessKey=minioadmin \
  --set s3.secretKey=minioadmin \
  --set s3.pathStyleAccess=true \
  --reuse-values
```

### Использовать existing secret вместо plaintext

```bash
# 1. Создать secret
kubectl create secret generic s3-credentials \
  -n <namespace> \
  --from-literal=access-key=minioadmin \
  --from-literal=secret-key=minioadmin

# 2. Использовать secret
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set global.s3.existingSecret=s3-credentials \
  --set global.s3.endpoint=http://minio:9000 \
  --reuse-values
```

### MinIO FQDN (если в другом namespace)

```bash
# Полное имя сервиса
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set global.s3.endpoint=http://minio.<minio-namespace>.svc.cluster.local:9000 \
  --reuse-values
```

## Verification

```bash
# Рестарт
kubectl rollout restart deployment -n <namespace> -l app=spark-connect

# Тест подключения
kubectl exec -n <namespace> deploy/spark-connect -- \
  /opt/spark/bin/spark-submit --master local[*] \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.access.key=minioadmin \
  --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
  /dev/null 2>&1 | head -20

# Тест через Jupyter
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-connect:15002').getOrCreate()
df = spark.read.csv('s3a://test/data.csv')
df.show()
spark.stop()
"
```

## References

- ISSUE-007: Missing S3 credentials secret
- S3A configuration: https://hadoop.apache.org/docs/stable/hadoop-aws/tools/hadoop-aws/index.html
