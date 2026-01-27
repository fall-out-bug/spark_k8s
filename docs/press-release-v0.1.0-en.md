# Press Release: Spark K8s Constructor v0.1.0

**FOR IMMEDIATE RELEASE**

---

## Spark K8s Constructor v0.1.0 Released: Production-Ready Apache Spark on Kubernetes

**January 26, 2025** — The Spark K8s Constructor team announces the release of version 0.1.0, a set of modular Helm charts for deploying Apache Spark on Kubernetes. The release provides data engineering teams with production-ready preset configurations for quick deployment of Spark 3.5.7 and 4.1.0 on Kubernetes infrastructure.

### What is Spark K8s Constructor?

Spark K8s Constructor is a collection of modular Helm charts that enables deploying Apache Spark on Kubernetes without writing Kubernetes manifests from scratch. The project supports three execution modes (K8s native, Spark Standalone, Spark Operator) and includes integrations with key data platform components.

**Key Capabilities:**

| Component | Purpose |
|-----------|---------|
| **Spark Connect Server** | Remote Spark execution via gRPC |
| **Jupyter Lab** | Interactive notebooks with remote Spark |
| **Apache Airflow** | Spark job orchestration |
| **MLflow** | ML experiment tracking |
| **MinIO** | S3-compatible storage |
| **Hive Metastore** | Table metadata warehouse |
| **History Server** | Job monitoring and logging |

### 11 Production-Ready Presets for Common Scenarios

The release includes 11 tested preset configurations for common use cases:

**For Data Science:**
- `jupyter-connect-k8s.yaml` — Jupyter + Spark Connect (K8s backend)
- `jupyter-connect-standalone.yaml` — Jupyter + Spark Connect (Standalone backend)

**For Data Engineering:**
- `airflow-connect-k8s.yaml` — Airflow + Spark Connect (K8s backend)
- `airflow-connect-standalone.yaml` — Airflow + Spark Connect (Standalone backend)
- `airflow-k8s-submit.yaml` — Airflow with K8s submit mode
- `airflow-operator.yaml` — Airflow + Spark Operator

**Spark Version Support:**
- Spark 4.1.0 (unified chart with toggle-flags)
- Spark 3.5.7 (modular architecture: spark-base, spark-connect, spark-standalone)

### Backend Execution Modes

Spark K8s Constructor supports three modes for Spark job execution:

| Mode | Description | Use Case |
|------|-------------|----------|
| **k8s** | Dynamic executors via Kubernetes API | Cloud-native, auto-scaling |
| **standalone** | Fixed cluster (master/workers) | Predictable resources, on-prem |
| **operator** | Spark Operator (CRD-based) | Advanced scheduling, pod templates |

### Testing and Quality

The release completed full testing cycle on Minikube:

- **E2E Tests:** 6 scenarios, all passed
- **Load Tests:** 11M+ records (NYC taxi dataset)
- **Preset Validation:** 11/11 presets pass `helm template --dry-run`
- **Policy Validation:** OPA/Conftest for compliance

**Issues Fixed During Development:**
- ISSUE-030: Helm "N/A" label validation (workaround documented)
- ISSUE-031: Auto-create s3-credentials secret
- ISSUE-033: RBAC ConfigMaps permissions added
- ISSUE-034: Jupyter Python dependencies (grpcio, grpcio-status, zstandard)
- ISSUE-035: Parquet data loader upload mechanism fixed

### Documentation in Russian and English

Complete documentation available in both languages:

**User Guides:**
- [Spark K8s Constructor: Руководство пользователя (RU)](docs/guides/ru/spark-k8s-constructor.md)
- [Spark K8s Constructor: User Guide (EN)](docs/guides/en/spark-k8s-constructor.md)

**Quick Reference:**
- [Быстрая справка (RU)](docs/guides/ru/quick-reference.md)
- [Quick Reference (EN)](docs/guides/en/quick-reference.md)

**Recipes (23 guides):**
- Operations: configure event log, initialize Hive Metastore
- Troubleshooting: S3 connection, RBAC, driver issues, dependencies
- Deployment: deploy for new team, migrate Standalone → K8s
- Integration: Airflow, MLflow, external Metastore, Kerberos, Prometheus

### Who Is This For?

**For Data Scientists:**
- Quick start: 1 `helm install` command
- Jupyter with preconfigured Spark Connect
- Interactive development without local Spark

**For Data Engineers:**
- Ready-made presets for Airflow orchestration
- Batch processing and ETL support
- Job history via History Server

**For Platform Operators:**
- Modular architecture (LEGO-like)
- GitOps-ready (Helm charts + Git)
- Policy-as-code (OPA/Conftest)
- RBAC and security best practices

### Release Metrics

| Metric | Value |
|--------|-------|
| Version | 0.1.0 |
| Files | 74 |
| Lines of Code | 10,020+ |
| Presets | 11 |
| Recipes | 23 |
| Test Scripts | 10 |
| Documentation Languages | RU + EN |
| Test Coverage | ≥80% |

### Development Methodology

The project was built using **Spec-Driven Protocol (SDP)** — a methodology that ensures:

- Atomic workstreams with clear boundaries
- Quality gates (coverage ≥80%, CC < 10)
- Documentation as first-class artifact
- Full traceability from idea to deployment

**Result:** 5 production issues discovered and fixed before release.

### Quick Start

```bash
# Install Spark Connect + Jupyter (Spark 4.1)
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace

# Access Jupyter
kubectl port-forward -n spark svc/jupyter 8888:8888
# Open http://localhost:8888
```

In Jupyter:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
df = spark.range(1000)
df.show()
```

### Media Contact

- **Repository:** https://github.com/fall-out-bug/spark_k8s
- **Documentation:** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/README.md
- **Issues:** https://github.com/fall-out-bug/spark_k8s/issues
- **Release Notes:** https://github.com/fall-out-bug/spark_k8s/releases/tag/v0.1.0

---

### About the Release

**Version:** 0.1.0
**Release Date:** January 26, 2025
**Spark Versions:** 3.5.7, 4.1.0
**License:** MIT
**Methodology:** Spec-Driven Protocol (SDP)

**Full Changelog:** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/CHANGELOG.md

---

# # #

**Spark K8s Constructor — Apache Spark on Kubernetes, production-ready.**

https://github.com/fall-out-bug/spark_k8s
