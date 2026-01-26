# Spark K8s Charts: Архитектура

**Дата:** 2025-01-26
**Версия:** 0.1.0

---

## Обзор архитектуры

Конструктор Spark K8s представляет собой двухуровневую структуру Helm чартов:

1. **Spark 3.5:** Модульные subcharts (LEGO-подход)
2. **Spark 4.1:** Единый чарт с toggle-flags

Оба подхода позволяют комбинировать компоненты для создания оптимальной конфигурации под конкретные нужды команды.

---

## Структура чартов

### Spark 3.5 (модульная архитектура)

```
charts/spark-3.5/
├── charts/
│   ├── spark-base-0.1.0.tgz          # Базовый образ
│   ├── spark-connect/                # Connect server
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── spark-connect.yaml
│   │       ├── jupyter.yaml
│   │       ├── jupyterhub.yaml
│   │       ├── history-server.yaml
│   │       ├── hive-metastore.yaml
│   │       ├── minio.yaml
│   │       ├── postgresql.yaml
│   │       ├── rbac.yaml
│   │       └── secrets.yaml
│   └── spark-standalone/             # Master/Workers
│       ├── Chart.yaml
│       ├── values-prod-like.yaml
│       └── templates/
│           ├── master.yaml
│           ├── worker.yaml
│           ├── shuffle-service.yaml
│           ├── airflow/
│           │   ├── scheduler.yaml
│           │   ├── webserver.yaml
│           │   └── pod-template-configmap.yaml
│           ├── mlflow/
│           │   ├── server.yaml
│           │   └── postgresql.yaml
│           └── ...
└── values-common.yaml
```

**Принципы:**
- Каждый компонент — отдельный Helm chart
- Комбинация через `Chart.yaml` dependencies или individual install
- Переиспользование `spark-base` как общего слоя

### Spark 4.1 (единый чарт)

```
charts/spark-4.1/
├── Chart.yaml
├── Chart.lock
├── values.yaml                       # Все компоненты в одном файле
├── charts/
│   └── spark-base-0.1.0.tgz
└── templates/
    ├── rbac.yaml
    ├── spark-connect-configmap.yaml
    ├── spark-connect.yaml
    ├── hive-metastore-configmap.yaml
    ├── hive-metastore.yaml
    ├── hive-metastore-init.yaml
    ├── history-server.yaml
    ├── jupyter-pvc.yaml
    ├── jupyter.yaml
    ├── ingress.yaml
    └── executor-pod-template-configmap.yaml
```

**Принципы:**
- Все компоненты в одном чарте
- Включение/выключение через `component.enabled: true/false`
- Проще для single-team деплоя

---

## Зависимости между компонентами

### Component Dependency Graph

```
                    ┌─────────────┐
                    │   Storage   │
                    │  (S3/MinIO) │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │  Connect │    │Standalone│    │ Operator │
    │  Server  │    │ Cluster  │    │ (K8s CRD)│
    └─────┬────┘    └─────┬────┘    └─────┬────┘
          │               │               │
          └───────────────┼───────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   ┌─────────┐      ┌─────────┐      ┌──────────┐
   │ Jupyter │      │ Airflow │      │  MLflow  │
   │         │      │         │      │          │
   └─────────┘      └─────────┘      └──────────┘
        │                │                  │
        └────────────────┼──────────────────┘
                         ▼
                  ┌──────────────┐
                  │ Hive Metastore│
                  │  (optional)   │
                  └───────┬───────┘
                          │
                         ▼
                  ┌──────────────┐
                  │History Server│
                  │  (optional)  │
                  └──────────────┘
```

### Исполнители Spark (Backend modes)

| Компонент | Роль | Backend modes |
|-----------|------|---------------|
| Connect Server | Remote Spark server | K8s, Standalone |
| Standalone | Classic cluster | — |
| Operator | CRD-based execution | K8s |

### Клиенты Spark

Все клиенты поддерживают все backend:

| Клиент | Connect | Standalone | Operator | Local K8s |
|--------|---------|------------|----------|-----------|
| Jupyter | ✅ | ✅ | ✅ | ✅ |
| Airflow | ✅ | ✅ | ✅ | ✅ |
| MLflow | ✅ | ✅ | ✅ | ✅ |
| spark-submit CLI | ✅ | ✅ | ✅ | ✅ |

### Правила зависимостей

| Компонент | Обязательные зависимости | Поддерживает клиенты |
|-----------|-------------------------|---------------------|
| Connect | Storage (S3/MinIO) | Jupyter, Airflow, MLflow, CLI |
| Standalone | Storage (S3/MinIO) | Jupyter, Airflow, MLflow, CLI |
| Operator | Storage (S3/MinIO) + CRDs | Jupyter, Airflow, MLflow, CLI |
| Jupyter | Любой Spark backend | — |
| Airflow | Любой Spark backend | — |
| MLflow | Любой Spark backend + Storage | — |
| History Server | Storage (S3/MinIO) | — |
| Metastore | PostgreSQL | Все Spark backends |

---

## Примеры конфигураций

### Data Science: Jupyter + Connect + K8s

```yaml
# charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml
connect:
  enabled: true
  backendMode: k8s
  eventLog:
    enabled: true
    dir: s3a://spark-logs/4.1/events

jupyter:
  enabled: true
  env:
    SPARK_CONNECT_URL: "sc://spark-connect:15002"

hiveMetastore:
  enabled: true

historyServer:
  enabled: true
  logDirectory: s3a://spark-logs/4.1/events
```

### Data Engineering: Airflow + Connect + Standalone

```yaml
# charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-connect.yaml
sparkMaster:
  enabled: true
  ha:
    enabled: true

sparkWorker:
  replicas: 2

sparkConnect:
  enabled: true
  backendMode: standalone
  standalone:
    masterService: spark-sa-spark-standalone-master

airflow:
  enabled: true
  kubernetesExecutor:
    deleteWorkerPods: false
```

### Platform: All components + HA

```yaml
# charts/spark-4.1/values-platform-team.yaml
connect:
  enabled: true
  replicas: 3

hiveMetastore:
  enabled: true
  postgresql:
    persistence:
      enabled: true

historyServer:
  enabled: true
  replicas: 3

jupyter:
  enabled: true

airflow:
  enabled: true

mlflow:
  enabled: true
```

---

## Key Configuration Patterns

### Spark 4.1: Backend mode switching

```yaml
# K8s backend (dynamic executors)
connect:
  backendMode: k8s
  dynamicAllocation:
    enabled: true
    minExecutors: 0
    maxExecutors: 10

# Standalone backend (fixed cluster)
connect:
  backendMode: standalone
  standalone:
    masterService: spark-standalone-master
    masterPort: 7077
```

### Spark 3.5: Driver host resolution (Standalone)

```yaml
# spark-connect/values.yaml
sparkConnect:
  sparkConf:
    spark.driver.host: "{{ .Release.Name }}-spark-connect.{{ .Release.Namespace }}.svc.cluster.local"
  env:
    SPARK_DRIVER_HOST: "{{ .Release.Name }}-spark-connect.{{ .Release.Namespace }}.svc.cluster.local"
```

### S3 configuration

```yaml
global:
  s3:
    endpoint: "http://minio:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
    pathStyleAccess: true
    existingSecret: "s3-credentials"  # опционально
```

---

## E2E Test Matrix

Все конфигурации протестированы (см. `docs/testing/F06-e2e-matrix-report.md`):

| Configuration | Spark 3.5 | Spark 4.1 |
|---------------|-----------|-----------|
| Jupyter + Connect + K8s | ✅ | ✅ |
| Jupyter + Connect + Standalone | ✅ | ✅ |
| Airflow + Connect + K8s | ✅ | ✅ |
| Airflow + Connect + Standalone | ✅ | ✅ |
| Airflow + K8s submit | ✅ | ✅ |
| Airflow + Operator | ✅ | ✅ |

---

## Полезные ссылки

- **Usage Guide:** `docs/guides/ru/spark-k8s-constructor.md`
- **Implementation Plan:** `docs/plans/2025-01-25-spark-k8s-builder-impl.md`
- **E2E Report:** `docs/testing/F06-e2e-matrix-report.md`
- **Issues:** `docs/issues/`
