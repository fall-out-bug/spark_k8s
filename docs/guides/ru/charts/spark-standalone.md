# Гайд по чарту Spark Standalone

**Чарт:** `charts/spark-standalone`  
**Тестировалось на:** Minikube  
**Подготовлено для:** Ограничений OpenShift (PSS `restricted` / SCC `restricted`)

## Обзор

Разворачивает кластер **Spark Standalone** (master + workers) с опциональными Airflow, MLflow, MinIO, Hive Metastore и External Shuffle Service.

### Что разворачивается

- **Spark Master** — Координатор кластера (порт 7077)
- **Spark Workers** — Узлы executor (настраиваемое количество реплик)
- **External Shuffle Service** — Стабильная подача shuffle данных (опционально)
- **Airflow** — Оркестрация workflow с KubernetesExecutor (опционально)
- **MLflow** — Сервер отслеживания ML lifecycle (опционально)
- **MinIO** — S3-совместимое объектное хранилище (опционально)
- **Hive Metastore** — Репозиторий метаданных для таблиц Spark SQL (опционально)

## Быстрый старт

### Требования

- Кластер Kubernetes (Minikube/k3s для локального использования)
- `kubectl`, `helm`
- Docker образ `spark-custom:3.5.7` доступен кластеру

### Установка

```bash
# Создание namespace
kubectl create namespace spark-sa

# Установка с настройками по умолчанию
helm install spark-standalone charts/spark-standalone -n spark-sa

# Или с общим overlay значений
helm install spark-standalone charts/spark-standalone -n spark-sa \
  -f charts/values-common.yaml

# Или с prod-like профилем (тестировалось на Minikube)
helm install spark-standalone charts/spark-standalone -n spark-sa \
  -f charts/spark-standalone/values-prod-like.yaml
```

### Проверка

```bash
# Ожидание готовности master
kubectl wait --for=condition=ready pod -l app=spark-master -n spark-sa --timeout=120s

# Проверка статуса
kubectl get pods -n spark-sa
```

### Доступ

- **Spark Master UI:** `kubectl port-forward svc/spark-standalone-master 8080:8080 -n spark-sa` → http://localhost:8080
- **Airflow UI:** `kubectl port-forward svc/spark-standalone-airflow-webserver 8080:8080 -n spark-sa` → http://localhost:8080 (admin / admin)
- **MLflow UI:** `kubectl port-forward svc/spark-standalone-mlflow 5000:5000 -n spark-sa` → http://localhost:5000
- **MinIO Console:** `kubectl port-forward svc/spark-standalone-minio 9001:9001 -n spark-sa` → http://localhost:9001 (minioadmin / minioadmin)

## Ключевые параметры конфигурации

### Топ-10 параметров для понимания

1. **`sparkMaster.enabled`** — Включить Spark Master (по умолчанию: `true`)
2. **`sparkMaster.ha.enabled`** — Включить High Availability (восстановление на PVC) (по умолчанию: `false`)
3. **`sparkWorker.replicas`** — Количество worker подов (по умолчанию: `2`)
4. **`sparkWorker.memory`** — Память на worker (по умолчанию: `"2g"`)
5. **`airflow.enabled`** — Включить Airflow (по умолчанию: `true`)
6. **`airflow.fernetKey`** — Общий Fernet ключ для Variables/Connections (обязателен, если Airflow включён)
7. **`mlflow.enabled`** — Включить MLflow (по умолчанию: `true`)
8. **`minio.enabled`** — Включить MinIO (по умолчанию: `true`)
9. **`s3.endpoint`** — URL S3 endpoint (по умолчанию: `"http://minio:9000"`)
10. **`security.podSecurityStandards`** — Включить PSS hardening (по умолчанию: `true`)

### Пример: Включение HA и масштабирование workers

```yaml
# my-values.yaml
sparkMaster:
  ha:
    enabled: true
    persistence:
      enabled: true
      size: 1Gi

sparkWorker:
  replicas: 5
  memory: "4g"
```

```bash
helm upgrade spark-standalone charts/spark-standalone -n spark-sa -f my-values.yaml
```

## Values Overlays

См. [`docs/guides/en/overlays/`](../../en/overlays/) для готовых overlays:
- `values-anyk8s.yaml` — Базовый профиль для любого Kubernetes
- `values-sa-prodlike.yaml` — Prod-like профиль (тестировалось на Minikube, ссылается на `charts/spark-standalone/values-prod-like.yaml`)

**Примечание:** Overlays одинаковы для EN и RU; используйте файлы из `docs/guides/en/overlays/`.

## Smoke-тесты

Репозиторий предоставляет smoke-скрипты:

### Spark Standalone E2E

```bash
# Тест здоровья кластера Spark + задание SparkPi
./scripts/test-spark-standalone.sh <namespace> <release-name>

# Пример:
./scripts/test-spark-standalone.sh spark-sa spark-standalone
```

**Ожидается:** Задание SparkPi завершается успешно, workers регистрируются у master.

### Тесты Airflow DAG

```bash
# Тест DAG Airflow (example + ETL)
./scripts/test-prodlike-airflow.sh <namespace> <release-name>

# Пример:
./scripts/test-prodlike-airflow.sh spark-sa-prodlike spark-prodlike
```

**Ожидается:** DAG достигают состояния `success`.

**Airflow Variables:**
Тестовый скрипт автоматически устанавливает требуемые Airflow Variables для DAG:
- `spark_image` — Docker образ Spark (по умолчанию: `spark-custom:3.5.7`)
- `spark_namespace` — Kubernetes namespace для заданий Spark (по умолчанию: аргумент namespace скрипта)
- `spark_standalone_master` — URL Spark Master (по умолчанию: `spark://<release>-spark-standalone-master:7077`)
- `s3_endpoint` — URL S3 endpoint (по умолчанию: `http://minio:9000`)
- `s3_access_key` — S3 access key (из секрета `s3-credentials`, если доступен)
- `s3_secret_key` — S3 secret key (из секрета `s3-credentials`, если доступен)

Для переопределения значений по умолчанию установите переменные окружения перед запуском скрипта:
```bash
export SPARK_NAMESPACE_VALUE=my-namespace
export SPARK_MASTER_VALUE=spark://custom-master:7077
export S3_ENDPOINT_VALUE=http://custom-s3:9000
./scripts/test-prodlike-airflow.sh spark-sa-prodlike spark-prodlike
```

См. [`docs/guides/ru/validation.md`](../validation.md) для полного справочника переменных окружения.

### Комбинированный smoke (рекомендуется)

```bash
# Запуск всех тестов (Spark E2E + Airflow)
./scripts/test-sa-prodlike-all.sh <namespace> <release-name>

# Пример:
./scripts/test-sa-prodlike-all.sh spark-sa-prodlike spark-prodlike
```

**Ожидается:** Все проверки проходят.

## Устранение неполадок

### Workers не регистрируются

**Проверка:**
```bash
# Логи master
kubectl logs deploy/spark-standalone-master -n spark-sa | grep -i worker

# Логи worker
kubectl logs deploy/spark-standalone-worker -n spark-sa
```

**Решение:** Проверьте, что `sparkMaster.service.ports.spark: 7077` и worker может достичь сервиса master.

### Airflow Variables не расшифровываются

**Симптом:** `ERROR - Can't decrypt _val for key=...`

**Решение:** Установите `airflow.fernetKey` в общее значение для всех подов Airflow. Сгенерируйте с помощью:
```bash
python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

### DAG Airflow падают из-за отсутствующих переменных

**Симптом:** DAG падают с ошибками типа `Variable spark_namespace not found` или неправильный URL Spark Master.

**Решение:** Убедитесь, что Airflow Variables установлены. Тестовый скрипт (`test-prodlike-airflow.sh`) автоматически заполняет их, но для ручного запуска:
```bash
# Установка переменных через Airflow CLI (в поде scheduler)
kubectl exec -n <namespace> <scheduler-pod> -- \
  airflow variables set spark_namespace <namespace>
kubectl exec -n <namespace> <scheduler-pod> -- \
  airflow variables set spark_standalone_master spark://<release>-spark-standalone-master:7077
kubectl exec -n <namespace> <scheduler-pod> -- \
  airflow variables set s3_endpoint http://minio:9000
# ... (установите другие требуемые переменные)
```

См. исходные файлы DAG в `charts/spark-standalone/files/airflow/dags/` для полного списка переменных.

### Задание Spark зависло в WAITING

**Проверка:**
```bash
# Ресурсы worker
kubectl describe pod -l app=spark-worker -n spark-sa | grep -A 5 "Requests:"

# Запросы ресурсов задания
kubectl logs <spark-driver-pod> -n spark-sa | grep -i "executor\|memory"
```

**Решение:** Убедитесь, что память/ядра executor, запрошенные заданием ≤ ёмкости worker.

## Справочник

- **Полные values:** `charts/spark-standalone/values.yaml`
- **Prod-like values:** `charts/spark-standalone/values-prod-like.yaml`
- **Общий overlay:** `charts/values-common.yaml`
- **Карта репозитория:** [`docs/PROJECT_MAP.md`](../../../PROJECT_MAP.md)
- **English version:** [`docs/guides/en/charts/spark-standalone.md`](../../en/charts/spark-standalone.md)
