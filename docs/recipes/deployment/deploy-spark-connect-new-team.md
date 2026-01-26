# Deploy Spark Connect for New Team

**Source:** E2E matrix

## Overview

Развернуть Spark Connect для новой команды Data Science/Engineering с минимальной конфигурацией.

## Prerequisites

- Kubernetes кластер с доступом
- Helm 3.x
- Namespace создан (или будет создан автоматически)

## Deployment

### Шаг 1: Создать namespace

```bash
kubectl create namespace datascience-alpha
```

### Шаг 2: Создать preset

Используйте готовый preset `values-scenario-jupyter-connect-k8s.yaml` или создайте свой:

```bash
# Скопируйте preset
cp charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
   charts/spark-4.1/values-team-alpha.yaml

# Отредактируйте под нужды команды
vim charts/spark-4.1/values-team-alpha.yaml
```

### Шаг 3: Деплой

```bash
helm install spark-alpha charts/spark-4.1 \
  -n datascience-alpha \
  -f charts/spark-4.1/values-team-alpha.yaml \
  --create-namespace
```

### Шаг 4: Настроить внешние ресурсы (опционально)

```bash
# S3/MinIO credentials
kubectl create secret generic s3-credentials \
  -n datascience-alpha \
  --from-literal=access-key=<access-key> \
  --from-literal=secret-key=<secret-key>

# External Hive Metastore (если есть)
helm upgrade spark-alpha charts/spark-4.1 -n datascience-alpha \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://external-metastore:9083 \
  --reuse-values
```

## Verification

```bash
# 1. Проверить поды
kubectl get pods -n datascience-alpha
# Ожидаем: spark-alpha-spark-41-connect-*, jupyter-*

# 2. Проверить сервисы
kubectl get svc -n datascience-alpha
# Ожидаем: spark-41-connect, jupyter

# 3. Проверить Spark Connect
kubectl exec -n datascience-alpha deploy/spark-alpha-spark-41-connect -- \
  /opt/spark/bin/spark-submit --help

# 4. Открыть Jupyter
kubectl port-forward -n datascience-alpha svc/jupyter 8888:8888
# Открыть: http://localhost:8888

# 5. Тест из Jupyter
# В Jupyter notebook:
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-alpha-spark-41-connect:15002").getOrCreate()
df = spark.range(100).count()
print(f"Count: {df}")
spark.stop()
```

## Customization

### Изменить ресурсы

```bash
helm upgrade spark-alpha charts/spark-4.1 -n datascience-alpha \
  --set connect.resources.requests.cpu=2 \
  --set connect.resources.requests.memory=4Gi \
  --set connect.resources.limits.cpu=4 \
  --set connect.resources.limits.memory=8Gi \
  --reuse-values
```

### Включить History Server

```bash
helm upgrade spark-alpha charts/spark-4.1 -n datascience-alpha \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/teams/alpha/events \
  --reuse-values
```

### Настроить S3/MinIO

```bash
helm upgrade spark-alpha charts/spark-4.1 -n datascience-alpha \
  --set global.s3.endpoint=https://s3.company.com \
  --set global.s3.existingSecret=company-s3-credentials \
  --set connect.eventLog.dir=s3a://company-bucket/spark-logs/alpha/events \
  --set hiveMetastore.warehouseDir=s3a://company-bucket/warehouse/alpha \
  --reuse-values
```

## Troubleshooting

```bash
# Если поды не стартуют
kubectl describe pod -n datascience-alpha <pod-name>
kubectl logs -n datascience-alpha <pod-name>

# Если Connect недоступен
kubectl logs -n datascience-alpha deploy/spark-alpha-spark-41-connect

# Если Jupyter не может подключиться
kubectl exec -n datascience-alpha deploy/jupyter -- \
  curl -v http://spark-alpha-spark-41-connect:15002
```

## References

- Usage Guide: `docs/guides/ru/spark-k8s-constructor.md`
- E2E Report: `docs/testing/F06-e2e-matrix-report.md`
- Preset: `charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml`
