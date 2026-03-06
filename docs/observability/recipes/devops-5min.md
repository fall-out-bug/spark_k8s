# DevOps — 5 min: System OK

**Цель:** За 5 минут понять — система в порядке или нет.

---

## Чек-лист (AC2)

### 1. Pods Running

```bash
kubectl get pods -n spark-infra
kubectl get pods -n observability
```

**Ожидание:** Running для spark-master, spark-worker, airflow, minio, prometheus, grafana, loki.

### 2. Prometheus Targets Up

```bash
# Port-forward (observability-demo: svc/observability-demo-prometh-prometheus; full stack: svc/prometheus)
kubectl port-forward -n observability svc/observability-demo-prometh-prometheus 9090:9090

# Проверить targets: http://localhost:9090/targets
```

**Ожидание:** `demo-metrics-exporter`, `prometheus`, `otel-collector` — up.

### 3. Loki Ready

```bash
# Pod с label app.kubernetes.io/name=loki
kubectl get pods -n observability -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].status.phase}'
# Ожидание: Running

# Или curl readiness (из пода в кластере)
kubectl run curl-loki --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s http://observability-demo-loki.observability.svc.cluster.local:3100/ready
```

**Ожидание:** `ready` в ответе.

### 4. Grafana Dashboards (AC3)

| Dashboard | UID | Назначение |
|-----------|-----|------------|
| Spark Overview | `spark-overview` | Workers, apps, History Server, logs |
| Budget Status | `budget-status` | Cluster budget utilization |
| Incident Metrics | `incident-metrics` | MTTR, incidents |

**URL:** Grafana demo — NodePort 30030 или port-forward:
```bash
kubectl port-forward -n observability svc/observability-demo-grafana 13000:3000
# http://localhost:13000/d/spark-overview/spark-overview
```

---

## Автоматическая проверка (AC4)

**Рекомендуется:** использовать канонический скрипт:

```bash
./scripts/check-demo-health.sh
```

Exit 0 = healthy, exit 1 = broken. Проверяет: namespace, Helm release, pods (MinIO, Spark, Airflow, History, Jupyter), Grafana, Prometheus, CrashLoopBackOff, orphan namespaces.

**Быстрая ручная проверка:**

```bash
# Все pods Running?
kubectl get pods -n spark-infra -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | grep -vc Running || true
# 0 = все Running
```

---

## Ссылки

- [INVENTORY](../INVENTORY.md) — полный инвентарь компонентов
- [demo-runbook](../../tests/demo-runbook-shared-infra.md) — развёртывание shared infra
