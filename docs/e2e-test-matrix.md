# E2E Test Matrix

Полная матрица end-to-end тестов для проверки всех комбинаций компонентов, версий Spark, режимов запуска, фич и базовых библиотек.

**Дата создания:** 2026-02-01
**Статус:** ⚠️ Требуется реализации

---

## Размерность матрицы

E2E тесты представляют собой полную проверку функциональности на реальных/больших данных.

- **Компоненты:** 3 (Jupyter, Airflow, Spark-submit)
- **Версии Spark:** 4 (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- **Версии Python:** 2 (3.10, 3.11) - последние поддерживаемые Spark
- **Версии JDK:** 2 (17, 21) - последние поддерживаемые Spark
- **Версии Airflow:** 2 (2.8.x, 2.9.x) - ветка 2
- **Режимы запуска:** 3 (k8s, standalone, connect)
- **Фичи:** 4 (baseline, GPU, Iceberg, GPU+Iceberg)

**Полная матрица:** 3 × 4 × 2 × 2 × 2 × 3 × 4 = **692 сценария**

**Оптимизированная матрица (ключевые комбинации):** **80 сценариев**

---

## Поддерживаемые версии библиотек

### Python версии

| Spark версия | Мин. Python | Рекомендуемая Python | Макс. Python |
|-------------|-------------|---------------------|--------------|
| 3.5.7 | 3.8 | 3.10 | 3.11 |
| 3.5.8 | 3.8 | 3.10 | 3.11 |
| 4.1.0 | 3.8 | 3.11 | 3.12 |
| 4.1.1 | 3.8 | 3.11 | 3.12 |

**E2E тесты используют:** Python 3.10 (для 3.5.x) и Python 3.11 (для 4.1.x)

### JDK версии

| Spark версия | Мин. JDK | Рекомендуемая JDK | Макс. JDK |
|-------------|----------|-------------------|-----------|
| 3.5.7 | 8 | 17 | 21 |
| 3.5.8 | 8 | 17 | 21 |
| 4.1.0 | 17 | 21 | 23 |
| 4.1.1 | 17 | 21 | 23 |

**E2E тесты используют:** JDK 17 (для 3.5.x) и JDK 21 (для 4.1.x)

### Airflow версии

| Ветка | Версии в E2E | Провайдер |
|-------|--------------|-----------|
| 2.x | 2.8.x, 2.9.x | apache-airflow-providers-cncf-kubernetes |

**E2E тесты используют:** Airflow 2.9.x (последняя стабильная ветки 2)

---

## Обязательные требования для всех сценариев

Все E2E тесты **ДОЛЖНЫ** включать:

1. **S3 для Event Log** - все логи выполнения Spark jobs сохраняются в S3
2. **History Server** - развёрнут для чтения логов из S3
3. **MinIO** - S3-совместимое хранилище
4. **Полный датасет** - NYC Taxi full (11GB, 744M records)

```yaml
# Обязательные значения для всех E2E тестов
global:
  s3:
    enabled: true
    endpoint: "http://minio:9000"
    accessKey: "$S3_ACCESS_KEY"
    secretKey: "$S3_SECRET_KEY"
    pathStyleAccess: true
    sslEnabled: false

connect:  # или jupyter, spark-submit
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/{version}/e2e/{scenario}/events"

historyServer:
  enabled: true
  provider: "s3"
  s3:
    endpoint: "http://minio:9000"
```

---

## Легенда

- ✅ = Создано
- ❌ = Не создано
- 🔄 = В работе
- 📦 = Требует сборки образа

---

## Оптимизированная матрица (80 сценариев)

### Priority 1: Core функциональность (24 сценария)

Базовые E2E тесты для всех версий Spark с основными комбинациями.

| № | Сценарий | Spark | Python | JDK | Airflow | Компонент | Режим | Статус |
|---|----------|-------|--------|-----|---------|-----------|-------|--------|
| 1 | `e2e-jupyter-k8s-357-py310-jdk17.sh` | 3.5.7 | 3.10 | 17 | - | Jupyter | k8s | ❌ |
| 2 | `e2e-jupyter-k8s-358-py310-jdk17.sh` | 3.5.8 | 3.10 | 17 | - | Jupyter | k8s | ❌ |
| 3 | `e2e-jupyter-k8s-410-py311-jdk21.sh` | 4.1.0 | 3.11 | 21 | - | Jupyter | k8s | ❌ |
| 4 | `e2e-jupyter-k8s-411-py311-jdk21.sh` | 4.1.1 | 3.11 | 21 | - | Jupyter | k8s | ❌ |
| 5 | `e2e-jupyter-connect-410-py311-jdk21.sh` | 4.1.0 | 3.11 | 21 | - | Jupyter | connect | ❌ |
| 6 | `e2e-jupyter-connect-411-py311-jdk21.sh` | 4.1.1 | 3.11 | 21 | - | Jupyter | connect | ❌ |
| 7 | `e2e-airflow-k8s-357-py310-jdk17-af29.sh` | 3.5.7 | 3.10 | 17 | 2.9 | Airflow | k8s | ❌ |
| 8 | `e2e-airflow-k8s-358-py310-jdk17-af29.sh` | 3.5.8 | 3.10 | 17 | 2.9 | Airflow | k8s | ❌ |
| 9 | `e2e-airflow-k8s-410-py311-jdk21-af29.sh` | 4.1.0 | 3.11 | 21 | 2.9 | Airflow | k8s | ❌ |
| 10 | `e2e-airflow-k8s-411-py311-jdk21-af29.sh` | 4.1.1 | 3.11 | 21 | 2.9 | Airflow | k8s | ❌ |
| 11 | `e2e-airflow-connect-410-py311-jdk21-af29.sh` | 4.1.0 | 3.11 | 21 | 2.9 | Airflow | connect | ❌ |
| 12 | `e2e-airflow-connect-411-py311-jdk21-af29.sh` | 4.1.1 | 3.11 | 21 | 2.9 | Airflow | connect | ❌ |
| 13-24 | spark-submit все комбинации | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | - | spark-submit | k8s/connect/standalone | ❌ |

### Priority 2: GPU тесты (16 сценариев)

E2E тесты с GPU для проверки RAPIDS ускорения.

| № | Сценарий | Spark | Python | JDK | CUDA | RAPIDS | Статус |
|---|----------|-------|--------|-----|------|--------|--------|
| 25 | `e2e-gpu-jupyter-k8s-357-cuda121.sh` | 3.5.7 | 3.10 | 17 | 12.1 | 24.x | 📦❌ |
| 26 | `e2e-gpu-jupyter-k8s-358-cuda121.sh` | 3.5.8 | 3.10 | 17 | 12.1 | 24.x | 📦❌ |
| 27 | `e2e-gpu-jupyter-k8s-410-cuda121.sh` | 4.1.0 | 3.11 | 21 | 12.1 | 24.x | 📦❌ |
| 28 | `e2e-gpu-jupyter-k8s-411-cuda121.sh` | 4.1.1 | 3.11 | 21 | 12.1 | 24.x | 📦❌ |
| 29-32 | `e2e-gpu-airflow-*-k8s-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | 12.1 | 24.x | 📦❌ |
| 33-36 | `e2e-gpu-spark-submit-*-k8s-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | 12.1 | 24.x | 📦❌ |
| 37-40 | `e2e-gpu-*-connect-*.sh` | 4.1.x | 3.11 | 21 | 12.1 | 24.x | 📦❌ |

**GPU образы:**
- CUDA 12.1 + RAPIDS 24.x
- spark-custom-gpu, jupyter-spark-gpu, airflow-spark-gpu

### Priority 3: Iceberg тесты (16 сценариев)

E2E тесты с Apache Iceberg для проверки ACID операций.

| № | Сценарий | Spark | Python | JDK | Iceberg | Catalog | Статус |
|---|----------|-------|--------|-----|---------|---------|--------|
| 41 | `e2e-iceberg-jupyter-k8s-357.sh` | 3.5.7 | 3.10 | 17 | 1.4.x | Hive | 📦❌ |
| 42 | `e2e-iceberg-jupyter-k8s-358.sh` | 3.5.8 | 3.10 | 17 | 1.5.x | Hive | 📦❌ |
| 43 | `e2e-iceberg-jupyter-k8s-410.sh` | 4.1.0 | 3.11 | 21 | 1.5.x | Hive | 📦❌ |
| 44 | `e2e-iceberg-jupyter-k8s-411.sh` | 4.1.1 | 3.11 | 21 | 1.5.x | Hive | 📦❌ |
| 45-48 | `e2e-iceberg-airflow-*-k8s-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | 1.4.x/1.5.x | Hive | 📦❌ |
| 49-52 | `e2e-iceberg-spark-submit-*-k8s-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | 1.4.x/1.5.x | Hive | 📦❌ |
| 53-56 | `e2e-iceberg-*-connect-*.sh` | 4.1.x | 3.11 | 21 | 1.5.x | Hive | 📦❌ |

**Iceberg образы:**
- Iceberg 1.4.x (для Spark 3.5.x)
- Iceberg 1.5.x (для Spark 4.1.x)
- spark-custom-iceberg, jupyter-spark-iceberg, airflow-spark-iceberg

### Priority 4: GPU+Iceberg комбо (8 сценариев)

E2E тесты с комбинацией GPU и Iceberg.

| № | Сценарий | Spark | Python | JDK | CUDA | Iceberg | Статус |
|---|----------|-------|--------|-----|------|---------|--------|
| 57 | `e2e-gpu-iceberg-jupyter-k8s-410.sh` | 4.1.0 | 3.11 | 21 | 12.1 | 1.5.x | 📦❌ |
| 58 | `e2e-gpu-iceberg-jupyter-k8s-411.sh` | 4.1.1 | 3.11 | 21 | 12.1 | 1.5.x | 📦❌ |
| 59-62 | `e2e-gpu-iceberg-airflow-*-k8s-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | 12.1 | 1.4.x/1.5.x | 📦❌ |
| 63-64 | `e2e-gpu-iceberg-spark-submit-*-k8s-*.sh` | 4.1.x | 3.11 | 21 | 12.1 | 1.5.x | 📦❌ |

### Priority 5: Standalone режим (8 сценариев)

E2E тесты для Spark Standalone режима.

| № | Сценарий | Spark | Python | JDK | Компонент | Статус |
|---|----------|-------|--------|-----|-----------|--------|
| 65 | `e2e-standalone-jupyter-357.sh` | 3.5.7 | 3.10 | 17 | Jupyter | ❌ |
| 66 | `e2e-standalone-jupyter-410.sh` | 4.1.0 | 3.11 | 21 | Jupyter | ❌ |
| 67-70 | `e2e-standalone-airflow-*-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | Airflow | ❌ |
| 71-72 | `e2e-standalone-spark-submit-*-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | spark-submit | ❌ |

### Priority 6: Library version compatibility (8 сценариев)

E2E тесты для проверки совместимости разных версий библиотек.

| № | Сценарий | Spark | Python | JDK | Цель | Статус |
|---|----------|-------|--------|-----|------|--------|
| 73 | `e2e-lib-compat-358-py311-jdk21.sh` | 3.5.8 | 3.11 | 21 | Max versions | ❌ |
| 74 | `e2e-lib-compat-410-py310-jdk17.sh` | 4.1.0 | 3.10 | 17 | Min versions | ❌ |
| 75 | `e2e-lib-compat-410-py312-jdk23.sh` | 4.1.0 | 3.12 | 23 | Edge versions | ❌ |
| 76 | `e2e-lib-compat-411-py312-jdk23.sh` | 4.1.1 | 3.12 | 23 | Edge versions | ❌ |
| 77-80 | `e2e-lib-compat-airflow-af28-*.sh` | 3.5.x/4.1.x | 3.10/3.11 | 17/21 | Airflow 2.8 | ❌ |

---

## Сводная таблица

| Категория | Сценариев | Создано | Образы 📦 |
|-----------|-----------|---------|-----------|
| Core функциональность | 24 | 0 | - |
| GPU | 16 | 0 | spark-custom-gpu, jupyter-spark-gpu, airflow-spark-gpu |
| Iceberg | 16 | 0 | spark-custom-iceberg, jupyter-spark-iceberg, airflow-spark-iceberg |
| GPU+Iceberg | 8 | 0 | spark-custom-gpu-iceberg (комбо) |
| Standalone | 8 | 0 | - |
| Library compatibility | 8 | 0 | - |
| **ИТОГО** | **80** | **0** | **6 специальных образа** |

---

## Структура E2E test сценария

```bash
#!/bin/bash
# @meta
name: "e2e-jupyter-k8s-410-py311-jdk21"
type: "e2e"
description: "E2E test for Jupyter + Spark Connect + K8s backend (Spark 4.1.0, Python 3.11, JDK 21)"
version: "4.1.0"
component: "jupyter"
mode: "connect-k8s"
features: []
python_version: "3.11"
jdk_version: "21"
airflow_version: ""
dataset: "nyc-taxi-full"
dataset_size: "11GB"
dataset_records: 744000000
estimated_time: "20 min"
# @endmeta
```

---

## Dataset для E2E тестов

### NYC Taxi Full (стандартный E2E)

- **Размер:** ~11GB
- **Записей:** ~744M
- **Формат:** 119 Parquet files
- **Source:** NYC Taxi (2015-2024)
- **Location:** `s3a://nyc-taxi/full/yellow_tripdata_*.parquet`

**Queries:**
```sql
-- 1. Full table scan
SELECT COUNT(*) FROM nyc_taxi;

-- 2. Aggregation
SELECT year, month, COUNT(*), SUM(fare_amount)
FROM nyc_taxi
GROUP BY year, month
ORDER BY year, month;

-- 3. Join
SELECT t1.year, t1.month, COUNT(*)
FROM nyc_taxi t1
JOIN nyc_taxi t2 ON t1.year = t2.year AND t1.month = t2.month
GROUP BY t1.year, t1.month;

-- 4. Window function
SELECT year, month,
       SUM(fare_amount) OVER (PARTITION BY year ORDER BY month) as cumulative_fare
FROM nyc_taxi
ORDER BY year, month;
```

### TPC-DS (опционально, для advanced E2E)

- **Scale factor:** 1GB, 10GB, 100GB
- **Queries:** 99 queries
- **Format:** Parquet
- **Purpose:** Стандартный бенчмарк для data warehousing

---

## Метрики для сбора

### Производительность
- **Execution time:** Общее время выполнения
- **Query latency:** Latency для каждого query
- **Throughput:** Records/sec
- **Startup time:** Время старта Spark application

### Ресурсы
- **CPU utilization:** Средний % CPU
- **Memory utilization:** Heap vs off-heap
- **Network I/O:** Bytes read/written
- **Disk I/O:** Bytes read/written (временные файлы)

### Stability
- **Pod restarts:** Количество перезапусков
- **OOM kills:** Out of memory событий
- **Failed tasks:** Количество упавших задач
- **Error rate:** % ошибок операций

### GPU-specific (для GPU тестов)
- **GPU utilization:** % GPU usage
- **GPU memory:** VRAM usage
- **CUDA operations:** Количество CUDA ops
- **Speedup factor:** GPU vs CPU ratio

### Iceberg-specific (для Iceberg тестов)
- **INSERT throughput:** Rows/sec
- **SELECT latency:** Avg query time
- **UPDATE/DELETE latency:** Time for ACID operations
- **Snapshot count:** Количество snapshots
- **S3 I/O:** Bytes read/written

---

## Результаты E2E тестов

После выполнения E2E тесты создают отчеты в `tests/e2e/results/`:

```
tests/e2e/results/
├── e2e-jupyter-k8s-410-py311-jdk21/
│   ├── metrics.json           # Сырые метрики
│   ├── summary.md             # Краткое резюме
│   ├── queries/               # Результаты каждого query
│   │   ├── query_1.json
│   │   ├── query_2.json
│   │   └── ...
│   ├── charts/                # Графики
│   └── logs/                  # Логи выполнения
└── ...
```

### Формат metrics.json

```json
{
  "scenario": "e2e-jupyter-k8s-410-py311-jdk21",
  "spark_version": "4.1.0",
  "python_version": "3.11",
  "jdk_version": "21",
  "timestamp": "2026-02-01T18:00:00Z",
  "duration_seconds": 1200,
  "queries_executed": 4,
  "metrics": {
    "execution_time": {
      "total_seconds": 1200,
      "queries": {
        "query_1": 45.2,
        "query_2": 320.5,
        "query_3": 580.3,
        "query_4": 254.0
      }
    },
    "throughput": {
      "avg_records_per_sec": 620000,
      "total_records": 744000000
    },
    "resources": {
      "cpu_avg_percent": 85.5,
      "memory_avg_gb": 6.2,
      "network_mb_read": 11500,
      "network_mb_written": 450
    },
    "stability": {
      "pod_restarts": 0,
      "oom_kills": 0,
      "failed_tasks": 0
    }
  },
  "verdict": "PASS"
}
```

---

## Required Docker Images для E2E

### Baseline (уже существуют)

| Образ | Spark | Python | JDK | Статус |
|-------|-------|--------|-----|--------|
| `spark-custom:3.5.7` | 3.5.7 | 3.10 | 17 | ✅ |
| `spark-custom:3.5.8` | 3.5.8 | 3.10 | 17 | ✅ |
| `spark-custom:4.1.0` | 4.1.0 | 3.11 | 21 | ✅ |
| `spark-custom:4.1.1` | 4.1.1 | 3.11 | 21 | ✅ |
| `jupyter-spark:3.5.7` | 3.5.7 | 3.10 | 17 | ✅ |
| `jupyter-spark:3.5.8` | 3.5.8 | 3.10 | 17 | ✅ |
| `jupyter-spark:4.1.0` | 4.1.0 | 3.11 | 21 | ✅ |
| `jupyter-spark:4.1.1` | 4.1.1 | 3.11 | 21 | ✅ |

### GPU (требуют сборки) 📦

| Образ | Spark | Python | JDK | CUDA | RAPIDS | Статус |
|-------|-------|--------|-----|------|--------|--------|
| `spark-custom-gpu:3.5.7` | 3.5.7 | 3.10 | 17 | 12.1 | 24.x | ❌ |
| `spark-custom-gpu:3.5.8` | 3.5.8 | 3.10 | 17 | 12.1 | 24.x | ❌ |
| `spark-custom-gpu:4.1.0` | 4.1.0 | 3.11 | 21 | 12.1 | 24.x | ❌ |
| `spark-custom-gpu:4.1.1` | 4.1.1 | 3.11 | 21 | 12.1 | 24.x | ❌ |
| `jupyter-spark-gpu:3.5.7` | 3.5.7 | 3.10 | 17 | 12.1 | 24.x | ❌ |
| `jupyter-spark-gpu:3.5.8` | 3.5.8 | 3.10 | 17 | 12.1 | 24.x | ❌ |
| `jupyter-spark-gpu:4.1.0` | 4.1.0 | 3.11 | 21 | 12.1 | 24.x | ❌ |
| `jupyter-spark-gpu:4.1.1` | 4.1.1 | 3.11 | 21 | 12.1 | 24.x | ❌ |

### Iceberg (требуют сборки) 📦

| Образ | Spark | Python | JDK | Iceberg | Статус |
|-------|-------|--------|-----|---------|--------|
| `spark-custom-iceberg:3.5.7` | 3.5.7 | 3.10 | 17 | 1.4.x | ❌ |
| `spark-custom-iceberg:3.5.8` | 3.5.8 | 3.10 | 17 | 1.5.x | ❌ |
| `spark-custom-iceberg:4.1.0` | 4.1.0 | 3.11 | 21 | 1.5.x | ❌ |
| `spark-custom-iceberg:4.1.1` | 4.1.1 | 3.11 | 21 | 1.5.x | ❌ |
| `jupyter-spark-iceberg:3.5.7` | 3.5.7 | 3.10 | 17 | 1.4.x | ❌ |
| `jupyter-spark-iceberg:3.5.8` | 3.5.8 | 3.10 | 17 | 1.5.x | ❌ |
| `jupyter-spark-iceberg:4.1.0` | 4.1.0 | 3.11 | 21 | 1.5.x | ❌ |
| `jupyter-spark-iceberg:4.1.1` | 4.1.1 | 3.11 | 21 | 1.5.x | ❌ |

### Airflow (branch 2.x)

| Образ | Airflow | Python | Spark | Статус |
|-------|---------|--------|-------|--------|
| `airflow-spark:2.9.0-3.5.7` | 2.9.0 | 3.10 | 3.5.7 | ❌ |
| `airflow-spark:2.9.0-3.5.8` | 2.9.0 | 3.10 | 3.5.8 | ❌ |
| `airflow-spark:2.9.0-4.1.0` | 2.9.0 | 3.11 | 4.1.0 | ❌ |
| `airflow-spark:2.9.0-4.1.1` | 2.9.0 | 3.11 | 4.1.1 | ❌ |
| `airflow-spark-gpu:2.9.0-4.1.0` | 2.9.0 | 3.11 | 4.1.0 | ❌ |
| `airflow-spark-iceberg:2.9.0-4.1.0` | 2.9.0 | 3.11 | 4.1.0 | ❌ |

---

## План работ

### Phase 1: Core E2E (24 сценария) - День 1-2

- [ ] Создать базовые E2E сценарии для всех версий Spark
- [ ] Проверить core функциональность (K8s submit, Connect)
- [ ] Измерить эталонную производительность

### Phase 2: Library Compatibility (8 сценариев) - День 2

- [ ] Проверить совместимость разных версий Python/JDK
- [ ] Проверить edge версии (Python 3.12, JDK 23)
- [ ] Проверить Airflow 2.8.x

### Phase 3: GPU (16 сценариев) 📦 - День 3-4

- [ ] Собрать GPU образы для всех версий
- [ ] Создать GPU E2E сценарии
- [ ] Измерить ускорение vs CPU

### Phase 4: Iceberg (16 сценариев) 📦 - День 4-5

- [ ] Собрать Iceberg образы для всех версий
- [ ] Создать Iceberg E2E сценарии
- [ ] Проверить ACID операции

### Phase 5: GPU+Iceberg комбо (8 сценариев) 📦 - День 5

- [ ] Проверить комбинацию GPU + Iceberg
- [ ] Создать комбо E2E сценарии

### Phase 6: Standalone (8 сценариев) - День 6

- [ ] Создать Standalone E2E сценарии
- [ ] Проверить масштабирование

---

## Last updated

2026-02-01 15:00 - Initial E2E test matrix creation
- Progress: 0/80 (0%)
- Next: Phase 1 - Core E2E tests
