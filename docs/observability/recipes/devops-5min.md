# DevOps — 5 min: System OK

**Цель:** За 5 минут понять — система в порядке или нет.

---

## Чек-лист

### 1. Pods Running

```bash
kubectl get pods -n spark-infra
kubectl get pods -n observability
```

**Ожидание:** Running для spark-master, spark-worker, airflow, minio, prometheus, grafana, loki, promtail.

### 2. Prometheus Targets Up

```bash
# Port-forward если нужно
kubectl port-forward -n observability svc/prometheus 9090:9090

# Проверить targets: http://localhost:9090/targets
```

**Ожидание:** `demo-metrics-exporter`, `spark-master`, `spark-worker` — up.

### 3. Loki Ready

```bash
kubectl exec -n observability deployment/loki -- wget -qO- http://localhost:3100/ready
```

**Ожидание:** `ready` в ответе.

### 4. Grafana Dashboards (опционально)

- **Spark Cluster Overview** — `spark-overview` — workers, apps
- **Tech Lead Morning** — `tech-lead-morning` — полный обзор

URL: `http://localhost:3000` (port-forward: `kubectl port-forward -n observability svc/grafana 3000:80`)

---

## Автоматическая проверка (опционально)

```bash
# Быстрая проверка
kubectl get pods -n spark-infra -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | grep -v Running | wc -l
# 0 = все Running
```

---

## Ссылки

- [INVENTORY](../../observability/INVENTORY.md) — полный инвентарь
- [demo-runbook](../../../tests/demo-runbook-shared-infra.md) — развёртывание
