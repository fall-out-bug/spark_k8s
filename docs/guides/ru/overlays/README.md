# Values Overlays (RU)

Overlays значений для чартов Spark.

**Примечание:** Overlays одинаковы для EN и RU. Используйте файлы из [`docs/guides/en/overlays/`](../../en/overlays/):

- **`values-anyk8s.yaml`** — Базовый профиль для любого Kubernetes
- **`values-sa-prodlike.yaml`** — Prod-like профиль для Spark Standalone (тестировалось на Minikube)
- **`values-connect-k8s.yaml`** — Режим Connect-only (K8s executors, по умолчанию)
- **`values-connect-standalone.yaml`** — Режим Connect + Standalone backend

## Использование

```bash
# Для spark-platform
helm install spark-platform charts/spark-platform -n spark \
  -f docs/guides/en/overlays/values-anyk8s.yaml

# Для spark-standalone
helm install spark-standalone charts/spark-standalone -n spark-sa \
  -f docs/guides/en/overlays/values-anyk8s.yaml

# Prod-like профиль
helm install spark-prodlike charts/spark-standalone -n spark-sa-prodlike \
  -f charts/spark-standalone/values-prod-like.yaml
```

См. также:
- [`docs/guides/en/overlays/`](../../en/overlays/) — исходные файлы overlays
