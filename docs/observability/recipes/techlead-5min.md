# Tech Lead — 5 min: Pipeline State

**Цель:** За 5 минут видеть состояние пайплайнов: что работает, что упало, почему.

---

## Утренний чек-лист

### 1. Grafana → Tech Lead Morning

**Dashboard:** `tech-lead-morning`

1. **Spark Cluster** — Workers alive, Apps running
2. **Airflow DAG Runs** — DAG runs by state (success/failed/running)
3. **Task Instances** — Task states
4. **Phase Breakdown** — Shuffle, spill, I/O по приложениям

### 2. Быстрая оценка

| Что смотреть | Где | Зелёный |
|--------------|-----|---------|
| Кластер | Spark Cluster row | Workers > 0, Apps running |
| DAGs | Airflow DAG Runs | success растёт, failed = 0 |
| Tasks | Task Instances | success, failed |
| Bottleneck | Phase breakdown | Низкий spill |

### 3. Упавшая задача — drill-down

1. **Airflow UI** — какой DAG, какая task
2. **Logs Explorer** — фильтр `{namespace="spark-infra"}` + pod name (содержит dag_id/task_id)
3. **Spark History Server** — application_id из логов Airflow → Spark UI

**Связь Airflow ↔ Spark:** Pod name Spark driver содержит `dag_id` и `task_id` в labels (если настроено).

---

## Ссылки

- [INVENTORY](../../observability/INVENTORY.md)
- [Data Engineer recipe](data-engineer-5min.md) — детальная отладка
