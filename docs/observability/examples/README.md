# Observability Examples

Примеры алертов и отчётов для конструктора spark_k8s.

## Prometheus Alerts (AC1)

**`alerts.yaml`** — пример Prometheus alert rules:

| Alert | Метрика | Описание |
|-------|---------|----------|
| SparkMasterDown | `demo_metrics_exporter_spark_up == 0` | Spark Master недоступен |
| SparkWorkerDown | `spark_workers_alive < spark_workers_total` | Worker(s) down |
| DemoMetricsExporterDown | `demo_metrics_exporter_up == 0` | Exporter не скрейпит |
| AirflowDAGFailed | `airflow_dag_runs_state{state="failed"} > 0` | DAG run failed |
| AirflowTaskFailed | `airflow_task_instances_state{state="failed"} > 0` | Task instance failed |

### Как применить

1. **Prometheus config:**
```yaml
rule_files:
  - /etc/prometheus/alerts.yaml
```

2. **Prometheus Operator (PrometheusRule):**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: spark-k8s-alerts
  namespace: observability
spec:
  groups:
    # copy from alerts.yaml
```

3. **ConfigMap + mount** в Prometheus pod.

### Кастомизация

- `for:` — длительность перед firing (1m–5m)
- `severity` — critical, warning, info
- Alertmanager — Slack, PagerDuty, email

---

## Grafana Alerts (AC2)

В Grafana: Dashboard → Panel → Alert → Create alert.

**Пример: DAG failed**

1. Создать panel с запросом: `airflow_dag_runs_state{state="failed"}`
2. Alert → Create alert from this panel
3. Condition: IS ABOVE 0
4. For: 5m
5. Contact point: Slack/email

**Пример: Task failed**

1. Запрос: `airflow_task_instances_state{state="failed"}`
2. Condition: IS ABOVE 0
3. For: 5m

**Datasource:** Prometheus (UID: PBFA97CFB590B2093 в demo)

---

## Daily Digest (AC3, опционально)

Ежедневный отчёт можно настроить через:

- **Grafana Report** — плагин (enterprise) или Grafana Reporter
- **CronJob** — скрипт, который запрашивает Prometheus/Grafana API и шлёт digest в Slack/email
- **Alertmanager** — группировка алертов по времени

Пример структуры digest:
- Spark: workers alive, apps running/waiting
- Airflow: DAG runs by state (success, failed)
- Top failed DAGs

---

## Ссылки

- [INVENTORY](../INVENTORY.md) — метрики, scrape jobs
- [DevOps recipe](../recipes/devops-5min.md) — проверка системы
