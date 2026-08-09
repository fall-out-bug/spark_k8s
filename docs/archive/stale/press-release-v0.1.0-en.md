# We released Spark K8s Constructor v0.1.0 🚀

**TL;DR:** We built modular Helm charts for Apache Spark on Kubernetes. 11 presets, 23 recipes, tested end-to-end, works out of the box. Spark 3.5.7 and 4.1.0.

---

## What happened?

We did what patches back in the day should have done: built a constructor for deploying Apache Spark on Kubernetes from ready-made LEGO blocks. No "write 500 lines of YAML" — just `helm install` and you're running jobs.

## What's inside?

**Components:**
- Spark Connect Server (gRPC, remote execution)
- Jupyter Lab with preconfigured Connect
- Apache Airflow for orchestration
- MLflow for ML experiments
- MinIO (S3-compatible storage)
- Hive Metastore
- History Server

**Backend modes:**
- `k8s` — dynamic executors (cloud-native)
- `standalone` — fixed cluster (master/workers)
- `operator` — Spark Operator

## 11 Presets

Don't believe everyone writes configs from scratch. So we made presets:

**Data Science:**
```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml
```

**Data Engineering:**
```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml
```

11 presets total for Spark 3.5.7 and 4.1.0.

## Testing

Not just "works on our machine". Ran on Minikube:

| Test | Result |
|------|--------|
| E2E scenarios | 6/6 passed |
| Load test (NYC taxi) | 11M+ records |
| Preset validation | 11/11 passed |

## 5 bugs you won't see in prod

Found and fixed during testing:

| Issue | What happened |
|-------|---------------|
| ISSUE-030 | Helm label validation → workaround documented |
| ISSUE-031 | MinIO secret missing → auto-create |
| ISSUE-033 | RBAC for ConfigMaps → permissions added |
| ISSUE-034 | Jupyter without grpcio → deps added |
| ISSUE-035 | Parquet upload failing → mc pipe instead of kubectl cp |

## Documentation

23 recipes + Quick Reference in Russian and English:

- **Operations:** configure event log, initialize Metastore
- **Troubleshooting:** S3 connection, RBAC, driver issues
- **Deployment:** deploy for new team, migrate
- **Integration:** Airflow, MLflow, Kerberos, Prometheus

## Quick Start

```bash
# Install
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace

# Jupyter
kubectl port-forward -n spark svc/jupyter 8888:8888
open http://localhost:8888
```

In Jupyter:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
df = spark.range(1000)
df.show()
```

## Metrics

| Metric | Value |
|--------|-------|
| Version | 0.1.0 |
| Files | 74 |
| Lines | 10,020+ |
| Presets | 11 |
| Recipes | 23 |
| Doc languages | RU + EN |
| Coverage | ≥80% |

## SDP

Built with Spec-Driven Protocol. Which means:
- Atomic workstreams
- Quality gates (coverage ≥80%, CC < 10)
- Documentation — not an afterthought

## Links

- **GitHub:** https://github.com/fall-out-bug/spark_k8s
- **Release:** https://github.com/fall-out-bug/spark_k8s/releases/tag/v0.1.0
- **Docs (EN):** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/docs/guides/en/spark-k8s-constructor.md
- **Docs (RU):** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/docs/guides/ru/spark-k8s-constructor.md

---

**Version:** 0.1.0 | **Spark:** 3.5.7, 4.1.0 | **License:** MIT

**Tested on Minikube. Works in prod.** ✅
