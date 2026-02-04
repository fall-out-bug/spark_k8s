# Spark K8s for Data Engineers

Complete guide for data engineers to deploy and manage Apache Spark on Kubernetes.

## 🎯 Your Journey

### Who Is This For?

You are a **Data Engineer** who needs to:
- Deploy Spark jobs without waiting for DevOps tickets
- Iterate quickly on data pipelines
- Understand production-ready configurations
- Troubleshoot failed jobs independently

---

## 🚀 Quick Start (5 Minutes)

1. **Local Setup**: [Local Development](../getting-started/local-dev.md)
2. **First Job**: [Your First Spark Job](../getting-started/first-spark-job.md)
3. **Choose Preset**: [Preset Selection Guide](../getting-started/choose-preset.md)

---

## 📚 Learning Path

### Phase 1: Foundations (1-2 days)

**Goal:** Deploy your first job locally

1. [ ] Complete local setup (Minikube or Kind)
2. [ ] Run "Hello World" job
3. [ ] Connect Jupyter and run queries
4. [ ] Understand backend modes (K8s vs Standalone)

**Resources:**
- [Getting Started Guides](../getting-started/)
- [Architecture Overview](../architecture/spark-k8s-charts.md)
- [Spark Basics](https://spark.apache.org/docs/latest/)

### Phase 2: Production Patterns (1 week)

**Goal:** Deploy production-ready pipelines

1. [ ] Choose production preset (Airflow + Connect, Standalone)
2. [ ] Configure resource limits and scaling
3. [ ] Set up observability (metrics, logging)
4. [ ] Implement job validation

**Resources:**
- [Production Checklist](../operations/production-checklist.md)
- [Performance Tuning](../operations/performance-tuning.md)
- [Observability Setup](../guides/en/observability/)

### Phase 3: Advanced Operations (2-4 weeks)

**Goal:** Manage data platforms at scale

1. [ ] Multi-version Spark (3.5 LTS + 4.1)
2. [ ] GPU acceleration for ML workloads
3. [ ] Iceberg table management
4. [ ] Cost optimization strategies

**Resources:**
- [Preset Catalog](../guides/en/presets/)
- [Cost Optimization Guide](../recipes/cost-optimization/auto-scaling-guide.md)
- [GPU Support](../recipes/integration/gpu-support.md)
- [Iceberg Integration](../recipes/integration/apache-iceberg.md)

---

## 🎓 Key Skills

### Required Skills

| Skill | Why Important | Resources |
|-------|---------------|------------|
| **Spark SQL** | Most ETL work is SQL | [Spark SQL Guide](https://spark.apache.org/docs/latest/sql/) |
| **Python/Scala** | Job development | [Spark Programming Guide](https://spark.apache.org/docs/latest/) |
| **Kubernetes Basics** | Understanding deployment | [K8s Basics](https://kubernetes.io/docs/tutorials/) |
| **Helm Charts** | Package management | [Helm Basics](https://helm.sh/docs/) |

### Nice to Have

- Airflow DAG authoring
- MLflow experiment tracking
- Delta Lake operations
- Streaming with Kafka

---

## 🔧 Common Tasks

### Deploy an ETL Pipeline

```bash
# Use Airflow + Connect preset
helm install spark spark-k8s/preset-airflow-connect

# Submit job
spark-submit \
  --master k8s://spark-connect:15002 \
  --deploy-mode cluster \
  --name my-etl-job \
  --py-files etl_pipeline.py
```

### Run Interactive Analysis

```bash
# Port-forward Jupyter
kubectl port-forward svc/jupyter 8888:8888

# Open browser to http://localhost:8888
# Connect to sc://localhost
```

### Troubleshoot Failed Job

```bash
# Check driver logs
kubectl logs -f deployment/spark-connect

# Check executor logs
kubectl logs -f -l spark-role=executor

# Common issues:
# - OOM: Increase executor memory
# - Slow: Add more executors
# - Connection refused: Check Spark Connect URL
```

---

## 🆘 Help & Support

### Stuck?

1. [Troubleshooting Guide](../operations/troubleshooting.md) — Decision trees
2. [Ask in Telegram](https://t.me/spark_k8s) — Community chat
3. [Open Issue](https://github.com/fall-out-bug/spark_k8s/issues) — Bug reports

### Learn More

- [Full Persona Documentation](./) — All personas
- [Architecture](../architecture/) — System design
- [Recipes](../recipes/) — How-to guides

---

**Persona:** Data Engineer
**Experience Level:** Beginner → Advanced
**Estimated Time to Productivity:** 1 day (local) → 1 week (production)
**Last Updated:** 2026-02-04
