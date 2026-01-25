# Driver Host FQDN Resolution

**Related Issue:** ISSUE-025

## Symptoms

```
java.net.UnknownHostException: spark-connect
Failed to resolve driver host
Connection refused to spark://spark-connect:7078
```

## Diagnosis

```bash
# Проверить текущий driver.host
kubectl exec -n <namespace> deploy/spark-connect -- \
  printenv | grep SPARK_DRIVER_HOST

# Проверить DNS резолвинг
kubectl run test-dns --rm -it -n <namespace> --image=busybox -- \
  nslookup spark-connect.<namespace>.svc.cluster.local

# Проверить service
kubectl get svc -n <namespace> spark-connect
```

## Solution

### Spark 4.1 + K8s backend: Использовать service FQDN

```bash
# Для деплоя в том же namespace
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.driver.host=spark-41-connect.<namespace>.svc.cluster.local \
  --reuse-values

# Или через template
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.driver.host="{{ .Release.Name }}-spark-41-connect.{{ .Release.Namespace }}.svc.cluster.local" \
  --reuse-values
```

### Spark 4.1 + Standalone: External FQDN

```bash
# Для подключения к standalone в другом namespace
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.driver.host=<namespace>-spark-connect.<namespace>.svc.cluster.local \
  --set connect.standalone.masterService=standalone-master.<standalone-ns>.svc.cluster.local \
  --reuse-values
```

### Spark 3.5 + Connect: Использовать env переменную

```bash
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set sparkConnect.driver.host=spark-connect.<namespace>.svc.cluster.local \
  --set sparkConnect.env.SPARK_DRIVER_HOST=spark-connect.<namespace>.svc.cluster.local \
  --reuse-values
```

### Для Jupyter подключения

```bash
# Обновить SPARK_CONNECT_URL в Jupyter
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set jupyter.env.SPARK_CONNECT_URL="sc://spark-41-connect.<namespace>.svc.cluster.local:15002" \
  --reuse-values
```

### Для Airflow подключения

```bash
# Установить Airflow variables
kubectl exec -n <namespace> deploy/<airflow-scheduler> -- \
  airflow variables set spark_connect_host spark-41-connect.<namespace>.svc.cluster.local

kubectl exec -n <namespace> deploy/<airflow-scheduler> -- \
  airflow variables set spark_connect_port 15002
```

## Verification

```bash
# Проверить DNS резолвинг
kubectl run test-dns --rm -it -n <namespace> --image=busybox -- \
  nslookup spark-41-connect.<namespace>.svc.cluster.local

# Проверить что service доступен
kubectl run test-curl --rm -it -n <namespace> --image=curlimages/curl -- \
  curl http://spark-41-connect.<namespace>.svc.cluster.local:15002

# Тест из Jupyter
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .remote('sc://spark-41-connect.<namespace>.svc.cluster.local:15002') \
    .getOrCreate()
print(f'Spark version: {spark.version}')
print(f'Driver host: {spark.conf.get(\"spark.driver.host\")}')
spark.stop()
"
```

## References

- ISSUE-025: Driver host FQDN
- K8s DNS: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- ISSUE-024: Connect driver host (4.1)
