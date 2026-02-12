# Rightsizing Recommendations

> **Last Updated:** 2026-02-11
> **Owner:** Platform Team
> **Related:** [Capacity Planning](./capacity-planning.md), [Cost Optimization](./cost-optimization.md)

## Overview

Rightsizing is the process of adjusting Spark application resources to match actual workload requirements. This guide provides recommendations and procedures for rightsizing Spark deployments on Kubernetes.

## Rightsizing Principles

### 1. Right-Size, Not Over-Provision

- **Driver:** 1-2 CPU cores, 2-4GB memory for most workloads
- **Executor:** Match to worker instance types (e.g., 4-8 cores, 16-32GB)
- **Dynamic Allocation:** Enable for batch workloads
- **Max Executors:** Set based on cluster capacity, not infinity

### 2. Monitor Utilization Metrics

Key Prometheus metrics to monitor:
```
# CPU utilization
sum(rate(container_cpu_usage_seconds_total{pod_name=~"spark-executor-*"}[5m])) /
sum(kube_pod_container_resource_limits{pod_name=~"spark-executor-*",resource="cpu"})

# Memory utilization
sum(container_memory_working_set_bytes{pod_name=~"spark-executor-*"}) /
sum(kube_pod_container_resource_limits{pod_name=~"spark-executor-*",resource="memory"})
```

Target utilization: **60-80%** for both CPU and memory.

### 3. Profile Workload Characteristics

| Workload Type | Driver Cores | Driver Memory | Executor Cores | Executor Memory | Max Executors |
|--------------|-------------|---------------|----------------|-----------------|---------------|
| **Interactive (SQL)** | 1 | 2GB | 2-4 | 8-16GB | 10-50 |
| **Batch (ETL)** | 2 | 4GB | 4-8 | 16-32GB | 50-200 |
| **ML Training** | 4 | 8GB | 8-16 | 32-64GB | 20-100 |
| **Streaming** | 2 | 4GB | 4-8 | 16-32GB | Fixed |

## Rightsizing Procedure

### Step 1: Gather Current Resource Usage

```bash
# Run the rightsizing recommendations script
./scripts/operations/scaling/rightsizing-recommendations.sh --namespace spark-prod --days 7
```

Output includes:
- Average/max CPU and memory utilization
- Over-provisioned applications (utilization < 50%)
- Under-provisioned applications (OOM kills, high GC)
- Recommended resource settings

### Step 2: Review Application Metrics

For each application, review:
1. **Spark UI:** Tasks duration, shuffle read/write, GC time
2. **Prometheus:** Resource utilization over time
3. **Loki Logs:** OOM kills, GC warnings, task failures

### Step 3: Calculate Right-Sized Resources

Use the executor sizing calculator:
```bash
./scripts/operations/scaling/calculate-executor-sizing.sh \
  --input-data-size 1TB \
  --num-partitions 1000 \
  --memory-per-partition 256MB
```

### Step 4: Apply Changes in Staging

1. Update values.yaml with new resource requests
2. Deploy to staging namespace
3. Run test workload
4. Verify performance is not degraded

### Step 5: Promote to Production

```bash
# Deploy updated configuration
helm upgrade spark-app ./charts/spark-4.1 \
  --namespace spark-prod \
  --values values-rightsized.yaml
```

## Common Rightsizing Scenarios

### Scenario 1: High CPU, Low Memory

**Symptoms:**
- CPU utilization > 90%
- Memory utilization < 50%

**Solution:**
- Increase executor cores (e.g., 4 → 8)
- Keep memory constant
- Consider larger instance types

### Scenario 2: Low CPU, High Memory

**Symptoms:**
- CPU utilization < 50%
- Memory utilization > 80%

**Solution:**
- Decrease executor memory
- Increase number of executors (keep total memory constant)
- Tune spark.executor.memoryOverhead

### Scenario 3: Frequent OOM Kills

**Symptoms:**
- Executor pods killed with OOMKilled
- Container heap usage near limit

**Solution:**
- Increase executor memory
- Tune spark.memory.fraction and spark.memory.storageFraction
- Reduce partitions (less memory per task)

### Scenario 4: Excessive Shuffle

**Symptoms:**
- High shuffle read/write times
- Network saturation

**Solutions:**
- Increase executor memory for shuffle buffer
- Enable shuffle file compression (spark.shuffle.compress=true)
- Consider Celeborn for shuffle service

## Automation

### Automated Rightsizing Report

Weekly automated report:
```bash
./scripts/operations/scaling/rightsizing-recommendations.sh \
  --report-format json \
  --output reports/rightsizing-$(date +%Y%m%d).json
```

### Alert on Over-Provisioning

Prometheus alert:
```yaml
- alert: SparkOverProvisioned
  expr: |
    sum(kube_pod_container_resource_limits{pod_name=~"spark-executor-*"}) /
    sum(container_memory_working_set_bytes{pod_name=~"spark-executor-*"}) > 2
  for: 24h
  annotations:
    summary: "Spark application {{ $labels.app_name }} is over-provisioned"
```

## Best Practices

1. **Start Small, Scale Up:** Begin with conservative estimates, scale based on metrics
2. **Use Dynamic Allocation:** Let Spark scale executors based on workload
3. **Set Resource Limits:** Always set CPU and memory limits
4. **Monitor GC Time:** High GC indicates memory pressure
5. **Profile Regularly:** Workloads change over time, review quarterly
6. **Test Changes:** Always validate in staging before production

## References

- [Spark Configuration Guide](https://spark.apache.org/docs/latest/configuration.html)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Prometheus Query Examples](../monitoring/sli-slo-definitions.md)
