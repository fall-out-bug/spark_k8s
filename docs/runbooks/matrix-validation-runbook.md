# Test Matrix Validation Runbook

Валидация всех сценариев на уровнях smoke → e2e → load с NYC Taxi pipeline (без SparkPi).

## Предварительные требования

- Kubernetes кластер (minikube/kind)
- Docker images: `spark-k8s-runtime:3.5-3.5.7-baseline`, `-iceberg`, `-gpu`, `-gpu-iceberg` для 3.5.7/3.5.8/4.1.0/4.1.1
- MinIO в `spark-infra` (для load-тестов с S3)
- Namespace `spark-infra` с MinIO

## Быстрый прогон (1 сценарий)

```bash
# Smoke
bash tests/run-matrix.sh smoke --filter "id=SCENARIO-0013" --timeout 8

# E2E
bash tests/run-matrix.sh e2e --filter "id=SCENARIO-0013" --timeout 10

# Load
bash tests/run-matrix.sh load --filter "id=SCENARIO-0013" --timeout 15
```

## Полный прогон по подмножеству

```bash
# 96 сценариев k8s/no-gpu (smoke ~5h)
bash tests/run-matrix.sh smoke --filter "gpu=false,platform=k8s" --timeout 5

# 24 сценария 3.5.7 + k8s + no-gpu
bash tests/run-matrix.sh smoke --filter "spark_version=3.5.7,platform=k8s,gpu=false"
```

## Все уровни для подмножества

```bash
export SCENARIO_FILTER="spark_version=3.5.7,platform=k8s,gpu=false"
bash scripts/run-matrix-validation.sh
```

## NYC Taxi pipeline

Скрипт `tests/scripts/nyc_taxi_pipeline.py`:

| Уровень | Данные | Операции |
|---------|--------|----------|
| **smoke** | 1K in-memory | COUNT, WHERE filter |
| **e2e** | 10K in-memory | GROUP BY, JOIN, aggregations |
| **load** | S3 `s3a://nyc-taxi/raw/` или 100K in-memory | 3 итерации GROUP BY AVG |

## Очистка namespace

После каждого сценария:
1. `helm uninstall` release
2. `kubectl delete namespace` (sync, до 60s)

## GPU

Для GPU-сценариев нужен кластер с GPU nodes. Перезапуск minikube с GPU:

```bash
minikube delete
minikube start --driver=docker --gpus=gpu
```

## Результаты

- `tests/results/junit/*.xml` — JUnit отчёты
- `tests/results/failed.log` — список упавших
