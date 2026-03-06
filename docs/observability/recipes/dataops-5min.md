# DataOps — 5 min: Traces and Dashboards for Jobs

**Цель:** За 5 минут видеть трейсы и даши по джобам Spark/Airflow.

---

## 1. Dashboards для джобов (AC2)

### Spark Overview (`spark-overview`)

**Путь:** Grafana → Dashboards → Spark → Spark Overview
**URL:** `http://localhost:13000/d/spark-overview/spark-overview` (port-forward)

- **History Server Up** — доступность History Server
- **Spark Logs** — Loki, базовый фильтр `{app=~"spark.*"}`
- **Traces** — Jaeger (если развёрнут)
- **Ссылки** — History Server UI, Jaeger UI

### Performance Analysis (`performance-analysis`)

**Путь:** Grafana → Dashboards → Spark → Performance Analysis

- **Executor Memory Used** — `spark_executor_metrics_memoryUsed`
- **Task Duration (Max)** — `spark_task_duration_max`
- **Shuffle Read** — `spark_shuffle_read_bytes`
- **Shuffle Write** — `spark_shuffle_write_bytes`

### Logs Explorer (Grafana Explore → Loki)

**Путь:** Grafana → Explore (⊕) → выбрать Loki

Базовый запрос:
```
{namespace=~"spark-infra|observability"}
```

---

## 2. Фильтрация по DAG, task, application_id (AC3)

**Loki labels:** `namespace`, `pod`, `app`, `component`, `node`, `trace_id`

| Фильтр | Loki Query | Примечание |
|--------|------------|------------|
| Namespace | `{namespace="spark-infra"}` | Логи spark-infra |
| Pod (DAG/task) | `{pod=~".*nyc-taxi.*feature.*"}` | Pod name содержит dag_id и task_id |
| App | `{app=~"spark.*"}` | Spark-подобные приложения |
| Container | `{container="spark-driver"}` | Только driver |

**application_id:** искать в теле лога (LogQL `|= "application_123"`) или в History Server API по DAG run.

**Пример для DAG `nyc_taxi_ml_full_pipeline`, task `feature_engineering`:**
```
{namespace="spark-infra", pod=~".*nyc-taxi.*feature.*"}
```

---

## 3. Phase Breakdown (AC4)

**Метрики demo-metrics-exporter (Prometheus):**

| Метрика | Назначение |
|---------|------------|
| `spark_latest_stage_shuffle_read_bytes` | Shuffle read по app_id |
| `spark_latest_stage_shuffle_write_bytes` | Shuffle write по app_id |
| `spark_latest_stage_memory_spill_bytes` | Memory spill |
| `spark_latest_stage_disk_spill_bytes` | Disk spill |
| `spark_latest_stage_input_bytes` | Input (read) |
| `spark_latest_stage_output_bytes` | Output (write) |
| `spark_latest_app_duration_ms` | Длительность приложения |

**Интерпретация:**

| Фаза | Метрики | Что значит |
|------|---------|------------|
| Driver | — | Координация, планирование |
| Read | input_bytes | Чтение (S3, HDFS) |
| Compute | task_duration, executor_memory | Вычисления |
| Shuffle | shuffle_read/write | Обмен между stages |
| Spill | memory_spill, disk_spill | OOM risk, настройка памяти |
| Write | output_bytes | Запись результата |

**Bottleneck:** Высокий shuffle + spill → увеличить `spark.executor.memory` или пересмотреть партиционирование.

---

## Ссылки

- [INVENTORY](../INVENTORY.md) — метрики, dashboards, scrape jobs
- [Performance Analysis dashboard](../../../charts/observability/grafana/dashboards/performance-analysis.json)
- [DevOps recipe](devops-5min.md) — быстрая проверка системы
