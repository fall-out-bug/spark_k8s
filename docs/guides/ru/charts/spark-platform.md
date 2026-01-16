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
2. **`sparkConnect.master`** — Режим Spark master: `"local"` или `"k8s"` (по умолчанию: `"k8s"`)
3. **`sparkConnect.executor.memory`** — Память на executor pod (по умолчанию: `"1g"`)
4. **`sparkConnect.dynamicAllocation.maxExecutors`** — Максимум executor подов (по умолчанию: `5`)
5. **`jupyterhub.enabled`** — Включить JupyterHub (по умолчанию: `true`)
6. **`minio.enabled`** — Включить MinIO (по умолчанию: `true`)
7. **`s3.endpoint`** — URL S3 endpoint (по умолчанию: `"http://minio:9000"`)
8. **`s3.accessKey`** / **`s3.secretKey`** — Учётные данные S3
9. **`historyServer.logDirectory`** — Директория event logs (по умолчанию: `"s3a://spark-logs/events"`)
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

**Примечание:** Overlays одинаковы для EN и RU; используйте файлы из `docs/guides/en/overlays/`.

## Smoke-тесты

Специальных smoke-скриптов для `spark-platform` пока нет. Ручная проверка:

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

## Справочник

- **Полные values:** `charts/spark-platform/values.yaml`
- **Общий overlay:** `charts/values-common.yaml`
- **Карта репозитория:** [`docs/PROJECT_MAP.md`](../../../PROJECT_MAP.md)
- **English version:** [`docs/guides/en/charts/spark-platform.md`](../../en/charts/spark-platform.md)
