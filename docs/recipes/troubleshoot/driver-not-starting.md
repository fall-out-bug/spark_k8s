# Driver Not Starting / Connection Refused

**Related Issues:** ISSUE-020, ISSUE-024

## Symptoms

```
Error: Could not connect to driver
java.net.ConnectException: Connection refused
SparkConnect: Failed to connect to spark://...
Driver pod: CrashLoopBackOff
```

## Diagnosis

```bash
# Проверить статус driver pod
kubectl get pods -n <namespace> -l spark-role=driver

# Логи driver
kubectl logs -n <namespace> <driver-pod> --tail=100

# Проверить driver.host конфигурацию
kubectl exec -n <namespace> deploy/spark-connect -- \
  printenv | grep SPARK_DRIVER_HOST

# Проверить service
kubectl get svc -n <namespace> spark-connect -o yaml
```

## Solution

### Spark 4.1 + K8s backend: driver.host пустой

```bash
# Для K8s backend driver.host должен быть пустой
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.driver.host="" \
  --set connect.backendMode=k8s \
  --reuse-values
```

### Spark 4.1 + Standalone backend: driver.host = FQDN

```bash
# Для Standalone backend нужно указать FQDN
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.driver.host=<release>-spark-41-connect.<namespace>.svc.cluster.local \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-sa-spark-standalone-master \
  --reuse-values
```

### Spark 3.5 + Standalone: driver.host через env

```bash
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set sparkConnect.driver.host=spark-connect.<namespace>.svc.cluster.local \
  --set sparkConnect.env.SPARK_DRIVER_HOST=spark-connect.<namespace>.svc.cluster.local \
  --reuse-values
```

### Проверка FQDN для standalone

```bash
# Получить FQDN standalone master
kubectl get svc -n <standalone-namespace> spark-sa-spark-standalone-master-hl \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Или hostname
kubectl get svc -n <standalone-namespace> spark-sa-spark-standalone-master-hl \
  -o jsonpath='{.spec.externalName}')

# Полный FQDN для DNS
echo "<service>.<namespace>.svc.cluster.local"
```

### Проблема с launcher (ISSUE-020)

```bash
# Spark 4.1 connect launcher проблема
# Добавить точку входа для Connect
connect:
  command:
    - /opt/spark/sbin/start-connect-server.sh
    - --driver-memory 2g
    - --driver-cores 1
```

## Verification

```bash
# Рестарт
kubectl rollout restart deployment -n <namespace> -l app=spark-connect

# Дождаться готовности
kubectl wait --for=condition=ready pod -n <namespace> -l app=spark-connect --timeout=300s

# Проверить driver.host
kubectl exec -n <namespace> deploy/spark-connect -- \
  printenv | grep DRIVER

# Тест подключения
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-41-connect:15002').getOrCreate()
print(spark.version)
spark.stop()
"
```

## References

- ISSUE-020: Connect launcher (4.1)
- ISSUE-024: Connect driver host (4.1)
- Spark Connect: https://spark.apache.org/docs/latest/spark-connect.html
