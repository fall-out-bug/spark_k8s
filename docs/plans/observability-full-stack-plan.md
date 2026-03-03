# Observability Full Stack Plan

**Цель:** Техлид за утренним кофе видит состояние кластера и трейс задач. Инженер данных видит все логи и трассировки с корреляцией Airflow↔Spark.

---

## Слой 1: Техлид (Grafana утренний обзор)

| Потребность | Решение |
|-------------|---------|
| Состояние кластера | Spark Cluster dashboard (workers, apps, cores, memory) |
| Метрики задач Airflow | airflow_dag_runs_state, airflow_task_instances_state по DAG |
| Метрики задач Spark | demo-metrics-exporter → History API (executors, stages, shuffle, spill) |
| Трейс задачи по этапам | driver startup → resource wait → read → compute → shuffle → spill → write |
| Статистика по запускам | Per-run metrics, History API application list |

**Источники для phase breakdown:**
- `spark_resource_wait_seconds` — ожидание ресурсов (OTEL)
- `spark_phase_compute_seconds` — compute (OTEL)
- `spark_phase_io_write_seconds` — запись (OTEL)
- demo-metrics-exporter: `spark_latest_stage_*` — input/output/shuffle/spill из History API

---

## Слой 2: Инженер данных (отладка)

| Потребность | Решение |
|-------------|---------|
| Все логи Spark и Airflow | Loki + Promtail |
| Связь ошибок Airflow↔Spark | Labels: namespace, pod, container, dag_id (из pod name) |
| Почему задача опоздала | Phase breakdown + resource wait + stage metrics |

---

## Компоненты

### 1. Loki + Promtail
- Loki: хранилище логов
- Promtail: DaemonSet, собирает логи подов из spark-infra, observability
- Labels: namespace, pod, container_name, app

### 2. OTEL Collector (расширение)
- Prometheus exporter: метрики из Spark OTEL → endpoint для scrape
- Prometheus scrape OTEL → phase metrics в Grafana

### 3. Prometheus (расширение)
- Scrape: Spark Master :8080, Spark Worker :8081
- Scrape: OTEL Prometheus exporter (если OTEL включён)

### 4. Spark OTEL (включение)
- spark.extraListeners=org.apache.spark.openTelemetry.OpenTelemetryListener
- spark.otel.exporter.endpoint=otel-collector.observability:4317
- Добавить в spark-submit в DAGs (через Airflow variables)

### 5. JMX Exporter (опционально)
- Требует javaagent в образе Spark
- Альтернатива: Spark PrometheusServlet (уже есть в Connect, не в standalone driver)

### 6. Grafana
- Loki datasource
- Dashboard "Logs Explorer" с фильтрами по namespace, pod, dag_id
- Dashboard "Task Trace" — phase breakdown из demo-metrics + OTEL

---

## Порядок внедрения

1. Loki + Promtail + Grafana Loki datasource
2. Prometheus: scrape Spark Master/Worker
3. OTEL: Prometheus exporter
4. Spark: OTEL в spark-submit (Airflow variables)
5. Grafana: Task Trace dashboard (phase breakdown из demo-metrics)
6. JMX Exporter — при наличии образа с javaagent
