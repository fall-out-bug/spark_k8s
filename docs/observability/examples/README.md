# Observability Examples

Примеры алертов и отчётов для конструктора spark_k8s.

## Alerts

**`alerts.yaml`** — пример Prometheus alert rules:
- Spark Master down
- Spark Worker down
- Demo metrics exporter down
- Airflow DAG failed

### Как применить

1. Добавить в Prometheus config:
```yaml
rule_files:
  - /etc/prometheus/alerts.yaml
```

2. Или создать ConfigMap и смонтировать в Prometheus pod.

### Кастомизация

- `for:` — длительность перед firing
- `severity` — critical/warning
- Добавить Alertmanager для уведомлений (Slack, PagerDuty)

## Grafana Alerts

В Grafana: Dashboard → Panel → Alert → Create alert.

Пример: DAG runs failed > 0 за 5 min.
