# Spark K8s Constructor: Руководство для DataOps

**Дата:** 2025-01-26
**Версия:** 0.1.0
**Spark:** 3.5.7, 4.1.0

---

## Обзор

Данный конструктор представляет собой набор модульных Helm чартов для развёртывания Apache Spark в Kubernetes. Компоненты можно комбинировать как LEGO-блоки для создания оптимальной конфигурации под конкретные нужды команды.

**Две архитектуры:**
- **Spark 3.5:** Модульные subcharts (spark-base, spark-connect, spark-standalone)
- **Spark 4.1:** Единый чарт с toggle-flags

---

## Содержание

1. [LEGO-блоки](#lego-блоки)
2. [Быстрый старт](#быстрый-старт)
3. [Preset каталог](#preset-каталог)
4. [Использование --set флагов](#использование-set-флагов)
5. [Operations рецепты](#operations-рецепты)
6. [Troubleshooting рецепты](#troubleshooting-рецепты)
7. [Deployment рецепты](#deployment-рецепты)
8. [Integration рецепты](#integration-рецепты)
9. [History Server](#history-server-полное-руководство)

---

## LEGO-блоки

### Spark 3.5 (модульные чарты)

```
charts/spark-3.5/charts/
├── spark-base/          # Базовый образ, общие конфиги
├── spark-connect/       # Spark Connect server
└── spark-standalone/    # Master/Workers + Airflow + MLflow
```

### Spark 4.1 (единый чарт)

```
charts/spark-4.1/
├── templates/
│   ├── spark-connect.yaml
│   ├── hive-metastore.yaml
│   ├── history-server.yaml
│   ├── jupyter.yaml
│   └── ...
└── values.yaml          # Все компоненты в одном файле
```

### Компоненты

| Компонент | Для кого | Зачем |
|-----------|----------|-------|
| spark-connect | Data Scientists, Engineers | Интерактивная работа, удалённые job'ы |
| spark-standalone | Data Engineers | Batch обработка, Airflow DAGs |
| hive-metastore | Все | Метаданные таблиц |
| history-server | DataOps, Engineers | Мониторинг выполненных job'ов |
| jupyter | Data Scientists | Нотебуки с Remote Spark |
| airflow | Data Engineers | Оркестрация пайплайнов |
| mlflow | Data Scientists | Experiment tracking |
| minio | Dev/Test | S3-совместимое хранилище |

---

## Быстрый старт

### Сценарий: Запуск Spark Connect для команды Data Science

**Шаг 1: Выберите чарт**
```bash
# Для Spark 3.5
cd charts/spark-3.5/charts/spark-connect

# Для Spark 4.1
cd charts/spark-4.1
```

**Шаг 2: Скопируйте preset**
```bash
# Spark 3.5
cp values.yaml values-datascience-dev.yaml

# Spark 4.1
cp values.yaml values-datascience-dev.yaml
```

**Шаг 3: Адаптируйте под команду**
```yaml
# values-datascience-dev.yaml
connect:
  enabled: true
  replicas: 1
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2"

hiveMetastore:
  enabled: true

jupyter:
  enabled: true
  env:
    SPARK_CONNECT_URL: "sc://spark-connect:15002"

historyServer:
  enabled: true
```

**Шаг 4: Валидация**
```bash
helm template spark-datascience . -f values-datascience-dev.yaml --dry-run
```

**Шаг 5: Деплой**
```bash
helm install spark-datascience . -f values-datascience-dev.yaml --namespace datascience
```

**Шаг 6: Проверка**
```bash
# Проверить поды
kubectl get pods -n datascience

# Проверить Spark Connect
kubectl exec -n datascience deploy/spark-connect -- /opt/spark/bin/spark-submit --help

# Открыть Jupyter
kubectl port-forward -n datascience svc/jupyter 8888:8888
```

---

## Preset каталог

### Существующие пресеты

| Preset | Файл | Версия | Размер | Компоненты |
|--------|-------|--------|--------|------------|
| Prod-like | `spark-standalone/values-prod-like.yaml` | 3.5 | Medium | Standalone + Airflow + MinIO + PSS |
| Common | `charts/values-common.yaml` | - | - | Общие значения |

### Тестируемые сценарии

| Сценарий | Тест | Backend | Компоненты |
|----------|------|---------|------------|
| Jupyter + Connect + K8s | `test-e2e-jupyter-connect.sh` | k8s | Jupyter + Connect + MinIO |
| Jupyter + Connect + Standalone | `test-e2e-jupyter-connect.sh` | standalone | Jupyter + Connect + Standalone + MinIO |
| Airflow + Connect + K8s | `test-e2e-airflow-connect.sh` | k8s | Airflow + Connect + MinIO |
| Airflow + Connect + Standalone | `test-e2e-airflow-connect.sh` | standalone | Airflow + Connect + Standalone + MinIO |
| Airflow + K8s submit | `test-e2e-airflow-k8s-submit.sh` | - | Airflow + MinIO |
| Airflow + Operator | `test-e2e-airflow-operator.sh` | operator | Airflow + Spark Operator + MinIO |

### Планируемые пресеты

```
charts/spark-4.1/
├── values-scenario-jupyter-connect-k8s.yaml
├── values-scenario-jupyter-connect-standalone.yaml
├── values-scenario-airflow-connect-k8s.yaml
├── values-scenario-airflow-connect-standalone.yaml
├── values-scenario-airflow-k8s-submit.yaml
└── values-scenario-airflow-operator.yaml
```

---

## Использование --set флагов

### Паттерн: Тестовые скрипты как референс

**Шаг 1: Находим нужный тест-сценарий**

```bash
# Data Science: Jupyter + Connect
scripts/test-e2e-jupyter-connect.sh

# Data Engineering: Airflow + Connect
scripts/test-e2e-airflow-connect.sh

# Data Engineering: Airflow + K8s submit
scripts/test-e2e-airflow-k8s-submit.sh

# Data Engineering: Airflow + Spark Operator
scripts/test-e2e-airflow-operator.sh
```

**Шаг 2: Извлекаем helm команду**

```bash
# Смотрим в скрипт для 4.1
grep -A 30 "helm upgrade --install" scripts/test-e2e-jupyter-connect.sh
```

**Шаг 3: Деплой (пример для Jupyter + Connect)**

```bash
NAMESPACE="datascience"
RELEASE="spark-datascience"

helm upgrade --install "${RELEASE}" charts/spark-4.1 -n "${NAMESPACE}" \
  --set connect.enabled=true \
  --set connect.backendMode=k8s \
  --set connect.image.tag=4.1.0 \
  --set connect.resources.requests.cpu=1 \
  --set connect.resources.requests.memory=2Gi \
  --set connect.resources.limits.cpu=2 \
  --set connect.resources.limits.memory=4Gi \
  --set jupyter.enabled=true \
  --set jupyter.env.SPARK_CONNECT_URL="sc://spark-datascience-spark-41-connect:15002" \
  --set hiveMetastore.enabled=true \
  --set historyServer.enabled=true \
  --set spark-base.minio.enabled=true \
  --create-namespace
```

---

## Operations рецепты

### Увеличение памяти драйверу

```bash
# Проблема: driver OOM
# Симптомы: kubectl logs spark-driver-xxx показывает java.lang.OutOfMemoryError

# Решение для Spark 4.1 + K8s backend
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.driver.memory=4g \
  --set connect.driver.memoryOverhead=1g \
  --set connect.resources.limits.memory=5g

# Решение для Spark 3.5 + Standalone
helm upgrade spark-standalone charts/spark-3.5/charts/spark-standalone -n prod \
  --set sparkMaster.sparkConf.spark\\.driver\\.memory=4g \
  --set sparkMaster.sparkConf.spark\\.driver\\.memoryOverhead=1g
```

### Настройка eventLog для History Server

```bash
# Проблема: History Server не видит логи
# Симптомы: пустая страница http://history-server:18080

# Решение
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --set spark-base.minio.enabled=true
```

### Изменение количества executors

```bash
# Проблема: job слишком медленный
# Решение для K8s backend
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.dynamicAllocation.minExecutors=2 \
  --set connect.dynamicAllocation.maxExecutors=20

# Решение для Standalone backend (fixed instances)
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.sparkConf.spark\\.executor\\.instances=10
```

---

## Troubleshooting рецепты

### Executor OOM Killed

```bash
# Симптомы:
kubectl get pods -n datascience
# spark-executor-xxx    0/1     OOMKilled

# Диагностика:
kubectl logs spark-executor-xxx -n datascience | grep -i "out of memory"
kubectl describe pod spark-executor-xxx -n datascience | grep -A 5 "OOMKilled"

# Решение:
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.executor.memory=1g \
  --set connect.executor.memoryOverhead=512m \
  --set connect.executor.memoryLimit=2g
```

### Driver не стартует

```bash
# Симптомы:
kubectl get pods -n datascience
# spark-connect-xxx    0/1     CrashLoopBackOff

kubectl logs spark-connect-xxx -n datascience
# Error: Could not connect to driver

# Решение для K8s backend:
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.driver.host=spark-datascience-spark-41-connect

# Решение для Standalone backend:
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.driver.host=$(kubectl get svc -n datascience spark-standalone-master -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

### S3 connection failed

```bash
# Симптомы:
kubectl logs spark-executor-xxx -n datascience
# Caused by: com.amazonaws.AmazonClientException: Unable to execute HTTP request

# Диагностика:
kubectl exec -n datascience deploy/spark-connect -- \
  curl -v http://minio:9000/minio/health/live

# Решение:
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set global.s3.endpoint=http://minio:9000 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --set global.s3.pathStyleAccess=true
```

### Job hangs/stuck

```bash
# Симптомы: Spark UI показывает Running но ничего не происходит

# Диагностика:
kubectl logs spark-executor-xxx -n datascience --tail=100 | grep -i "heartbeats"

# Частая причина: network policies
kubectl get networkpolicies -n datascience

# Решение: добавить network policy для executors
cat <<EOF | kubectl apply -n datascience -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: spark-executors
spec:
  podSelector:
    matchLabels:
      spark-role: executor
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          spark-role: driver
    ports:
    - protocol: TCP
      port: 7078
EOF
```

---

## Deployment рецепты

### Развернуть Spark Connect для новой команды

```bash
# 1. Создаем namespace
kubectl create namespace datascience-alpha

# 2. Деплой
helm upgrade --install spark-alpha charts/spark-4.1 -n datascience-alpha \
  --set connect.enabled=true \
  --set connect.backendMode=k8s \
  --set connect.image.tag=4.1.0 \
  --set connect.replicas=1 \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/teams/alpha/events \
  --set jupyter.enabled=true \
  --set jupyter.env.SPARK_CONNECT_URL="sc://spark-alpha-spark-41-connect:15002" \
  --set hiveMetastore.enabled=true \
  --set hiveMetastore.warehouseDir=s3a://warehouse/teams/alpha \
  --set historyServer.enabled=true \
  --set global.s3.endpoint=https://s3.company.com \
  --set global.s3.existingSecret=company-s3-credentials \
  --create-namespace

# 3. Проверка
kubectl wait --for=condition=ready pod -n datascience-alpha -l app=spark-connect --timeout=300s
```

### Миграция с Standalone на K8s backend

```bash
# 1. Backup текущей конфигурации
helm get values spark-prod -n prod > prod-backup-$(date +%Y%m%d).yaml

# 2. Switch backend mode
helm upgrade spark-prod charts/spark-4.1 -n prod \
  --set connect.backendMode=k8s \
  --set connect.dynamicAllocation.enabled=true \
  --set connect.dynamicAllocation.minExecutors=2 \
  --set connect.dynamicAllocation.maxExecutors=50 \
  --reuse-values

# 3. Отключаем standalone (если не нужен)
helm -n prod uninstall spark-standalone-master spark-standalone-worker
```

### Настройка resource quotas

```bash
cat <<EOF | kubectl apply -n datascience-alpha -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: spark-compute-resources
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 40Gi
    limits.cpu: "20"
    limits.memory: 80Gi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: spark-limits
spec:
  limits:
  - max:
      cpu: "4"
      memory: 16Gi
    min:
      cpu: "100m"
      memory: 256Mi
    default:
      cpu: "500m"
      memory: 2Gi
    defaultRequest:
      cpu: "100m"
      memory: 512Mi
    type: Container
EOF
```

---

## Integration рецепты

### Airflow → Spark Connect

```bash
# 1. Установка Airflow со Spark provider
helm upgrade --install airflow charts/spark-3.5/charts/spark-standalone \
  -n airflow \
  --set airflow.enabled=true \
  --set airflow.sparkConnect.enabled=true \
  --set airflow.sparkConnect.url=sc://spark-datascience-spark-41-connect.datascience.svc.cluster.local:15002

# 2. Пример DAG
from airflow import DAG
from airflow.providers.spark.operators.spark_submit import SparkSubmitOperator

dag = DAG('spark_connect_job', start_date=datetime(2025, 1, 1))

spark_job = SparkSubmitOperator(
    task_id='spark_etl',
    application='s3a://dags/scripts/etl.py',
    conn_id='spark_connect_default',
    conf={'spark.executor.instances': '5'},
    dag=dag
)
```

### MLflow → Spark Connect

```bash
# 1. Установить MLflow
helm install mlflow charts/spark-3.5/charts/spark-standalone \
  -n mlflow \
  --set mlflow.enabled=true

# 2. Настроить Spark Connect с MLflow tracking
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.sparkConf.spark\\.extraListeners=org.apache.spark.mlflow.MLflowExecutionListener \
  --set connect.sparkConf.spark\\.mlflow.trackingUri=http://mlflow.mlflow.svc.cluster.local:5000 \
  --reuse-values
```

### Внешний Hive Metastore

```bash
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://company-hive-metastore.prod.svc.cluster.local:9083 \
  --set connect.sparkConf.spark\\.sql\\.warehouseDir=s3a://warehouse/company \
  --reuse-values
```

### Kerberos аутентификация

```bash
# 1. Создать Kerberos secret
kubectl create secret generic spark-kerberos \
  --from-file=krb5.conf=/etc/krb5.conf \
  --from-file=user.keytab=/path/to/keytab \
  -n datascience

# 2. Настроить Spark Connect
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.sparkConf.spark\\.authenticate=true \
  --set connect.sparkConf.spark\\.keytab=/etc/secrets/user.keytab \
  --set connect.sparkConf.spark\\.principal=user@COMPANY.COM \
  --set connect.extraVolumes[0].name=kerberos \
  --set connect.extraVolumes[0].secret.secretName=spark-kerberos \
  --set connect.extraVolumeMounts[0].name=kerberos \
  --set connect.extraVolumeMounts[0].mountPath=/etc/secrets \
  --reuse-values
```

---

## History Server: Полное руководство

### Что такое History Server

Web UI для просмотра завершённых Spark job'ов. Показывает:
- DAG выполнения (stages, tasks)
- Метрики (execution time, data read/written)
- Logs (driver и executor logs)
- Configuration

### Как это работает

```
Spark Job → Event Log (S3/MinIO) ← History Server читает
              ↓
         s3a://spark-logs/4.1/events/
              ↓
         History Server UI: http://history-server:18080
```

### Настройка eventLog и History Server

```bash
# 1. Включаем eventLog для Spark Connect
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events \
  --set connect.eventLog.compress=true \
  --reuse-values

# 2. Деплоим History Server
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory=s3a://spark-logs/4.1/events \
  --set historyServer.resources.requests.memory=1Gi \
  --set historyServer.resources.limits.memory=2Gi \
  --reuse-values

# 3. Проверка
kubectl port-forward -n datascience svc/spark-41-history-server 18080:18080
# Открыть: http://localhost:18080
```

### Troubleshooting: History Server не показывает job'ы

```bash
# Диагностика 1: Проверить что eventLog включён
kubectl exec -n datascience deploy/spark-connect -- \
  printenv | grep EVENTLOG

# Диагностика 2: Проверить что файлы пишутся в S3
kubectl exec -n datascience deploy/spark-connect -- \
  /opt/spark/bin/hdfs dfs -ls s3a://spark-logs/4.1/events/

# Диагностика 3: Проверить логи History Server
kubectl logs -n datascience deploy/spark-41-history-server | grep -i "error"

# Диагностика 4: Проверить подключение к S3
kubectl exec -n datascience deploy/spark-41-history-server -- \
  /opt/spark/bin/hdfs dfs -ls s3a://spark-logs/4.1/events/

# Решение: добавить secret для History Server
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set global.s3.existingSecret=s3-credentials \
  --reuse-values
```

### Просмотр логов конкретного job

```bash
# 1. Открыть History Server
kubectl port-forward -n datascience svc/spark-41-history-server 18080:18080

# 2. Найти job в списке

# 3. Или найти через S3 напрямую
kubectl exec -n datascience deploy/spark-connect -- \
  /opt/spark/bin/hdfs dfs -ls -h s3a://spark-logs/4.1/events/ | tail -20

# 4. Скачать конкретный log для анализа
kubectl exec -n datascience deploy/spark-connect -- \
  /opt/spark/bin/hdfs dfs -get s3a://spark-logs/4.1/events/app-20250125123456-0001.tgz /tmp/
```

### Оптимизация для Production

```bash
# 1. Сжатие event logs
helm upgrade spark-prod charts/spark-4.1 -n prod \
  --set connect.eventLog.compress=true \
  --set connect.eventLog.fs.s3a.fast.upload=true \
  --reuse-values

# 2. Кастомный UI cleaner
helm upgrade spark-prod charts/spark-4.1 -n prod \
  --set historyServer.sparkConf.spark\\.history\\.cleaner.enabled=true \
  --set historyServer.sparkConf.spark\\.history\\.cleaner.interval=1d \
  --set historyServer.sparkConf.spark\\.history\\.cleaner.maxAge=7d \
  --reuse-values
```

### Ingress для внешнего доступа

```bash
helm upgrade spark-datascience charts/spark-4.1 -n datascience \
  --set ingress.enabled=true \
  --set ingress.hosts.historyServer=history-spark.company.com \
  --set ingress.className=nginx \
  --reuse-values
```

---

## Полезные ссылки

- **E2E тесты:** `docs/testing/F06-e2e-matrix-report.md`
- **Issues:** `docs/issues/`
- **Architecture:** `docs/architecture/spark-k8s-charts.md`
- **Implementation:** `docs/plans/2025-01-25-spark-k8s-builder-impl.md`
