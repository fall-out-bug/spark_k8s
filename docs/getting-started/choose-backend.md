# Choose Your Backend Mode

Spark K8s supports three execution backends. Choose based on your use case.

## Quick Comparison

| Backend | Best For | Resource Isolation | Operations Overhead |
|---------|----------|-------------------|---------------------|
| **Kubernetes (dynamic)** | General workloads, varied loads | Pod-level | Low |
| **Standalone (fixed)** | Stable production, cost optimization | Cluster-level | Medium |
| **Operator (CRD)** | GitOps, advanced control | Custom resource | Higher |

---

## Kubernetes Backend (Dynamic)

**Use when:** You want dynamic resource allocation and standard K8s operations.

### Pros
- Automatic scaling via Cluster Autoscaler
- Pod-level resource isolation
- Standard Kubernetes deployment patterns
- Works with all standard K8s tools

### Cons
- Slower pod startup (driver + executor pods)
- More K8s API calls

### When to Choose
- Variable workloads
- Development/testing environments
- Multi-tenant clusters

### Configuration

```yaml
spark:
  connect:
    mode:
      k8s:
        backend: kubernetes  # Dynamic provisioning
```

---

## Standalone Backend (Fixed Cluster)

**Use when:** You want a fixed-size cluster with faster startup.

### Pros
- Faster startup (driver runs in-driver pod)
- Simpler operations (fewer pods)
- Cost predictable (fixed size)

### Cons
- Manual scaling required
- Cluster-level resource sharing (less isolation)
- Scaling requires cluster restart

### When to Choose
- Stable production workloads
- Cost optimization (no over-provisioning)
- Development environments (fast iteration)

### Configuration

```yaml
spark:
  connect:
    mode:
      k8s:
        backend: standalone  # Fixed cluster deployment
```

---

## Spark Operator Backend

**Use when:** You want GitOps and CRD-based deployment.

### Pros
- Declarative (SparkApplication CRD)
- GitOps-friendly
- Advanced features (batch scheduling, lifecycle management)
- Native K8s integration

### Cons
- Requires Spark Operator installation
- More complex setup
- Vendor lock-in to operator patterns

### When to Choose
- Enterprise production environments
- GitOps workflows
- Multi-cluster management
- Advanced scheduling needs

### Configuration

```yaml
spark:
  connect:
    mode:
      k8s:
        backend: operator  # Spark Operator CRDs
```

---

## Decision Tree

```
Need GitOps/CRDs?
├── Yes → Operator
└── No → Need fast iteration?
    ├── Yes → Standalone
    └── No → Kubernetes (dynamic)
```

---

## Migration Between Backends

Switching backends is just a configuration change:

```bash
# From Kubernetes to Standalone
helm upgrade spark spark-k8s/spark-connect \
  --set spark.connect.mode.k8s.backend=standalone

# From Standalone to Operator
helm upgrade spark spark-k8s/spark-connect \
  --set spark.connect.mode.k8s.backend=operator
```

> **Note:** Operator requires [Spark Operator](https://github.com/apache/spark-kubernetes-operator) pre-installed.

---

## Examples

### Development: Standalone (Fast Iteration)

```yaml
spark:
  connect:
    mode:
      k8s:
        backend: standalone
  executor:
    instances: 2  # Fixed cluster size
```

### Production: Kubernetes (Auto-scaling)

```yaml
spark:
  connect:
    mode:
      k8s:
        backend: kubernetes
  executor:
    instances: min:2 max:10  # Dynamic scaling
    dynamicAllocation:
      enabled: true
```

### Enterprise: Operator (GitOps)

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-etl
spec:
  mode: cluster
  image: spark-k8s/spark:4.1.0
  mainApplicationFile: local:///app/main.py
  sparkVersion: 4.1.0
  restartPolicy: OnFailure
```

---

## Next Steps

- [Local Development Setup](local-dev.md) — Try locally first
- [Production Checklist](../operations/production-checklist.md) — Before going live

---

**Time:** 5 minutes to read
**Difficulty:** Beginner
**Last Updated:** 2026-02-04
