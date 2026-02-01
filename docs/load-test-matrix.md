# Load Test Matrix

Нагрузочные тесты для проверки производительности, масштабирования и стабильности Spark K8s deployment при длительной работе.

## Размерность матрицы

Load тесты представляют собой выборочные сценарии для ключевых конфигураций.

- **Компоненты:** 3 (Jupyter, Airflow, Spark-submit)
- **Версии Spark:** 4 (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- **Режимы запуска:** 3 (k8s, standalone, connect)
- **Фичи:** 4 (baseline, GPU, Iceberg, GPU+Iceberg)

**Ожидаемое количество:** 16 сценариев (выборочно)

## Обязательные требования для всех сценариев

Все load тесты **ДОЛЖНЫ** включать:

1. **S3 для Event Log** - все логи выполнения Spark jobs сохраняются в S3
2. **History Server** - развёрнут для чтения логов из S3
3. **MinIO** - S3-совместимое хранилище
4. **Подробные метрики** - собираются в JSON для анализа

```yaml
# Обязательные значения для всех load тестов
global:
  s3:
    enabled: true
    endpoint: "http://minio:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
    pathStyleAccess: true
    sslEnabled: false

connect:  # или jupyter, spark-submit
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/{version}/load/{scenario}/events"

historyServer:
  enabled: true
    provider: "s3"
  s3:
    endpoint: "http://minio:9000"
```

**Примечание:** S3 логирование критически важно для load тестов, так как позволяет:
- Анализировать производительность через UI History Server
- Отслеживать проблемы после завершения теста
- Сравнивать результаты между запусками

## Легенда

- ✅ = Создано
- ❌ = Не создано
- 🔄 = В работе
- 📦 = Требует сборки образа

---

## Приоритетные сценарии для нагрузочного тестирования

### 1. Baseline производительности (4 сценария)

Базовые сценарии для измерения эталонной производительности разных версий Spark:

| Сценарий | Описание | Dataset | Duration |
|----------|-----------|---------|----------|
| ❌ `baseline-357-k8s.sh` | Spark 3.5.7 + K8s | NYC Taxi 11GB | 30 min |
| ❌ `baseline-358-k8s.sh` | Spark 3.5.8 + K8s | NYC Taxi 11GB | 30 min |
| ❌ `baseline-410-k8s.sh` | Spark 4.1.0 + K8s | NYC Taxi 11GB | 30 min |
| ❌ `baseline-411-k8s.sh` | Spark 4.1.1 + K8s | NYC Taxi 11GB | 30 min |

**Метрики:**
- Execution time
- Throughput (records/sec)
- CPU utilization
- Memory utilization
- Pod restarts

---

### 2. GPU ускорение (4 сценария)

Проверка ускорения вычислений на GPU:

| Сценарий | Описание | Dataset | Duration |
|----------|-----------|---------|----------|
| ❌ `gpu-357-k8s.sh` | Spark 3.5.7 + GPU + K8s | NYC Taxi 11GB | 30 min |
| ❌ `gpu-410-k8s.sh` | Spark 4.1.0 + GPU + K8s | NYC Taxi 11GB | 30 min |
| ❌ `gpu-358-k8s.sh` | Spark 3.5.8 + GPU + K8s | NYC Taxi 11GB | 30 min |
| ❌ `gpu-411-k8s.sh` | Spark 4.1.1 + GPU + K8s | NYC Taxi 11GB | 30 min |

**Метрики:**
- GPU utilization (%)
- GPU memory usage
- Speedup vs CPU (execution time ratio)
- RAPIDS plugin effectiveness

**Образы:** 📦 spark-custom-gpu, jupyter-spark-gpu

---

### 3. Iceberg ACID операции (4 сценария)

Проверка производительности Iceberg с ACID транзакциями:

| Сценарий | Описание | Dataset | Duration |
|----------|-----------|---------|----------|
| ❌ `iceberg-357-k8s.sh` | Spark 3.5.7 + Iceberg + K8s | NYC Taxi 11GB | 30 min |
| ❌ `iceberg-410-k8s.sh` | Spark 4.1.0 + Iceberg + K8s | NYC Taxi 11GB | 30 min |
| ❌ `iceberg-358-k8s.sh` | Spark 3.5.8 + Iceberg + K8s | NYC Taxi 11GB | 30 min |
| ❌ `iceberg-411-k8s.sh` | Spark 4.1.1 + Iceberg + K8s | NYC Taxi 11GB | 30 min |

**Метрики:**
- INSERT throughput
- SELECT/UPDATE/DELETE latency
- Snapshot management overhead
- S3 storage I/O

**Образы:** 📦 spark-custom-iceberg, jupyter-spark-iceberg

---

### 4. Connect vs K8s submit (2 сценария)

Сравнение производительности Spark Connect vs прямого K8s submit:

| Сценарий | Описание | Dataset | Duration |
|----------|-----------|---------|----------|
| ❌ `connect-vs-k8s-410.sh` | Сравнение режимов Spark 4.1.0 | NYC Taxi 11GB | 30 min |
| ❌ `connect-vs-k8s-411.sh` | Сравнение режимов Spark 4.1.1 | NYC Taxi 11GB | 30 min |

**Метрики:**
- Connection overhead
- Query latency difference
- Resource utilization difference

---

### 5. Standalone scalability (2 сценария)

Проверка масштабирования на Standalone режиме:

| Сценарий | Описание | Executors | Duration |
|----------|-----------|-----------|----------|
| ❌ `standalone-scalability-410.sh` | Spark 4.1.0 + Standalone | 1-10 | 30 min |
| ❌ `standalone-scalability-411.sh` | Spark 4.1.1 + Standalone | 1-10 | 30 min |

**Метрики:**
- Linear scaling (executor count vs throughput)
- Worker resource utilization
- Job distribution overhead

---

## Сводная таблица

| Категория | Сценариев | Создано | Образы 📦 |
|-----------|-----------|---------|----------|
| Baseline | 4 | 0 | - |
| GPU | 4 | 0 | spark-custom-gpu, jupyter-spark-gpu |
| Iceberg | 4 | 0 | spark-custom-iceberg, jupyter-spark-iceberg |
| Connect vs K8s | 2 | 0 | - |
| Standalone scalability | 2 | 0 | - |
| **ИТОГО** | **16** | **0** | 4 специальных образа |

---

## Структура load test сценария

```bash
#!/bin/bash
# @meta
name: "baseline-410-k8s"
type: "load"
description: "Load test: Spark 4.1.0 baseline performance on K8s"
version: "4.1.0"
component: "spark-submit"
mode: "k8s"
features: []
dataset: "nyc-taxi-11gb"
duration: "30 min"
iterations: 10
metrics: ["execution_time", "throughput", "cpu", "memory"]
# @endmeta
```

---

## Метрики для сбора

### Производительность
- **Execution time:** Общее время выполнения
- **Throughput:** Records/sec
- **Startup time:** Время старта Spark application
- **First result time:** Время до первого результата

### Ресурсы
- **CPU utilization:** Средний % CPU
- **Memory utilization:** Heap vs off-heap
- **Network I/O:** Bytes read/written
- **Disk I/O:** Bytes read/written

### Stability
- **Pod restarts:** Количество перезапусков
- **OOM kills:** Out of memory событий
- **Failed tasks:** Количество упавших задач
- **Error rate:** % ошибок операций

### GPU-specific
- **GPU utilization:** % GPU usage
- **GPU memory:** VRAM usage
- **CUDA operations:** Количество CUDA ops
- **Speedup factor:** GPU vs CPU ratio

---

## Наборы данных

### Small (для отладки)
- Размер: ~100MB
- Записей: ~7M
- Формат: Parquet
- Source: NYC Taxi sample

### Medium (стандартный load test)
- Размер: ~1GB
- Записей: ~70M
- Формат: Parquet
- Source: NYC Taxi subset

### Large (фактический load test)
- Размер: ~11GB
- Записей: ~744M
- Формат: 119 Parquet files
- Source: NYC Taxi full (2015-2024)
- Location: `s3a://nyc-taxi/full/yellow_tripdata_*.parquet`

### Synthetic (для стресс тестирования)
- Генерируется на лету
- Размер: настраиваемый
- Формат: Генерируемые данные
- Purpose: Пиковая нагрузка

---

## Профили нагрузки

### Sustained load
Постоянная нагрузка в течение длительного времени.
- Проверка стабильности, memory leaks
- Duration: 30+ минут
- Iterations: 10+

### Burst load
Пиковые нагрузки с периодами простоя.
- Проверка auto-scaling, recovery
- Duration: 30 минут
- Pattern: 5 min load / 2 min idle × 6 cycles

### Scaling load
Постепенное увеличение нагрузки.
- Проверка линейного масштабирования
- Duration: 30 минут
- Pattern: 1 → 2 → 4 → 8 executors

### Concurrent load
Множество одновременных задач.
- Проверка contention, resource sharing
- Duration: 30 минут
- Pattern: 5 concurrent jobs × 6 iterations

---

## Результаты load тестов

После выполнения load тесты создают отчеты в `tests/load/results/`:

```
tests/load/results/
├── baseline-410-k8s/
│   ├── metrics.json          # Сырые метрики
│   ├── summary.md            # Краткое резюме
│   ├── charts/               # Графики
│   └── logs/                 # Логи выполнения
└── ...
```

### Формат metrics.json

```json
{
  "scenario": "baseline-410-k8s",
  "spark_version": "4.1.0",
  "timestamp": "2026-02-01T18:00:00Z",
  "duration_seconds": 1800,
  "iterations": 10,
  "metrics": {
    "execution_time": {
      "avg": 245.5,
      "min": 238.2,
      "max": 256.8,
      "p50": 244.1,
      "p95": 250.3,
      "p99": 256.8
    },
    "throughput": {
      "avg_records_per_sec": 3034567,
      "total_records": 744000000
    },
    "resources": {
      "cpu_avg_percent": 78.5,
      "memory_avg_gb": 3.2
    },
    "stability": {
      "pod_restarts": 0,
      "oom_kills": 0,
      "failed_tasks": 0
    }
  }
}
```

---

## План работ

### Phase 1: Baseline (4 сценария)
- Создать baseline load тесты для всех версий Spark
- Измерить эталонную производительность

### Phase 2: GPU (4 сценария) 📦
- Собрать spark-custom-gpu, jupyter-spark-gpu образы для 3.5.7, 3.5.8, 4.1.0, 4.1.1
- Создать GPU load тесты

### Phase 3: Iceberg (4 сценария) 📦
- Собрать spark-custom-iceberg, jupyter-spark-iceberg образы
- Создать Iceberg load тесты

### Phase 4: Comparison (4 сценария)
- Создать тесты сравнения режимов
- Создать тесты масштабирования

---

## Required Docker Images

Для выполнения всех load тестов требуются следующие образы:

### Baseline (уже существуют)
- `spark-custom:3.5.7`
- `spark-custom:3.5.8`
- `spark-custom:4.1.0`
- `spark-custom:4.1.1`

### GPU (требуют сборки) 📦
- `spark-custom-gpu:3.5.7` (CUDA 12.1 + RAPIDS)
- `spark-custom-gpu:3.5.8` (CUDA 12.1 + RAPIDS)
- `spark-custom-gpu:4.1.0` (CUDA 12.1 + RAPIDS)
- `spark-custom-gpu:4.1.1` (CUDA 12.1 + RAPIDS)
- `jupyter-spark-gpu:3.5.7`
- `jupyter-spark-gpu:3.5.8`
- `jupyter-spark-gpu:4.1.0`
- `jupyter-spark-gpu:4.1.1`

### Iceberg (требуют сборки) 📦
- `spark-custom-iceberg:3.5.7`
- `spark-custom-iceberg:3.5.8`
- `spark-custom-iceberg:4.1.0`
- `spark-custom-iceberg:4.1.1`
- `jupyter-spark-iceberg:3.5.7`
- `jupyter-spark-iceberg:3.5.8`
- `jupyter-spark-iceberg:4.1.0`
- `jupyter-spark-iceberg:4.1.1`

---

## OpenShift Security Load Testing

### Security stability tests (4 сценария)

Нагрузочные тесты для проверки стабильности работы с включёнными security настройками OpenShift:

| Сценарий | Описание | Duration | Checks |
|----------|-----------|----------|--------|
| ❌ `security-pss-load-35.sh` | PSS restricted + sustained load | 30 min | Pod restarts, OOM, errors |
| ❌ `security-pss-load-41.sh` | PSS restricted + sustained load | 30 min | Pod restarts, OOM, errors |
| ❌ `security-scc-load-35.sh` | SCC restricted + sustained load | 30 min | Pod restarts, OOM, errors |
| ❌ `security-scc-load-41.sh` | SCC restricted + sustained load | 30 min | Pod restarts, OOM, errors |

**Проверки:**
- ✅ Нет pod restarts при sustained load
- ✅ Нет OOM kills
- ✅ Постоянный UID/GID при пересоздании pods
- ✅ Network policies не блокируют легитимный трафик
- ✅ Event logs успешно пишутся в S3
- ✅ History Server доступен

**Метрики:**
- Pod restart count
- OOM kill events
- Failed tasks rate
- S3 write success rate
- Network policy drop rate

**Файлы:**
- `scripts/tests/load/scenarios/security-pss-load-35.sh`
- `scripts/tests/load/scenarios/security-pss-load-41.sh`
- `scripts/tests/load/scenarios/security-scc-load-35.sh`
- `scripts/tests/load/scenarios/security-scc-load-41.sh`

**Progress:** 0/4 (0%)

**Прогресс с security load тестами: 16 + 4 = 20 scenarios (0%)**

---

## Last updated

2026-02-01 14:30 - Добавлена security load testing секция
- Progress: 0/20 (0%)
- Next: Phase 1 - Baseline load tests + Security tests
