# History Server Shows No Jobs

**Related Issue:** ISSUE-006

## Symptoms

- History Server UI пустой
- `http://history-server:18080` не показывает job'ы
- Jobs завершаются успешно, но не появляются в UI

## Diagnosis

```bash
# Проверить logDirectory
kubectl exec -n <namespace> deploy/history-server -- \
  printenv | grep SPARK_HISTORY_OPTS

# Проверить что event logs пишутся
kubectl run mc-$(date +%s) --rm -i --restart=Never -n <namespace> --image=quay.io/minio/mc:latest -- \
  /bin/sh -lc "mc ls minio/spark-logs/4.1/events"

# Проверить логи History Server
kubectl logs -n <namespace> deploy/history-server --tail=100
```

## Solution

### Проблема 1: logDirectory не совпадает с eventLog.dir

```bash
# Spark 4.1: убедиться что пути совпадают
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --reuse-values
```

### Проблема 2: History Server нет доступа к S3

```bash
# Добавить credentials
kubectl create secret generic s3-credentials \
  -n <namespace> \
  --from-literal=access-key=minioadmin \
  --from-literal=secret-key=minioadmin

helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set global.s3.existingSecret=s3-credentials \
  --reuse-values
```

### Проблема 3: eventLog не включён

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --reuse-values
```

### Полная настройка

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --set connect.eventLog.compress=true \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --set global.s3.endpoint=http://minio:9000 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --reuse-values
```

## Verification

```bash
# Рестарт
kubectl rollout restart deployment -n <namespace> -l app=history-server

# Запустить тестовый job
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-41-connect:15002').getOrCreate()
spark.range(1000).count()
spark.stop()
"

# Подождать и проверить
sleep 10
kubectl run mc-$(date +%s) --rm -i --restart=Never -n <namespace> --image=quay.io/minio/mc:latest -- \
  /bin/sh -lc "mc ls minio/spark-logs/4.1/events | tail -5"

# Открыть UI
kubectl port-forward -n <namespace> svc/spark-41-history-server 18080:18080
# Открыть: http://localhost:18080
```

## References

- ISSUE-006: History log prefix missing (4.1)
- History Server guide: `docs/guides/ru/spark-k8s-constructor.md`
- Spark Monitoring: https://spark.apache.org/docs/latest/monitoring.html#configuration
