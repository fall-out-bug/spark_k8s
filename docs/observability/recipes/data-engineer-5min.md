# Data Engineer — 5 min: Data Traceability

**Цель:** Проследить путь данных, связать ошибки Airflow↔Spark, понять почему задача опоздала.

---

## 1. Поиск логов по dag_id, task_id, application_id (AC2)

**Grafana Explore → Loki** (путь: Explore ⊕ → выбрать Loki):

Базовый запрос:
```
{namespace="spark-infra"}
```

По pod name (содержит DAG/task в имени):
```
{namespace="spark-infra", pod=~".*nyc_taxi.*"}
```

По application_id (из Airflow логов, поиск в теле):
```
{namespace="spark-infra"} |= "application_1234567890"
```

По dag_id и task_id (pod naming: `nyc-taxi-feature-engineering`):
```
{namespace="spark-infra", pod=~".*nyc-taxi.*feature.*"}
```

---

## 2. Связь ошибки Airflow ↔ Spark (AC3)

**Корреляция:**

1. **Airflow Task Log** — ищем `application_*` или `driver.*.svc`
2. **Spark Driver pod** — `kubectl get pods -n spark-infra -l spark-role=driver`
3. **Loki** — `{namespace="spark-infra", pod=~".*driver.*"}` + время ошибки

**Labels Promtail:** `namespace`, `pod`, `app`, `component`, `node`, `trace_id` — для фильтрации.

**Связь:** Pod name Spark driver содержит dag_id и task_id (например `nyc-taxi-feature-engineering`).

---

## 3. Почему задача опоздала (AC4)

**Phase breakdown (resource wait, read, compute, write):**

| Причина | Метрика | Действие |
|---------|---------|----------|
| Ожидание ресурсов | `spark_apps_waiting` > 0 | Увеличить workers/cores |
| Медленное чтение | `spark_latest_stage_input_bytes` высокий | Проверить S3/IO |
| Медленная запись | `spark_latest_stage_output_bytes` высокий | Проверить S3/IO |
| Shuffle | `spark_latest_stage_shuffle_read_bytes`, `spark_latest_stage_shuffle_write_bytes` | Партиционирование |
| Spill | `spark_latest_stage_memory_spill_bytes` > 0, `spark_latest_stage_disk_spill_bytes` | Увеличить executor memory |
| Compute | `spark_latest_app_duration_ms` | Оптимизация кода, ресурсы |

**Источник:** demo-metrics-exporter (Prometheus), History Server API.

---

## Ссылки

- [INVENTORY](../INVENTORY.md) — Promtail labels, метрики
- [DataOps recipe](dataops-5min.md) — phase breakdown, Loki фильтры
- [Tech Lead recipe](techlead-5min.md) — утренний обзор
