# DataOps — 5 min: Traces and Dashboards for Jobs

**Цель:** За 5 минут видеть трейсы и даши по джобам Spark/Airflow.

---

## 1. Tech Lead Dashboard (phase breakdown)

**Dashboard:** Tech Lead Morning (`tech-lead-morning`)

- **Spark Cluster** — workers, apps running, cores, memory
- **Airflow DAG Runs** — по state (success, failed, running)
- **Spark Phase Breakdown** — shuffle, spill, I/O, app duration

**Метрики phase breakdown:**
- `spark_latest_stage_shuffle_read_bytes`, `spark_latest_stage_shuffle_write_bytes`
- `spark_latest_stage_memory_spill_bytes`, `spark_latest_stage_disk_spill_bytes`
- `spark_latest_stage_input_bytes`, `spark_latest_stage_output_bytes`
- `spark_latest_app_duration_ms`

---

## 2. Logs Explorer

**Dashboard:** Logs Explorer (`logs-explorer`)

**Базовый запрос Loki:**
```
{namespace=~"spark-infra|observability"}
```

**Фильтры:**
- По namespace: `{namespace="spark-infra"}`
- По pod: `{pod=~"spark-infra.*"}`
- По container: `{container="spark-driver"}`

---

## 3. Phase Breakdown — интерпретация

| Метрика | Что значит |
|---------|------------|
| Shuffle read/write | Обмен данными между stages |
| Memory/Disk spill | OOM risk, нужна настройка памяти |
| Input/Output bytes | Чтение/запись (S3, HDFS) |
| App duration | Общее время приложения |

**Bottleneck:** Высокий shuffle + spill → увеличить `spark.executor.memory` или пересмотреть партиционирование.

---

## Ссылки

- [INVENTORY](../../observability/INVENTORY.md) — метрики, dashboards
- [Grafana dashboards](../../../charts/observability/grafana/dashboards/) — spark-executors, spark-tuning, spark-overview
