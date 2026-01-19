# Гайд по чарту Spark Platform

**Чарт:** `charts/spark-platform`  
**Тестировалось на:** Minikube  
**Подготовлено для:** Ограничений OpenShift (PSS `restricted` / SCC `restricted`)

## Обзор

Разворачивает **Spark Connect** (gRPC сервер) с динамическими executor-подами Kubernetes, плюс опциональные JupyterHub, MinIO, Hive Metastore и History Server.

### Что разворачивается

- **Spark Connect Server** — gRPC API (порт 15002) для подключения клиентов; создаёт executor-поды динамически через K8s API
- **JupyterHub** — Многопользовательская среда Jupyter с KubeSpawner (опционально)
- **MinIO** — S3-совместимое объектное хранилище (опционально)
- **Hive Metastore** — Репозиторий метаданных для таблиц Spark SQL (опционально)
- **Spark History Server** — Веб-интерфейс для просмотра завершённых приложений Spark (опционально)

## Быстрый старт

### Требования

- Кластер Kubernetes (Minikube/k3s для локального использования)
- `kubectl`, `helm`
- Docker образ `spark-custom:3.5.7` доступен кластеру

### Установка

```bash
# Создание namespace
kubectl create namespace spark

# Установка с настройками по умолчанию
helm install spark-platform charts/spark-platform -n spark

# Или с общим overlay значений
helm install spark-platform charts/spark-platform -n spark \
  -f charts/values-common.yaml
```

### Проверка

```bash
# Ожидание готовности подов
kubectl wait --for=condition=ready pod -l app=spark-connect -n spark --timeout=120s

# Проверка статуса
kubectl get pods -n spark
```

### Доступ

- **JupyterHub:** `kubectl port-forward svc/spark-platform-jupyterhub 8000:8000 -n spark` → http://localhost:8000 (admin / admin123)
- **Spark UI:** `kubectl port-forward svc/spark-platform-spark-connect 4040:4040 -n spark` → http://localhost:4040
- **History Server:** `kubectl port-forward svc/spark-platform-history-server 18080:18080 -n spark` → http://localhost:18080
- **MinIO Console:** `kubectl port-forward svc/spark-platform-minio 9001:9001 -n spark` → http://localhost:9001 (minioadmin / minioadmin)

## Ключевые параметры конфигурации

### Топ-10 параметров для понимания

1. **`sparkConnect.enabled`** — Включить Spark Connect Server (по умолчанию: `true`)
2. **`sparkConnect.backendMode`** — Режим бэкенда: `"k8s"` (K8s executors) или `"standalone"` (Standalone backend) (по умолчанию: `"k8s"`)
3. **`sparkConnect.standalone.masterService`** — Имя сервиса Standalone master (требуется при `backendMode=standalone`)
4. **`sparkConnect.standalone.masterPort`** — Порт Standalone master (по умолчанию: `7077`)
5. **`sparkConnect.executor.memory`** — Память на executor pod (по умолчанию: `"1g"`)
6. **`sparkConnect.dynamicAllocation.maxExecutors`** — Максимум executor подов (по умолчанию: `5`, только для режима K8s)
7. **`jupyterhub.enabled`** — Включить JupyterHub (по умолчанию: `true`)
8. **`minio.enabled`** — Включить MinIO (по умолчанию: `true`)
9. **`s3.endpoint`** — URL S3 endpoint (по умолчанию: `"http://minio:9000"`)
10. **`serviceAccount.name`** — Имя ServiceAccount (по умолчанию: `"spark"`)

### Пример: Настройка ресурсов executor

```yaml
# my-values.yaml
sparkConnect:
  executor:
    memory: "2g"
    cores: 2
  dynamicAllocation:
    maxExecutors: 10
```

```bash
helm upgrade spark-platform charts/spark-platform -n spark -f my-values.yaml
```

## Values Overlays

См. [`docs/guides/en/overlays/`](../../en/overlays/) для готовых overlays:
- `values-anyk8s.yaml` — Базовый профиль для любого Kubernetes
- `values-sa-prodlike.yaml` — Prod-like профиль (тестировалось на Minikube)
- `values-connect-k8s.yaml` — Режим Connect-only (K8s executors, по умолчанию)
- `values-connect-standalone.yaml` — Режим Connect + Standalone backend

**Примечание:** Overlays одинаковы для EN и RU; используйте файлы из `docs/guides/en/overlays/`.

### Режимы бэкенда Connect

Spark Connect поддерживает два режима бэкенда для Spark 3.5 и 4.1:

#### 1. Режим K8s Executors (по умолчанию)

Connect создаёт executor-поды динамически через Kubernetes API. Это рекомендуемый режим для большинства случаев использования.

**Конфигурация:**
```yaml
# Spark 3.5 (umbrella chart)
spark-connect:
  sparkConnect:
    backendMode: "k8s"  # По умолчанию
    executor:
      memory: "1g"
      cores: 1
    dynamicAllocation:
      enabled: true
      minExecutors: 0
      maxExecutors: 5

# Spark 4.1 (direct chart)
connect:
  backendMode: "k8s"  # По умолчанию
  executor:
    memory: "1Gi"
    cores: "1"
  dynamicAllocation:
    enabled: true
    minExecutors: 0
    maxExecutors: 10
```

**Развёртывание:**
```bash
# Spark 3.5
helm install spark-connect charts/spark-3.5 -n spark \
  -f docs/guides/en/overlays/values-connect-k8s.yaml \
  --set spark-connect.enabled=true

# Spark 4.1
helm install spark-connect charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=k8s
```

#### 2. Режим Standalone Backend

Connect отправляет задания в существующий кластер Spark Standalone. Используйте этот режим, когда хотите использовать существующие Standalone workers.

**⚠️ Важно:** Сервис Standalone master должен быть доступен из namespace Connect. Для развёртываний в одном namespace используйте имя сервиса напрямую. Для кросс-namespace используйте полный FQDN: `<service>.<namespace>.svc.cluster.local`.

**Конфигурация:**
```yaml
# Spark 3.5 (umbrella chart)
spark-connect:
  sparkConnect:
    backendMode: "standalone"
    standalone:
      masterService: "spark-sa-spark-standalone-master"  # Тот же namespace
      # masterService: "spark-standalone-master.spark-sa.svc.cluster.local"  # Кросс-namespace
      masterPort: 7077

# Spark 4.1 (direct chart)
connect:
  backendMode: "standalone"
  standalone:
    masterService: "spark-sa-spark-standalone-master"  # Тот же namespace
    masterPort: 7077
```

**Развёртывание:**
```bash
# Spark 3.5 (тот же namespace)
helm install spark-connect charts/spark-3.5 -n spark \
  -f docs/guides/en/overlays/values-connect-standalone.yaml \
  --set spark-connect.enabled=true \
  --set spark-connect.sparkConnect.standalone.masterService=spark-sa-spark-standalone-master

# Spark 4.1 (тот же namespace)
helm install spark-connect charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-sa-spark-standalone-master
```

**Требования:**
- Кластер Spark Standalone должен быть развёрнут и работать
- Сервис Standalone master должен быть доступен (рекомендуется тот же namespace)
- Standalone workers должны быть зарегистрированы у master

См. файлы overlays для подробных примеров конфигурации для Spark 3.5 и 4.1.

## Smoke-тесты

### Нагрузочные тесты

Для комплексной проверки под нагрузкой используйте специальные скрипты нагрузочных тестов:

**Режим K8s Executors:**
```bash
./scripts/test-spark-connect-k8s-load.sh <namespace> <release-name>

# Пример:
./scripts/test-spark-connect-k8s-load.sh spark spark-connect-k8s

# С пользовательскими параметрами нагрузки:
export LOAD_ROWS=2000000
export LOAD_PARTITIONS=100
export LOAD_ITERATIONS=5
export LOAD_EXECUTORS=5
./scripts/test-spark-connect-k8s-load.sh spark spark-connect-k8s
```

**Режим Standalone Backend:**
```bash
./scripts/test-spark-connect-standalone-load.sh <namespace> <release-name> [standalone-master]

# Пример:
./scripts/test-spark-connect-standalone-load.sh spark spark-connect-standalone \
  spark://spark-sa-spark-standalone-master:7077
```

См. [`docs/guides/ru/validation.md`](../validation.md) для подробной документации по скриптам нагрузочных тестов.

### Ручная проверка

Для быстрой ручной проверки:

```bash
# 1. Проверка доступности Spark Connect
kubectl exec -it deploy/spark-platform-spark-connect -n spark -- \
  curl -fsS http://localhost:4040/api/v1/applications

# 2. Проверка UI JupyterHub
kubectl port-forward svc/spark-platform-jupyterhub 8000:8000 -n spark &
# Откройте http://localhost:8000 и убедитесь, что вход работает
```

## Устранение неполадок

### Executor-поды не создаются

**Проверка:**
```bash
# RBAC
kubectl auth can-i create pods --as=system:serviceaccount:spark:spark -n spark

# Логи драйвера
kubectl logs deploy/spark-platform-spark-connect -n spark | grep -i executor
```

**Решение:** Убедитесь, что `rbac.create: true` и `serviceAccount.create: true` в values.

### Ошибки подключения к S3

**Проверка:**
```bash
kubectl get pods -n spark -l app=minio
kubectl logs deploy/spark-platform-minio -n spark
```

**Решение:** Проверьте, что `s3.endpoint` соответствует имени сервиса MinIO и `s3.sslEnabled: false` для MinIO.

### Проблемы подключения к Standalone Backend

**Симптомы:**
- Connect не может отправить задания в Standalone master
- Ошибки типа `Connection refused` или `No route to host`

**Проверка:**
```bash
# Проверка существования сервиса Standalone master
kubectl get svc <standalone-master-service> -n <namespace>

# Проверка доступности Standalone master из пода Connect
kubectl exec -it deploy/<connect-deployment> -n <namespace> -- \
  nc -zv <standalone-master-service> 7077

# Проверка логов Standalone master
kubectl logs -n <namespace> <standalone-master-pod>
```

**Решение:**
- Убедитесь, что сервис Standalone master находится в том же namespace (рекомендуется) или используйте FQDN для кросс-namespace
- Проверьте, что `sparkConnect.standalone.masterService` соответствует фактическому имени сервиса
- Проверьте network policies при использовании кросс-namespace коммуникации
- Убедитесь, что Standalone workers зарегистрированы у master

## Справочник

- **Полные values:** `charts/spark-platform/values.yaml`
- **Общий overlay:** `charts/values-common.yaml`
- **Карта репозитория:** [`docs/PROJECT_MAP.md`](../../../PROJECT_MAP.md)
- **English version:** [`docs/guides/en/charts/spark-platform.md`](../../en/charts/spark-platform.md)
