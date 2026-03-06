# Tech Lead — 5 min: Pipeline State

**Цель:** За 5 минут видеть состояние пайплайнов: что работает, что упало, почему.

---

## Утренний чек-лист (AC2)

### 1. Spark Overview (`spark-overview`)

**Путь:** Grafana → Dashboards → Spark → Spark Overview
**URL:** `http://localhost:13000/d/spark-overview/spark-overview`

- **History Server Up** — кластер доступен
- **Spark Logs** — Loki, базовый обзор логов
- **Traces** — Jaeger (если развёрнут)

### 2. Кластер и DAG/Task states

**Prometheus (Explore → Prometheus):**

| Метрика | Что смотреть |
|---------|--------------|
| `spark_workers_alive` | Workers > 0 |
| `spark_apps_running` | Apps running |
| `airflow_dag_runs_state{dag_id="nyc_taxi_ml_full_pipeline"}` | DAG runs по state (success, failed, running) |
| `airflow_task_instances_state{dag_id="nyc_taxi_ml_full_pipeline"}` | Task instances по state |

### 3. Phase breakdown

**Performance Analysis (`performance-analysis`):** Shuffle read/write, executor memory, task duration.

**Prometheus:** `spark_latest_stage_*`, `spark_latest_app_duration_ms` (по app_id).

### 4. Быстрая оценка

| Что смотреть | Где | Зелёный |
|--------------|-----|---------|
| Кластер | spark_workers_alive, spark_apps_running | Workers > 0, Apps running |
| DAGs | airflow_dag_runs_state | success растёт, failed = 0 |
| Tasks | airflow_task_instances_state | success, failed = 0 |
| Bottleneck | Performance Analysis, spark_latest_stage_* | Низкий spill |

---

## Упавшая задача — drill-down (AC3)

1. **Airflow UI** — какой DAG, какая task (http://localhost:18080)
2. **Grafana Explore → Loki** — фильтр `{namespace="spark-infra", pod=~".*<dag_id>.*<task_id>.*"}` или поиск по application_id в логах
3. **Spark History Server** — application_id из логов Airflow → Spark UI (http://localhost:18081)

**Связь Airflow ↔ Spark:** Pod name Spark driver содержит dag_id и task_id (например `nyc-taxi-feature-engineering`).

---

## Ссылки на дашборды (AC4)

| Dashboard | UID | Назначение |
|-----------|-----|------------|
| Spark Overview | `spark-overview` | Unified view, logs, traces |
| Performance Analysis | `performance-analysis` | Shuffle, spill, executor memory |
| Budget Status | `budget-status` | Cluster budget utilization |
| Incident Metrics | `incident-metrics` | MTTR, incidents |

---

## Ссылки

- [INVENTORY](../INVENTORY.md) — полный инвентарь
- [DataOps recipe](dataops-5min.md) — трейсы, phase breakdown, Loki фильтры
- [Data Engineer recipe](data-engineer-5min.md) — детальная отладка, traceability
