# Spark K8s Constructor: Apache Spark on Kubernetes

[![Spark Version](https://img.shields.io/badge/Spark-3.5.7%20%7C%204.1.0-orange)](https://spark.apache.org/)
[![Helm](https://img.shields.io/badge/Helm-3.x-blue)](https://helm.sh)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

**Version:** 0.1.0 | **Last Updated:** 2025-01-26

Modular Helm charts for deploying Apache Spark on Kubernetes. Deploy Spark Connect, Spark Standalone, and supporting components (Jupyter, Airflow, MLflow, MinIO, Hive Metastore, History Server) with preset configurations.

---

## Quick Links

| Resource | Description | Link |
|----------|-------------|------|
| **Usage Guide** | Complete user guide (RU/EN) | [RU](docs/guides/ru/spark-k8s-constructor.md) \| [EN](docs/guides/en/spark-k8s-constructor.md) |
| **Quick Reference** | Command cheat sheet (RU/EN) | [RU](docs/guides/ru/quick-reference.md) \| [EN](docs/guides/en/quick-reference.md) |
| **Architecture** | System architecture and components | [Architecture](docs/architecture/spark-k8s-charts.md) |
| **Recipes** | Operations, Troubleshooting, Deployment, Integration | [Recipes](#recipes) |
| **Project Origins** | Why spark_k8s — problem, solution, vision (EN/RU) | [EN](docs/about/origin-story.md) \| [RU](docs/about/ru/origin-story.md) |
| **Pre-built Images** | GHCR pull instructions, versioning | [docs/guides/ghcr-images.md](docs/guides/ghcr-images.md) |
| **What's New** | Changelog and release notes | [CHANGELOG.md](CHANGELOG.md) |

---

## Testing Status

| Platform | Status | Notes |
|----------|--------|-------|
| **Minikube** | ✅ Tested | E2E + load tests validated |
| **OpenShift** | ✅ Prepared | PSS `restricted` / SCC `restricted` compatible |

See [OpenShift notes](docs/guides/en/openshift-notes.md) for details.

---

## Charts

### Spark 3.5 (Modular Charts)

| Chart | Description | Quick Start |
|-------|-------------|-------------|
| [spark-connect](charts/spark-3.5/charts/spark-connect) | Spark Connect server (gRPC) | `helm install spark-connect charts/spark-3.5/charts/spark-connect` |
| [spark-standalone](charts/spark-3.5/charts/spark-standalone) | Master + Workers + Airflow + MLflow | `helm install spark-standalone charts/spark-3.5/charts/spark-standalone` |

### Spark 4.1 (Unified Chart)

| Chart | Description | Quick Start |
|-------|-------------|-------------|
| [spark-4.1](charts/spark-4.1) | All-in-one: Connect, Jupyter, History Server, Hive Metastore | `helm install spark charts/spark-4.1` |

### Component Versions

| Component | Spark 3.5 | Spark 4.1 |
|-----------|-----------|-----------|
| Apache Spark | 3.5.7 | 4.1.0 |
| Python | 3.10 | 3.10 |
| Java | 17 | 17 |

---

## Preset Catalog

Pre-configured values files for common scenarios:

| Scenario | Chart | Preset File | Backend |
|----------|-------|-------------|---------|
| Jupyter + Connect (K8s) | 4.1 | `values-scenario-jupyter-connect-k8s.yaml` | K8s |
| Jupyter + Connect (Standalone) | 4.1 | `values-scenario-jupyter-connect-standalone.yaml` | Standalone |
| Airflow + Connect (K8s) | 4.1 | `values-scenario-airflow-connect-k8s.yaml` | K8s |
| Airflow + Connect (Standalone) | 4.1 | `values-scenario-airflow-connect-standalone.yaml` | Standalone |
| Airflow + K8s Submit | 4.1 | `values-scenario-airflow-k8s-submit.yaml` | K8s |
| Airflow + Spark Operator | 4.1 | `values-scenario-airflow-operator.yaml` | Operator |
| Jupyter + Connect (K8s) | 3.5 | `values-scenario-jupyter-connect-k8s.yaml` | K8s |
| Jupyter + Connect (Standalone) | 3.5 | `values-scenario-jupyter-connect-standalone.yaml` | Standalone |
| Airflow + Connect | 3.5 | `values-scenario-airflow-connect.yaml` | Standalone |
| Airflow + K8s Submit | 3.5 | `values-scenario-airflow-k8s-submit.yaml` | K8s |
| Airflow + Operator | 3.5 | `values-scenario-airflow-operator.yaml` | Operator |

**Usage:**
```bash
# Spark 4.1 example
helm install spark charts/spark-4.1 -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml

# Spark 3.5 example
helm install spark-connect charts/spark-3.5/charts/spark-connect \
  -f charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml
```

### OCI Registry Install (Alternative)

Charts are also published to GitHub Container Registry:

```bash
# Login to GHCR (one-time)
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin

# Pull and install from OCI
helm pull oci://ghcr.io/fall-out-bug/spark_k8s/charts/spark-4.1 --version 0.1.0
helm install spark ./spark-4.1-0.1.0.tgz

# Or install directly (Helm 3.8+)
helm install spark oci://ghcr.io/fall-out-bug/spark_k8s/charts/spark-4.1 --version 0.1.0
```

Available charts: `spark-4.1`, `spark-3.5`, `spark-base`

---

## Components

| Component | Description | Use Case |
|-----------|-------------|----------|
| **spark-connect** | Remote Spark server (gRPC) | Data Scientists, Engineers |
| **spark-standalone** | Master + Workers cluster | Batch processing, ETL |
| **jupyter** | JupyterLab with remote Spark | Interactive notebooks |
| **hive-metastore** | Table metadata warehouse | SQL queries, ACID |
| **history-server** | Job history and metrics | Debugging, monitoring |
| **airflow** | Pipeline orchestration | DAG scheduling |
| **mlflow** | Experiment tracking | ML workflows |
| **minio** | S3-compatible storage | Object storage, event logs |

---

## Recipes

[Documentation](docs/README.md) | Scripts |
|-------------|----------|
| [Operations](docs/recipes/operations) | [scripts/recipes/operations](scripts/recipes/operations) |
| [Troubleshooting](docs/recipes/troubleshoot) | [scripts/recipes/troubleshoot](scripts/recipes/troubleshoot) |
| [Deployment](docs/recipes/deployment) | — |
| [Integration](docs/recipes/integration) | — |

### Quick Recipe Index

**Operations:**
- Configure event log for MinIO
- Enable event log (Spark 4.1)
- Initialize Hive Metastore

**Troubleshooting:**
- S3 connection failed
- History Server empty
- Spark properties syntax
- Zstandard library missing
- Driver not starting
- Driver host resolution
- Helm installation label validation
- S3 credentials secret missing
- Connect crashloop (RBAC)
- Jupyter Python dependencies

**Deployment:**
- Deploy Spark Connect for new team
- Migrate Standalone → K8s
- Add History Server HA
- Setup resource quotas

**Integration:**
- Airflow + Spark Connect
- MLflow experiment tracking
- External Hive Metastore
- Kerberos authentication
- Prometheus monitoring

---

## What's New in v0.1.0

### Features
- ✅ Spark 3.5.7 and Spark 4.1.0 support
- ✅ 11 preset values files for production scenarios
- ✅ 23 operation, troubleshooting, deployment, and integration recipes
- ✅ Jupyter notebooks with remote Spark Connect
- ✅ MinIO S3-compatible storage with auto-configuration
- ✅ E2E test suite (Minikube validated)
- ✅ Load testing support (synthetic and parquet data)
- ✅ Policy-as-code validation (OPA/Conftest)
- ✅ Quick Reference Card

### Fixes
- ✅ ISSUE-031: Auto-create s3-credentials secret
- ✅ ✅ ISSUE-033: RBAC configmaps create permission
- ✅ ISSUE-034: Jupyter Python dependencies (grpcio, grpcio-status, zstandard)
- ✅ ISSUE-035: Parquet data loader upload mechanism

### Known Issues
- ⚠️ ISSUE-030: Helm "N/A" label validation (workaround: install spark-base separately)

---

## Documentation Structure

```
docs/
├── architecture/          # System architecture
│   └── spark-k8s-charts.md
├── guides/                # User guides
│   ├── en/               # English
│   │   ├── spark-k8s-constructor.md
│   │   └── quick-reference.md
│   └── ru/               # Russian
│       ├── spark-k8s-constructor.md
│       └── quick-reference.md
├── recipes/               # How-to guides
│   ├── operations/       # Day-to-day tasks
│   ├── troubleshoot/     # Problem diagnosis
│   ├── deployment/       # Setup procedures
│   └── integration/      # External systems
├── adr/                   # Architectural decisions
├── issues/                # Issue reports
└── PROJECT_MAP.md         # Repository map
```

See [docs/PROJECT_MAP.md](docs/PROJECT_MAP.md) for complete navigation.

---

## Quick Start

### 1. Install Spark Connect + Jupyter (Spark 4.1)

```bash
# Using preset
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace

# Or customize
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set jupyter.enabled=true \
  --set spark-base.minio.enabled=true
```

### 2. Connect to Spark

```bash
# Port-forward Jupyter
kubectl port-forward -n spark svc/spark-4-1-spark-41-jupyter 8888:8888

# Open http://localhost:8888
```

In Jupyter:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-4-1-spark-41-connect:15002").getOrCreate()
df = spark.range(1000)
df.show()
```

### 3. Run E2E Test

```bash
scripts/test-e2e-jupyter-connect.sh spark-test spark-connect 4.1
```

---

## Backend Modes

Spark Connect supports three backend modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| **k8s** | Dynamic executors via Kubernetes API | Cloud-native, auto-scaling |
| **standalone** | Fixed cluster (master/workers) | Predictable resources, on-prem |
| **operator** | Spark Operator CRD-based | Advanced scheduling, pod templates |

**Example (Standalone mode):**
```bash
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set standalone.enabled=true
```

---

## Validation

### Preset Validation
```bash
# Validate all preset values
./scripts/validate-presets.sh
```

### Policy Validation
```bash
# Validate against OPA policies
./scripts/validate-policy.sh
```

### Linting
```bash
# Helm template validation
helm template test charts/spark-4.1 -f charts/spark-4.1/values-scenario-*.yaml --dry-run
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Apache Spark community
- Kubernetes upstream
- Helm charts maintainers

---

**Links:**
- [Spark Documentation](https://spark.apache.org/docs/latest/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
