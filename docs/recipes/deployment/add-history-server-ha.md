# Add History Server with HA

**Source:** History Server guide

## Overview

Добавить History Server для мониторинга Spark jobs с высокой доступностью (HA).

## Prerequisites

- Spark Connect уже развернут
- Event logs включены
- S3/MinIO доступен

## Deployment

### Шаг 1: Включить eventLog (если не включён)

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --set connect.eventLog.compress=true \
  --reuse-values

# Spark 3.5
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set sparkConnect.eventLog.enabled=true \
  --set sparkConnect.eventLog.dir=s3a://spark-logs/events \
  --reuse-values
```

### Шаг 2: Деплой History Server (single replica)

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --set historyServer.resources.requests.memory=1Gi \
  --set historyServer.resources.limits.memory=2Gi \
  --reuse-values

# Spark 3.5
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/events \
  --reuse-values
```

### Шаг 3: Настроить HA (3 replicas)

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set historyServer.replicas=3 \
  --set historyServer.resources.requests.cpu=200m \
  --set historyServer.resources.requests.memory=1Gi \
  --set historyServer.resources.limits.cpu=500m \
  --set historyServer.resources.limits.memory=2Gi \
  --reuse-values
```

### Шаг 4: Добавить Ingress (external access)

```bash
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts.historyServer=history-spark.company.com \
  --set ingress.annotations.'cert-manager\\.io/cluster-issuer'=letsencrypt-prod \
  --reuse-values
```

### Шаг 5: Настроить UI cleaner (опционально)

```bash
# Удалять старые приложения из UI (чтобы не перегружать)
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set historyServer.sparkConf.spark\\.history\\.cleaner.enabled=true \
  --set historyServer.sparkConf.spark\\.history\\.cleaner.interval=1d \
  --set historyServer.sparkConf.spark\\.history\\.cleaner.maxAge=7d \
  --reuse-values
```

## Verification

```bash
# 1. Проверить поды
kubectl get pods -n <namespace> -l app=history-server
# Ожидаем: 3/3 Ready

# 2. Проверить сервис
kubectl get svc -n <namespace> spark-41-history-server

# 3. Локальный доступ
kubectl port-forward -n <namespace> svc/spark-41-history-server 18080:18080
# Открыть: http://localhost:18080

# 4. Проверить Ingress (если настроен)
kubectl get ingress -n <namespace>
curl -I https://history-spark.company.com

# 5. Запустить тестовый job
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .remote('sc://spark-41-connect:15002') \
    .appName('history-server-test') \
    .getOrCreate()
spark.range(1000).count()
spark.stop()
"

# 6. Проверить что job появился в UI
# Через ~30 секунд обновить http://localhost:18080
```

## Configuration Options

### Ресурсы для production

```yaml
historyServer:
  replicas: 3
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "1"
      memory: "4Gi"
  sparkConf:
    spark.history.fs.logDirectory: "s3a://spark-logs/4.1/events"
    spark.history.provider: "org.apache.spark.deploy.history.FsHistoryProvider"
    spark.history.ui.maxApplications: "1000"
    spark.history.retainedApplications: "100"
```

### S3 lifecycle policy (автоочистка старых логов)

```bash
# Через AWS CLI
aws s3api put-bucket-lifecycle-configuration \
  --bucket spark-logs \
  --lifecycle-configuration file://lifecycle.json

# lifecycle.json:
{
  "Rules": [
    {
      "Id": "DeleteOldEventLogs",
      "Status": "Enabled",
      "Prefix": "4.1/events/",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
```

## Troubleshooting

```bash
# UI пустой - проверить logDirectory
kubectl exec -n <namespace> deploy/history-server -- \
  printenv | grep SPARK_HISTORY_OPTS

# Нет доступа к S3
kubectl exec -n <namespace> deploy/history-server -- \
  /opt/spark/bin/hdfs dfs -ls s3a://spark-logs/4.1/events

# Медленная загрузка UI
# Уменьшите spark.history.ui.maxApplications
# Или включите cleaner для удаления старых приложений
```

## References

- History Server Guide: `docs/guides/ru/spark-k8s-constructor.md`
- ISSUE-006: History log prefix missing
- Spark Monitoring: https://spark.apache.org/docs/latest/monitoring.html
