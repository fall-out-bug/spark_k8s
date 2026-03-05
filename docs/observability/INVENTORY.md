# Observability Inventory — spark_k8s Constructor

**Source:** WS-031-01 | **Updated:** 2026-03-03

Полный инвентарь observability-компонентов конструктора. База для persona recipes и PR gate.

---

## 1. Grafana Dashboards

| Dashboard | UID | ConfigMap | Назначение |
|-----------|-----|-----------|------------|
| Tech Lead Morning | `tech-lead-morning` | grafana-dashboard-tech-lead | Утренний обзор: кластер, DAG runs, phase breakdown |
| Logs Explorer | `logs-explorer` | grafana-dashboard-logs-explorer | Логи Spark и Airflow, Loki, фильтры |
| Spark Cluster Overview | `spark-overview` | grafana-dashboards | Workers, apps, cores, memory |
| Airflow Overview | `airflow-overview` | grafana-dashboards | DAG runs, task instances |
| Spark Cluster | `spark-cluster` | grafana-dashboards-spark | Workers, cores, memory, free resources |
| Spark Executors | `spark-executors` | grafana-dashboards-spark | Tasks, shuffle, spill, I/O |
| Spark Tuning | `spark-tuning` | grafana-dashboards-spark | Shuffle, spill, app duration |
| Spark S3 I/O | `spark-s3-io` | grafana-dashboards-spark | Input/output bytes |
| Airflow All DAGs | `airflow-multi-dag` | grafana-dashboards-spark | DAG runs, task instances (multi-dag) |

**Datasources:** Prometheus (UID: PBFA97CFB590B2093), Loki (UID: loki)

---

## 2. Prometheus Scrape Jobs

| Job | Target | Port | Метрики |
|-----|--------|------|---------|
| prometheus | localhost | 9090 | Self |
| demo-metrics-exporter | demo-metrics-exporter.observability | 9108 | spark_*, airflow_* |
| spark-master | spark-infra-standalone-master | 8080 | Spark Master UI |
| spark-worker | pods (standalone-worker) | 8081 | Spark Worker UI |
| otel-collector | otel-collector.observability | 8889 | OTEL metrics |

**Ключевые метрики (demo-metrics-exporter):**
- `spark_workers_alive`, `spark_workers_total`, `spark_apps_running`, `spark_apps_waiting`, `spark_apps_completed`
- `spark_cores_*`, `spark_memory_*`, `spark_worker_cores_free`, `spark_worker_memory_free_mb`
- `spark_executor_*`, `spark_latest_stage_*`, `spark_latest_app_duration_ms`
- `airflow_dag_runs_state`, `airflow_task_instances_state`

---

## 3. Loki + Promtail

**Loki:** `loki.observability:3100` — хранилище логов

**Promtail config:**
- Namespaces: `spark-infra`, `observability`
- Labels: `namespace`, `pod`, `container`, `app`, `component`
- Path: `/var/log/pods/*/*.log`

**Loki Query:** `{namespace=~"spark-infra|observability"}`

---

## 4. Demos и Observability-зависимости

| Demo | DAG | OTEL | demo-metrics | Зависимости |
|------|-----|------|--------------|-------------|
| nyc_taxi_ml_full_pipeline | nyc_taxi_ml_full_pipeline | ✅ | ✅ | Spark Master, History API, Airflow PG |
| citibike_analytics_pipeline | citibike_analytics_pipeline | ❓ | ✅ | Spark Master, History API, Airflow PG |
| movielens_recommendation_pipeline | movielens_recommendation_pipeline | ❓ | ✅ | Spark Master, History API, Airflow PG |
| spark_standalone_load_demo | spark_standalone_load_demo | ❓ | ✅ | Spark Master, History API, Airflow PG |

**demo-metrics-exporter TARGET_DAGS:** `spark_standalone_load_demo,nyc_taxi_ml_full_pipeline,citibike_analytics_pipeline,movielens_recommendation_pipeline`

---

## 5. E2E / Load / Observability Tests

| Test Path | Marker | Observability Impact |
|-----------|--------|----------------------|
| `tests/e2e/` | e2e | Deploy charts, может затрагивать observability namespace |
| `scripts/tests/load/` | load | Load tests, метрики |
| `scripts/tests/e2e/` | e2e | E2E deployment |
| `tests/demo-runbook-shared-infra.md` | — | Runbook: deploy observability, verify |

**Прямых observability tests:** нет (WS-031-07 создаст `test_observability_smoke.py`)

---

## 6. Config Files

| File | Purpose |
|------|---------|
| `tests/observability/prometheus-demo.yaml` | Prometheus config + deployment |
| `tests/observability/loki.yaml` | Loki deployment |
| `tests/observability/promtail.yaml` | Promtail DaemonSet and config |
| `tests/observability/demo-metrics-exporter.yaml` | Demo metrics exporter |
| `tests/observability/grafana-*.yaml` | Grafana dashboards, datasources, providers |
| `tests/observability/jmx-exporter-config.yaml` | JMX Exporter (not deployed) |
| `scripts/tests/minikube/deploy-observability.sh` | Main deploy script |

---

## 7. Deploy Order

1. `kubectl create namespace observability`
2. Prometheus, Loki, Promtail
3. demo-metrics-exporter (requires Spark Master, Airflow)
4. OTEL Collector (if OTEL enabled)
5. Grafana + dashboards, datasources
6. `./scripts/tests/minikube/deploy-observability.sh` — all-in-one
