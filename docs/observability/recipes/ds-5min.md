# Data Scientist — 5 min: "Just Works" Checklist

**Цель:** За 5 минут понять — ноутбук/модель запускается или нет.

---

## Минимальный чек-лист (AC2)

### 1. Jupyter Up

```bash
kubectl get pods -n spark-infra -l app.kubernetes.io/name=jupyter
```

**Ожидание:** Running

**URL:** http://localhost:18888/lab (port-forward: `tests/observability/start-ui-portforwards.sh`)

### 2. Spark Up (Standalone или Connect)

**Demo (Standalone):**
```bash
kubectl get pods -n spark-infra -l app.kubernetes.io/component=standalone-master
kubectl get pods -n spark-infra -l app.kubernetes.io/component=standalone-worker
```

**Connect-сценарии:**
```bash
kubectl get pods -n spark-infra -l app.kubernetes.io/component=spark-connect
# Service: sc://<release>-spark-connect:15002
```

**Ожидание:** Master/Connect и workers Running

### 3. MinIO Buckets

```bash
kubectl run -n spark-infra minio-check --rm -i --restart=Never \
  --image=minio/mc:RELEASE.2025-08-13T08-35-41Z --command -- /bin/sh -c "
  mc alias set local http://minio:9000 minioadmin minioadmin &&
  mc ls local
"
```

**Ожидание:** warehouse, spark-logs, spark-jobs (или нужные buckets)

---

## Куда смотреть при ошибке (AC3)

1. **Jupyter pod logs:** `kubectl logs -n spark-infra -l app.kubernetes.io/name=jupyter -f`
2. **Spark driver/worker logs:** `kubectl logs -n spark-infra -l app.kubernetes.io/component=standalone-worker`
3. **Grafana Explore → Loki** (опционально): `{namespace="spark-infra"}` — фильтр по namespace

---

## History Server (Spark UI) (AC4)

Для просмотра завершённых Spark jobs:

```bash
kubectl port-forward -n spark-infra svc/spark-infra-spark-35-history 18081:18080
```

**URL:** http://localhost:18081

Или использовать `tests/observability/start-ui-portforwards.sh` — History на :18081.

---

## Ссылки

- [INVENTORY](../INVENTORY.md) — компоненты observability
- [demo-runbook](../../tests/demo-runbook-shared-infra.md) — развёртывание shared infra
- [DevOps recipe](devops-5min.md) — полная проверка системы
