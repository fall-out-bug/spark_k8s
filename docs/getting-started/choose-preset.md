# Choose a Preset Configuration

Spark K8s comes with 11+ preset configurations for common scenarios.

## Preset Catalog

| Preset | Use Case | Backend | Complexity |
|--------|----------|---------|------------|
| `jupyter-connect-local` | Interactive development | Local | Simple |
| `airflow-connect-k8s` | Production pipelines | K8s | Medium |
| `standalone-cluster` | Stable production | Standalone | Medium |
| `operator-crd` | GitOps enterprise | Operator | Advanced |
| `gpu-rapids` | GPU acceleration | K8s | Advanced |

---

## Quick Decision Guide

```
Interactive Development?
├── Yes → jupyter-connect-local
└── No → Production Workload?
    ├── Yes → airflow-connect-k8s
    └── No → Stable Batch?
        ├── Yes → standalone-cluster
        └── No → operator-crd
```

---

## Preset Details

### Jupyter + Connect (Local Dev)

**Best for:** Data exploration, ML prototyping, notebooks

```bash
helm install spark spark-k8s/preset-jupyter-connect
```

**Features:**
- Jupyter Lab with Spark Connect
- Local object storage (MinIO)
- Sample notebooks included
- Auto-scaling disabled (1 driver, 1 executor)

---

### Airflow + Connect (Production Pipelines)

**Best for:** ETL/ELT pipelines, scheduled jobs

```bash
helm install spark spark-k8s/preset-airflow-connect
```

**Features:**
- Airflow with Spark connection
- Kubernetes executor
- Celery broker
- Postgres metadata
- DAG examples

---

### Standalone Cluster (Stable Production)

**Best for:** Cost optimization, stable workloads

```bash
helm install spark spark-k8s/preset-standalone
```

**Features:**
- Fixed-size cluster (driver + 3 executors)
- Resource limits configured
- Cost-optimized (no over-provisioning)
- Monitoring integration

---

### Operator (GitOps Enterprise)

**Best for:** GitOps workflows, advanced scheduling

```bash
helm install spark-k8s/preset-operator
```

**Requires:** [Spark Operator](https://github.com/apache/spark-kubernetes-operator)

**Features:**
- SparkApplication CRD
- Batch scheduling
- Lifecycle management
- Integration with K8s controllers

---

## Customizing Presets

### Override Values

```bash
helm install spark spark-k8s/preset-jupyter-connect \
  --set jupyter.resources.requests.memory=2Gi \
  --set spark.executor.instances=3
```

### View Full Preset

```bash
helm show values spark-k8s/preset-jupyter-connect
```

---

## Advanced: Build Your Own Preset

See [Preset Architecture](../architecture/preset-system.md) to create custom presets.

---

## Next Steps

- [Local Development Setup](local-dev.md) — If not already done
- [Cloud Setup](cloud-setup.md) — For production deployment
- [Production Checklist](../operations/production-checklist.md) — Before going live

---

**Time:** 5 minutes to choose
**Difficulty:** Beginner
**Last Updated:** 2026-02-04
