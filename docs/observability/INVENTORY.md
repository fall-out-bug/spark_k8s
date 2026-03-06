# Observability Inventory — spark_k8s Constructor

**Source:** WS-00-031-01 | **Updated:** 2026-03-06

Полный инвентарь observability-компонентов конструктора. База для persona recipes и PR gate.

## Два режима развёртывания

| Режим | Источник | Когда использовать |
|-------|----------|-------------------|
| **Demo** | `charts/observability-demo/` (Helm) + `deploy-observability.sh` | Minikube demo, spark-infra namespace. Helm install observability-demo. |
| **Full stack** | `charts/observability/` (Helm) | Production, multi-namespace. Prometheus Operator, ServiceMonitors. |

Demo использует `spark-infra`; charts/observability по умолчанию — `spark-operations`. Для demo: `charts/observability-demo` с `values-demo.yaml` (targetNamespace=spark-infra).

---

## 1. Grafana Dashboards (AC1)

**Источник:** `charts/observability/grafana/dashboards/` (deployed via grafana-spark subchart)

| Dashboard | UID | Folder | Назначение |
|-----------|-----|--------|------------|
| Spark Overview | `spark-overview` | Spark | Unified view: History Server, logs, traces links |
| Performance Analysis | `performance-analysis` | Spark | Executor memory, task duration, shuffle I/O |
| Backup Status | `backup-status` | Operations | Backup size, duration, last backup status |
| Budget Status | `budget-status` | Operations | Cluster budget utilization, team breakdown |
| Chaos Metrics | `chaos-metrics` | Operations | Job success rate, recovery time during chaos |
| Cost by Job | `cost-by-job` | Operations | Cost distribution by application |
| Cost by Team | `cost-by-team` | Operations | Cost distribution by team |
| Incident Metrics | `incident-metrics` | Operations | MTTR, PIR, recurring incidents |
| SLO Forecast | `slo-forecast` | Operations | SLO error rate, time to breach |
| Cost Trends | (no UID) | — | Cost trends, forecasting (in folder, not in values) |
| Cost Breakdown | (no UID) | — | Driver/executor, spot/on-demand (in folder, not in values) |
| RTO/RPO Metrics | (no UID) | — | Recovery objectives, backup compliance (in folder, not in values) |

**Deprecated (_archived):** Tech Lead Morning, Logs Explorer, grafana-dashboards-spark (raw YAMLs replaced by Helm).

**Datasources:** Prometheus (UID: PBFA97CFB590B2093), Loki (UID: loki), Jaeger (full stack only)

---

## 2. Prometheus Scrape Jobs (AC2)

**Источник:** observability-demo → prometheus-spark (prometheus-operator) + ServiceMonitors

| Job | Target | Port | Метрики |
|-----|--------|------|---------|
| prometheus | self | 9090 | Prometheus self-metrics |
| demo-metrics-exporter | demo-metrics-exporter.observability | 9108 | spark_*, airflow_* |
| otel-collector | otel-collector.observability | 8889 | otel_* (traces, metrics) |
| spark-servicemonitor | Spark driver pods (app=spark, spark-role=driver) | metrics | spark_driver_metrics |
| kube-state-metrics | (prometheus-operator) | — | kube_* |
| node-exporter | (prometheus-operator) | — | node_* |

**Ключевые метрики (demo-metrics-exporter):**
- `spark_workers_alive`, `spark_workers_total`, `spark_apps_running`, `spark_apps_waiting`, `spark_apps_completed`
- `spark_cores_*`, `spark_memory_*`, `spark_worker_cores_free`, `spark_worker_memory_free_mb`
- `spark_executor_*`, `spark_latest_stage_*`, `spark_latest_app_duration_ms`
- `airflow_dag_runs_state`, `airflow_task_instances_state`

---

## 3. Loki + Promtail (AC3)

**Loki:** `{{ .Release.Name }}-loki:3100` (e.g. observability-demo-loki.observability:3100)

**Promtail config** (`charts/observability/loki/templates/promtail-spark.yaml`):

| Параметр | Значение |
|----------|----------|
| Job | spark-pods |
| Namespace | `targetNamespace` (spark-infra for demo, spark-operations default) |
| Labels | namespace, pod, app, component, node, trace_id |
| Path | /var/log/pods/$uid/$container/*.log |
| Pipeline | JSON parse, level label, timestamp, sampling (10% INFO, 100% ERROR/WARN) |

**Loki Query:** `{namespace=~"spark-infra|observability"}` (for demo)

---

## 4. Demos и Observability-зависимости (AC4)

| Demo | DAG | OTEL | demo-metrics | Зависимости |
|------|-----|------|--------------|-------------|
| nyc_taxi_ml_full_pipeline | nyc_taxi_ml_full_pipeline | ✅ (pushgateway) | ✅ | Spark Master, History API, Airflow PG |
| citibike_analytics_pipeline | citibike_analytics_pipeline | — | ✅ | Spark Master, History API, Airflow PG |
| movielens_recommendation_pipeline | movielens_recommendation_pipeline | — | ✅ | Spark Master, History API, Airflow PG |
| spark_standalone_load_demo | spark_standalone_load_demo | — | ✅ | Spark Master, History API, Airflow PG |

**demo-metrics-exporter TARGET_DAGS:** `spark_standalone_load_demo,nyc_taxi_ml_full_pipeline,citibike_analytics_pipeline,movielens_recommendation_pipeline`

**DAG sources:** `charts/spark-3.5/dags/` (nyc_taxi_ml_full_pipeline.py, citibike_analytics_pipeline.py, movielens_recommendation_pipeline.py)

---

## 5. E2E / Load / Observability Tests (AC5)

| Test Path | Type | Observability Impact |
|-----------|------|----------------------|
| `tests/integration/test_observability_demo.py` | helm template | observability-demo chart render |
| `tests/integration/test_observability_grafana.py` | helm template | Grafana chart |
| `tests/integration/test_observability_prometheus.py` | helm template | Prometheus chart |
| `tests/integration/test_observability_loki.py` | helm template | Loki chart |
| `tests/integration/test_observability_jaeger.py` | helm template | Jaeger chart |
| `tests/integration/test_observability_alertmanager.py` | helm template | Alertmanager chart |
| `tests/integration/test_observability_spark_ui.py` | helm template | History Server observability (metrics, tracing, logging) |
| `tests/demo-runbook-shared-infra.md` | runbook | Deploy observability, verify OTEL |
| `scripts/tests/load/run-load-against-release.sh` | load | Produces metrics (History Server, event logs) |
| `scripts/tests/load/run-validate-history-after-load.sh` | load | Validates History Server API |
| `scripts/tests/e2e/` | e2e | May deploy observability namespace |
| `scripts/observability/test_observability_*.py` | script | Metrics/logging validation |

**Прямых observability smoke tests:** нет (WS-031-07 создаст `test_observability_smoke.py`)

---

## 6. Config Files

| File | Purpose |
|------|---------|
| `charts/observability-demo/` | Demo umbrella chart (Prometheus, Loki, Grafana, demo-metrics-exporter, OTEL) |
| `charts/observability-demo/values-demo.yaml` | Demo preset (targetNamespace=spark-infra) |
| `tests/observability/start-ui-portforwards.sh` | Port-forwards for UI access (Grafana :13000, Prometheus :19090) |
| `tests/observability/_archived/` | Deprecated raw YAMLs (2026-03-06) |
| `scripts/tests/minikube/deploy-observability.sh` | Main deploy script (Helm) |

**Note:** Port-forwards use `svc/grafana` and `svc/prometheus`; with observability-demo the actual service names are release-prefixed (e.g. observability-demo-grafana-spark-grafana). Verify after deploy.

---

## 7. Deploy Order

1. `kubectl create namespace observability`
2. `helm dependency update charts/observability-demo`
3. `helm upgrade --install observability-demo charts/observability-demo -f values-demo.yaml -n observability --set targetNamespace=spark-infra`
4. Or: `./scripts/tests/minikube/deploy-observability.sh` — all-in-one
