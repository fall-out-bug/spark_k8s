# Data Scientist — 5 min: "Just Works" Checklist

**Цель:** За 5 минут понять — ноутбук/модель запускается или нет.

---

## Минимальный чек-лист

### 1. Jupyter Up

```bash
kubectl get pods -n spark-infra -l app.kubernetes.io/name=jupyter
```

**Ожидание:** Running

### 2. Spark Connect Up

```bash
kubectl get pods -n spark-infra -l app.kubernetes.io/component=spark-connect
# или для standalone
kubectl get svc -n spark-infra | grep 15002
```

**Ожидание:** Service/Connect доступен на 15002

### 3. MinIO Buckets

```bash
kubectl run -n spark-infra minio-check --rm -i --restart=Never \
  --image=quay.io/minio/mc:latest --command -- /bin/sh -c "
  mc alias set local http://minio:9000 minioadmin minioadmin &&
  mc ls local
"
```

**Ожидание:** warehouse, spark-logs, spark-jobs (или нужные buckets)

---

## Куда смотреть при ошибке

1. **Jupyter pod logs:** `kubectl logs -n spark-infra -l app.kubernetes.io/name=jupyter`
2. **Spark Connect logs:** `kubectl logs -n spark-infra -l app.kubernetes.io/component=spark-connect`
3. **Grafana Logs Explorer** (если настроен) — фильтр по namespace

---

## History Server (Spark UI)

Для просмотра завершённых Spark jobs:

```bash
kubectl port-forward -n spark-infra svc/spark-infra-spark-35-history 18080:18080
# http://localhost:18080
```

---

## Ссылки

- [demo-runbook](../../../tests/demo-runbook-shared-infra.md) — полный runbook
- [INVENTORY](../../observability/INVENTORY.md)
