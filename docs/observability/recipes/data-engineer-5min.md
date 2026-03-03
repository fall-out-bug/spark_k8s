# Data Engineer — 5 min: Data Traceability

**Цель:** Проследить путь данных, связать ошибки Airflow↔Spark, понять почему задача опоздала.

---

## 1. Поиск логов по dag_id, task_id, application_id

**Logs Explorer** — Loki запросы:

```
{namespace="spark-infra"} |~ "dag_id|task_id"
```

По pod name (содержит DAG/task в имени):
```
{namespace="spark-infra", pod=~".*nyc_taxi.*"}
```

По application_id (из Airflow логов):
```
{namespace="spark-infra"} |~ "application_1234567890"
```

---

## 2. Связь ошибки Airflow ↔ Spark

1. **Airflow Task Log** — ищем `application_*` или `driver.*.svc`
2. **Spark Driver pod** — `kubectl get pods -n spark-infra -l spark-role=driver`
3. **Loki** — `{pod=~"spark-infra.*driver.*"}` + время ошибки

**Labels Promtail:** `namespace`, `pod`, `container`, `app`, `component` — для фильтрации.

---

## 3. Почему задача опоздала

**Phase breakdown (demo-metrics, History API):**

| Причина | Метрика | Действие |
|---------|---------|----------|
| Ожидание ресурсов | `spark_apps_waiting` > 0 | Увеличить workers/cores |
| Медленное чтение | `spark_latest_stage_input_bytes` высокий | Проверить S3/IO |
| Медленная запись | `spark_latest_stage_output_bytes` высокий | Проверить S3/IO |
| Shuffle | `spark_latest_stage_shuffle_*` высокий | Партиционирование |
| Spill | `spark_latest_stage_memory_spill_bytes` > 0 | Увеличить executor memory |

---

## Ссылки

- [INVENTORY](../../observability/INVENTORY.md) — Promtail labels
- [observability-full-stack-plan](../../../docs/plans/observability-full-stack-plan.md) — Слой 2
