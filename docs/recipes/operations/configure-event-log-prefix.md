# Configure Event Log Prefix for MinIO

**Related Issue:** ISSUE-013

## Symptoms

- History Server не видит логи от Spark jobs
- Event logs не создаются в ожидаемом месте
- Jobs завершаются успешно, но UI пустой

## Diagnosis

```bash
# Проверить текущий eventLog.dir
kubectl exec -n <namespace> deploy/spark-connect -- \
  printenv | grep SPARK_EVENTLOG_DIR

# Проверить что файлы создаются в MinIO
kubectl run mc-$(date +%s) --rm -i --restart=Never -n <namespace> --image=quay.io/minio/mc:latest -- \
  /bin/sh -lc "mc alias set minio http://minio:9000 minioadmin minioadmin && mc ls minio/spark-logs/events"
```

## Solution

### Для Spark 3.5 + Connect

```bash
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set sparkConnect.eventLog.enabled=true \
  --set sparkConnect.eventLog.dir=s3a://spark-logs/events \
  --reuse-values
```

### Для Spark 4.1 + Connect

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --reuse-values
```

### Создать prefix в MinIO (автоматически через тесты)

```bash
ensure_event_log_prefix() {
  local ns="$1"
  local endpoint="http://minio:9000"
  local prefix="spark-logs/events"

  kubectl run "mc-prefix-$(date +%s)" --rm -i --restart=Never -n "${ns}" --command \
    --image=quay.io/minio/mc:latest \
    -- /bin/sh -lc "mc alias set minio ${endpoint} minioadmin minioadmin >/dev/null 2>&1 && \
                  mc mb --ignore-existing minio/spark-logs >/dev/null 2>&1 && \
                  echo '' | mc pipe minio/${prefix}/.keep >/dev/null 2>&1"
}
```

### Для History Server

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --reuse-values

# Spark 3.5
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/events \
  --reuse-values
```

### Рестарт pod'ов после изменения

```bash
kubectl rollout restart deployment -n <namespace> -l app=spark-connect
kubectl rollout restart deployment -n <namespace> -l app=history-server
```

## Verification

```bash
# Запустить тестовый job
kubectl exec -n <namespace> deploy/jupyter -- \
  /bin/sh -lc 'spark-submit --master local[*] --conf spark.eventLog.enabled=true \
    --conf spark.eventLog.dir=s3a://spark-logs/events \
    /dev/null 2>&1 || true'

# Проверить что log файл создался
kubectl run mc-$(date +%s) --rm -i --restart=Never -n <namespace> --image=quay.io/minio/mc:latest -- \
  /bin/sh -lc "mc alias set minio http://minio:9000 minioadmin minioadmin && \
                mc ls minio/spark-logs/events | tail -5"

# Открыть History Server
kubectl port-forward -n <namespace> svc/history-server 18080:18080
# Открыть: http://localhost:18080
```

## References

- ISSUE-013: Spark Connect MinIO events prefix
- Apache Spark Monitoring: https://spark.apache.org/docs/latest/monitoring.html
