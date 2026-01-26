# Spark K8s Constructor — Быстрая справка

**Дата:** 2025-01-26
**Версия:** 0.1.0
**Spark:** 3.5.7, 4.1.0

> Краткая справка по командам, рецептам и пресетам Spark K8s Constructor

## Содержание

- [Helm команды](#helm-команды)
- [Управление компонентами](#управление-компонентами)
- [Траблшутинг](#траблшутинг)
- [Полезные kubectl команды](#полезные-kubectl-команды)
- [Переменные окружения](#переменные-окружения)
- [Индекс рецептов](#индекс-рецептов)
- [Каталог пресетов](#каталог-пресетов)

---

## Helm команды

### Базовые операции

```bash
# Установка Spark 4.1
helm install spark charts/spark-4.1 -n spark --create-namespace

# Установка Spark 3.5 Connect
helm install spark-connect charts/spark-3.5/charts/spark-connect -n spark

# Установка Spark 3.5 Standalone
helm install spark-standalone charts/spark-3.5/charts/spark-standalone -n spark

# Обновление релиза
helm upgrade spark charts/spark-4.1 -n spark

# Удаление
helm uninstall spark -n spark

# Проверка значений
helm get values spark -n spark
```

### Установка с пресетами

```bash
# Spark 4.1
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark

# Spark 3.5
helm install spark-connect charts/spark-3.5/charts/spark-connect \
  -f charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml \
  -n spark
```

### Оверрайд значений

```bash
# Включить компоненты
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set jupyter.enabled=true

# Настроить ресурсы
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.resources.requests.memory=2Gi \
  --set connect.resources.limits.memory=4Gi

# S3 конфигурация
helm upgrade spark charts/spark-4.1 -n spark \
  --set global.s3.endpoint=http://minio:9000 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin
```

### Валидация

```bash
# Локальная валидация (без установки)
helm template test charts/spark-4.1 -f values.yaml --dry-run

# Проверка пресетов
./scripts/validate-presets.sh

# Проверка политик безопасности
./scripts/validate-policy.sh
```

### Отладка

```bash
# Показать все значения
helm show values charts/spark-4.1

# Рендер манифестов в файл
helm template spark charts/spark-4.1 -n spark > rendered.yaml

# Рендер с отладкой
helm template spark charts/spark-4.1 -n spark --debug

# Статус релиза
helm status spark -n spark

# История релизов
helm history spark -n spark
```

---

## Управление компонентами

### Spark Connect Server

```bash
# Включить/выключить
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.enabled=true

# Backend mode: k8s (динамические executors)
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.backendMode=k8s

# Backend mode: standalone (фиксированный кластер)
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-sa-spark-standalone-master

# Backend mode: operator (Spark Operator)
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.backendMode=operator
```

### Spark Standalone

```bash
# Spark 3.5 - Master + Workers
helm install spark-standalone charts/spark-3.5/charts/spark-standalone \
  -n spark \
  --set sparkMaster.enabled=true \
  --set sparkWorker.replicas=3

# Spark 4.1 - через Connect
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set standalone.enabled=true
```

### History Server

```bash
# Включить
helm upgrade spark charts/spark-4.1 -n spark \
  --set historyServer.enabled=true

# Настроить event log
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.eventLog.enabled=true \
  --set connect.eventLog.dir=s3a://spark-logs/4.1/events
```

### Jupyter

```bash
# Включить
helm upgrade spark charts/spark-4.1 -n spark \
  --set jupyter.enabled=true

# Установить URL для Connect
helm upgrade spark charts/spark-4.1 -n spark \
  --set jupyter.env.SPARK_CONNECT_URL=sc://spark-connect:15002
```

---

## Траблшутинг

### Драйвер не запускается

```bash
# Проверить логи драйвера
kubectl logs -n spark spark-driver-xxx -c spark-kubernetes-driver

# Описать под драйвера
kubectl describe pod -n spark spark-driver-xxx

# Проверить события
kubectl get events -n spark --sort-by='.lastTimestamp'

# Диагностический скрипт
./scripts/recipes/troubleshoot/check-driver-logs.sh spark
```

### Проблемы с S3/MinIO

```bash
# Проверить подключение
./scripts/recipes/troubleshoot/test-s3-connection.sh spark

# Проверить секрет
kubectl get secret -n spark s3-credentials -o yaml

# Протестировать из пода
kubectl exec -n spark spark-connect-0 -- curl -sf http://minio:9000/minio/health/live
```

### Проблемы с памятью (OOM)

```bash
# Найти OOMKilled поды
./scripts/recipes/troubleshoot/check-executor-logs.sh spark

# Увеличить память executor
helm upgrade spark charts/spark-4.1 -n spark \
  --set connect.sparkConf.'spark.executor.memory'=4g \
  --set connect.sparkConf.'spark.executor.memoryOverhead'=1g
```

### History Server пустой

```bash
# Проверить event log
kubectl exec -n spark spark-history-server-0 -- ls -la /spark-events

# Проверить конфигурацию
kubectl logs -n spark spark-history-server-0

# См. рецепт
cat docs/recipes/troubleshoot/history-server-empty.md
```

### Проблемы с RBAC

```bash
# Проверить права
./scripts/recipes/troubleshoot/check-rbac.sh spark spark

# Тест can-i
kubectl auth can-i create pods -n spark \
  --as=system:serviceaccount:spark:spark
```

---

## Полезные kubectl команды

### Работа с подами

```bash
# Список всех Spark подов
kubectl get pods -n spark -l 'app in (spark-connect,spark-standalone)'

# Driver поды
kubectl get pods -n spark -l spark-role=driver

# Executor поды
kubectl get pods -n spark -l spark-role=executor

# Поды с ошибками
kubectl get pods -n spark | grep -E '(Error|CrashLoopBackOff|OOMKilled)'

# Логи (последние 100 строк)
kubectl logs -n spark <pod> --tail=100

# Следить за логами
kubectl logs -n spark <pod> -f

# Логи всех контейнеров
kubectl logs -n spark <pod> --all-containers=true
```

### Port Forwarding

```bash
# Spark UI (драйвер на 4040)
kubectl port-forward -n spark <driver-pod> 4040:4040

# Spark Connect (15002)
kubectl port-forward -n spark svc/spark-connect 15002:15002

# Jupyter (8888)
kubectl port-forward -n spark svc/jupyter 8888:8888

# History Server (18080)
kubectl port-forward -n spark svc/spark-history-server 18080:18080

# MinIO Console (9001)
kubectl port-forward -n spark svc/minio 9001:9001
```

### Сервисы и эндпоинты

```bash
# Все сервисы
kubectl get svc -n spark

# Эндпоинты сервиса
kubectl get endpoints -n spark spark-connect

# Ingress
kubectl get ingress -n spark
```

### Конфигурация

```bash
# ConfigMap
kubectl get cm -n spark spark-connect-configmap -o yaml

# Секреты
kubectl get secrets -n spark

# Показать развернутый ConfigMap
kubectl get cm -n spark spark-connect-configmap -o jsonpath='{.data.spark-defaults\.conf}' | jq -r .
```

---

## Переменные окружения

### Spark Connect

| Переменная | Описание |
|-----------|----------|
| `SPARK_CONNECT_URL` | URL Spark Connect (sc://host:port) |
| `SPARK_REMOTE` | Алиас для SPARK_CONNECT_URL |
| `SPARK_HOME` | Путь к Spark |

### S3/MinIO

| Переменная | Описание |
|-----------|----------|
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |
| `SPARK_S3_ACCESS_KEY` | Spark S3 access key |
| `SPARK_S3_SECRET_KEY` | Spark S3 secret key |
| `SPARK_S3_ENDPOINT` | S3 endpoint URL |

### Hive Metastore

| Переменная | Описание |
|-----------|----------|
| `HIVE_METASTORE_URIS` | Metastore thrift URIs |
| `HIVE_METASTORE_WAREHOUSE_DIR` | Warehouse location |

---

## Индекс рецептов

### Operations (B) — Операции

| Рецепт | Описание |
|--------|----------|
| [configure-event-log-prefix.md](../recipes/operations/configure-event-log-prefix.md) | Настройка event log для MinIO |
| [enable-event-log-41.md](../recipes/operations/enable-event-log-41.md) | Event log для Spark 4.1 |
| [initialize-metastore.md](../recipes/operations/initialize-metastore.md) | Инициализация Hive Metastore |

### Troubleshooting (D) — Диагностика

| Рецепт | Описание |
|--------|----------|
| [s3-connection-failed.md](../recipes/troubleshoot/s3-connection-failed.md) | Проблемы с S3/MinIO |
| [history-server-empty.md](../recipes/troubleshoot/history-server-empty.md) | History Server не показывает задачи |
| [properties-syntax.md](../recipes/troubleshoot/properties-syntax.md) | Синтаксис Spark properties |
| [compression-library-missing.md](../recipes/troubleshoot/compression-library-missing.md) | Отсутствие библиотек сжатия |
| [driver-not-starting.md](../recipes/troubleshoot/driver-not-starting.md) | Драйвер не запускается |
| [driver-host-resolution.md](../recipes/troubleshoot/driver-host-resolution.md) | FQDN резолюция драйвера |
| [helm-installation-label-validation.md](../recipes/troubleshoot/helm-installation-label-validation.md) | Ошибка валидации "N/A" label (ISSUE-030) |
| [s3-credentials-secret-missing.md](../recipes/troubleshoot/s3-credentials-secret-missing.md) | Отсутствует секрет s3-credentials (ISSUE-031) |
| [connect-crashloop-rbac-configmap.md](../recipes/troubleshoot/connect-crashloop-rbac-configmap.md) | RBAC permission для ConfigMaps (ISSUE-032/033) |
| [jupyter-python-dependencies-missing.md](../recipes/troubleshoot/jupyter-python-dependencies-missing.md) | Отсутствуют Python зависимости (ISSUE-034) |

### Deployment (A) — Развертывание

| Рецепт | Описание |
|--------|----------|
| [deploy-spark-connect-new-team.md](../recipes/deployment/deploy-spark-connect-new-team.md) | Развертывание для новой команды |
| [migrate-standalone-to-k8s.md](../recipes/deployment/migrate-standalone-to-k8s.md) | Миграция Standalone → K8s |
| [add-history-server-ha.md](../recipes/deployment/add-history-server-ha.md) | Настройка HA для History Server |
| [setup-resource-quotas.md](../recipes/deployment/setup-resource-quotas.md) | Настройка квот ресурсов |

### Integration (C) — Интеграции

| Рецепт | Описание |
|--------|----------|
| [airflow-spark-connect.md](../recipes/integration/airflow-spark-connect.md) | Интеграция с Airflow |
| [mlflow-spark-connect.md](../recipes/integration/mlflow-spark-connect.md) | MLflow эксперименты |
| [external-hive-metastore.md](../recipes/integration/external-hive-metastore.md) | Внешний Metastore |
| [kerberos-authentication.md](../recipes/integration/kerberos-authentication.md) | Kerberos аутентификация |
| [prometheus-monitoring.md](../recipes/integration/prometheus-monitoring.md) | Мониторинг через Prometheus |

---

## Каталог пресетов

### Spark 4.1 Presets

| Пресет | Описание | Компоненты |
|--------|----------|------------|
| `values-scenario-jupyter-connect-k8s.yaml` | Jupyter + Connect + K8s backend | Connect, Jupyter |
| `values-scenario-jupyter-connect-standalone.yaml` | Jupyter + Connect + Standalone | Connect, Jupyter, Standalone |
| `values-scenario-airflow-connect-k8s.yaml` | Airflow + Connect + K8s backend | Connect, Airflow |
| `values-scenario-airflow-connect-standalone.yaml` | Airflow + Connect + Standalone | Connect, Airflow, Standalone |
| `values-scenario-airflow-k8s-submit.yaml` | Airflow + K8s submit mode | Airflow |
| `values-scenario-airflow-operator.yaml` | Airflow + Spark Operator | Airflow, Operator |

### Spark 3.5 Presets

#### Spark Connect

| Пресет | Описание | Компоненты |
|--------|----------|------------|
| `values-scenario-jupyter-connect-k8s.yaml` | Jupyter + Connect + K8s | Connect, Jupyter |
| `values-scenario-jupyter-connect-standalone.yaml` | Jupyter + Connect + Standalone | Connect, Jupyter, Standalone |

#### Spark Standalone

| Пресет | Описание | Компоненты |
|--------|----------|------------|
| `values-scenario-airflow-connect.yaml` | Airflow + Standalone | Standalone, Airflow |
| `values-scenario-airflow-k8s-submit.yaml` | Airflow + K8s submit | Airflow |
| `values-scenario-airflow-operator.yaml` | Airflow + Operator | Airflow |

---

## Быстрые команды копирования

```bash
# Копирование локального скрипта в под
kubectl cp ./script.py spark-driver-xxx:/tmp/script.py -n spark

# Копирование из пода
kubectl cp spark-driver-xxx:/tmp/output.csv ./output.csv -n spark

# Исполнение в поде
kubectl exec -n spark spark-connect-0 -- python -c "print('test')"

# Интерактивная оболочка
kubectl exec -n spark spark-connect-0 -it -- /bin/bash

# Редактор ConfigMap в vi
kubectl edit cm -n spark spark-connect-configmap
```

---

## Полезные ссылки

- [Полное руководство](./spark-k8s-constructor.md)
- [Архитектура](../architecture/spark-k8s-charts.md)
- [План реализации](../plans/2025-01-25-spark-k8s-builder-impl.md)
- [Spark Documentation](https://spark.apache.org/docs/latest/)
