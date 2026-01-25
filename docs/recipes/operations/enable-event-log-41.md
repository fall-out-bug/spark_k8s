# Enable Event Log for Spark 4.1

**Related Issue:** ISSUE-022

## Symptoms

- Spark 4.1 jobs не оставляют event logs
- History Server пустой
- Нет истории выполнений

## Diagnosis

```bash
# Проверить включен ли eventLog
kubectl exec -n <namespace> deploy/spark-41-connect -- \
  printenv | grep SPARK_EVENTLOG

# Проверить конфиг
kubectl get cm -n <namespace> spark-41-connect-configmap -o yaml
```

## Solution

### Включить eventLog для Spark Connect 4.1

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --set connect.eventLog.compress=true \
  --reuse-values
```

### Включить History Server

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --set historyServer.resources.requests.memory=1Gi \
  --set historyServer.resources.limits.memory=2Gi \
  --reuse-values
```

### Полная конфигурация через preset

Используйте `values-scenario-jupyter-connect-k8s.yaml` который уже включает eventLog:

```yaml
connect:
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/4.1/events"

historyServer:
  enabled: true
  logDirectory: "s3a://spark-logs/4.1/events"
```

## Verification

```bash
# Рестарт
kubectl rollout restart deployment -n <namespace> -l app=spark-connect

# Запустить job
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-41-connect:15002').getOrCreate()
spark.range(100).count()
spark.stop()
"

# Проверить логи
kubectl run mc-$(date +%s) --rm -i --restart=Never -n <namespace> --image=quay.io/minio/mc:latest -- \
  /bin/sh -lc "mc ls minio/spark-logs/4.1/events"

# History Server
kubectl port-forward -n <namespace> svc/spark-41-history-server 18080:18080
```

## References

- ISSUE-022: Event log prefix missing (4.1)
- History Server guide: `docs/guides/ru/spark-k8s-constructor.md`
