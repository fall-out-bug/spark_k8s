# Auto-Scaling Guide for Spark on Kubernetes

This guide covers auto-scaling options for Spark K8s Constructor to optimize resource utilization and reduce costs.

## Overview

Spark K8s Constructor supports multiple auto-scaling mechanisms:

1. **Dynamic Allocation** (built-in Spark) - Automatically scales executors based on workload
2. **Cluster Autoscaler** (Kubernetes) - Scales node pools based on pod pending state
3. **KEDA** (Kubernetes Event-driven Autoscaling) - Scales based on external metrics (e.g., S3 queue depth)

## Dynamic Allocation

Dynamic Allocation is enabled by default and allows Spark to add/remove executors based on workload.

### Configuration

```yaml
connect:
  dynamicAllocation:
    enabled: true
    minExecutors: 0
    maxExecutors: 10
    initialExecutors: 2
```

### Key Parameters

| Parameter | Description | Default | Recommendation |
|-----------|-------------|---------|----------------|
| `enabled` | Enable dynamic allocation | `true` | Keep enabled for production |
| `minExecutors` | Minimum number of executors | `0` | Use `0` for cost optimization |
| `maxExecutors` | Maximum number of executors | `10` | Based on cluster capacity |
| `initialExecutors` | Initial executors to request | `minExecutors` | Use `1-2` for faster startup |

### Tuning Guidelines

```yaml
connect:
  sparkConf:
    # Shuffle tracking for better scaling
    "spark.dynamicAllocation.shuffleTracking.enabled": "true"
    # Timeout for idle executors
    "spark.dynamicAllocation.executorIdleTimeout": "60s"
    # Cached executor idle timeout
    "spark.dynamicAllocation.cachedExecutorIdleTimeout": "2m"
    # Scheduler backlog timeout
    "spark.dynamicAllocation.schedulerBacklogTimeout": "1s"
    # Sustained scheduler backlog timeout
    "spark.dynamicAllocation.sustainedSchedulerBacklogTimeout": "5s"
```

## Cluster Autoscaler

Cluster Autoscaler scales Kubernetes nodes based on pending pods. This is useful for spot instance pools.

### Enable Cluster Autoscaler

```yaml
autoscaling:
  clusterAutoscaler:
    enabled: true
    scaleDown:
      enabled: true
      delayAfterAdd: 10m
      unneededTime: 5m
      unreadyTime: 20m
      utilizationThreshold: 0.5
    nodeGroups:
      - name: spark-spot-pool
        minSize: 0
        maxSize: 50
```

### Configuration Guide

| Parameter | Description | Default | Recommendation |
|-----------|-------------|---------|----------------|
| `scaleDown.enabled` | Enable scale down | `true` | Enable for cost savings |
| `scaleDown.delayAfterAdd` | Delay before scaling down after add | `10m` | Use `5-10m` for spot pools |
| `scaleDown.unneededTime` | Time node is unneeded before scale down | `5m` | Use `3-5m` for aggressive scaling |
| `scaleDown.utilizationThreshold` | CPU utilization threshold | `0.5` | Use `0.4-0.5` for cost optimization |

### Node Group Discovery

For AWS EKS:
```yaml
autoscaling:
  clusterAutoscaler:
    nodeGroups:
      - name: spark-spot-pool
        tags:
          - k8s.io/cluster-autoscaler/enabled
          - k8s.io/cluster-autoscaler/spark-4.1
```

For GCP GKE:
```yaml
autoscaling:
  clusterAutoscaler:
    nodeGroups:
      - name: spark-spot-pool
        labels:
          cloud.google.com/gke-preemptible: "true"
```

## KEDA S3 Scaler

KEDA can scale Spark Connect based on S3 queue depth (pending jobs).

### Enable KEDA S3 Scaler

```yaml
autoscaling:
  keda:
    enabled: true
    pollingInterval: 30
    cooldownPeriod: 300
    minReplicaCount: 0
    maxReplicaCount: 10
    s3:
      bucket: "spark-jobs"
      prefix: "pending/"
      targetObjectSize: "5"
      region: "us-east-1"
      accessKey: "${AWS_ACCESS_KEY_ID}"
      secretKey: "${AWS_SECRET_ACCESS_KEY}"
```

### How It Works

1. KEDA polls S3 bucket for objects in `pending/` prefix
2. When object count exceeds threshold, scales up Spark Connect deployment
3. After cooldown period, scales down to minimum

### Best Practices

- Use separate S3 prefixes for different environments
- Set `targetObjectSize` based on average job complexity
- Use longer `cooldownPeriod` for batch workloads

## Cost-Optimized Preset

A ready-to-use preset for cost optimization using spot instances:

```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/cost-optimized-values.yaml
```

This preset includes:
- Spot instance configuration
- Aggressive dynamic allocation
- Fault-tolerant Spark settings
- Cluster Autoscaler integration

## Rightsizing Calculator

Calculate optimal executor sizing for your workloads:

```bash
# Calculate for 1TB data with medium executors
python scripts/rightsizing_calculator.py \
  --data-size 1TB \
  --executor-preset medium

# Calculate with cluster limits
python scripts/rightsizing_calculator.py \
  --data-size 10TB \
  --executor-preset large \
  --cluster-cores 500 \
  --cluster-memory 2000

# Get Helm values snippet
python scripts/rightsizing_calculator.py \
  --data-size 5TB \
  --executor-preset medium \
  --helm-values
```

### Calculator Output

```
======================================================================
SPARK RIGHTSIZE CALCULATOR
======================================================================

Executor Configuration: Medium
  Description: General-purpose workloads

Recommended Settings:
  Executors: 50
  Min Executors: 12
  Max Executors: 100

Executor Resources:
  Cores: 2
  Memory: 4G
  Memory Overhead: 512m
  Cores Limit: 2
  Memory Limit: 8G

Driver Resources:
  Cores: 4
  Memory: 4G

Total Resources:
  Memory: 204.0 GB
  Cores: 100

Estimated Cost: $2.04 - $6.12

Justification: Data size: 1.0TB requires 8192 executors for parallelism
and 3 executors for memory. Using Medium executors (General-purpose workloads).

======================================================================
```

## Spot Instance Considerations

### When to Use Spot Instances

✅ **Good for:**
- Fault-tolerant batch workloads
- ETL jobs with checkpointing
- Data processing with retries
- Development/testing environments

❌ **Not suitable for:**
- Interactive queries requiring low latency
- Stateful streaming without checkpointing
- Jobs without retry logic

### Spot Configuration

```yaml
connect:
  executor:
    # Enable fault tolerance
  sparkConf:
    "spark.task.maxFailures": "8"
    "spark.stage.maxConsecutiveAttempts": "4"
    "spark.speculation": "true"
    "spark.speculation.multiplier": "1.5"

  nodeSelector:
    eks.amazonaws.com/capacityType: "SPOT"

  tolerations:
    - key: "spot-instance"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

## Monitoring Auto-Scaling

### Prometheus Metrics

Key metrics to monitor:

- `spark_executor_count`: Current executor count
- `spark_executor_memory_bytes`: Total executor memory
- `cluster_autoscaler_cluster_safe_to_autoscale`: Cluster can scale
- `cluster_autoscaler_node_count_total`: Total nodes in cluster
- `keda_scaled_object_status`: KEDA scaling status

### Grafana Dashboards

Use the "Spark Job Performance" dashboard to monitor:
- Executor count over time
- Memory utilization
- Task completion rates
- Job durations

## Cost Optimization Best Practices

1. **Always use Dynamic Allocation** for production workloads
2. **Set minExecutors=0** for dev/test environments
3. **Use spot instances** for fault-tolerant batch jobs
4. **Enable Cluster Autoscaler** for variable workloads
5. **Right-size executors** using the calculator
6. **Monitor executor utilization** and adjust settings
7. **Use cost-optimized preset** as starting point
8. **Set aggressive scale-down** for spot pools (3-5 min unneeded)
9. **Enable shuffle tracking** for better scaling decisions
10. **Use speculation** for spot instance workloads

## Troubleshooting

### Executors Not Scaling Down

**Problem:** Executors stay allocated after job completes

**Solutions:**
1. Check idle timeout: `spark.dynamicAllocation.executorIdleTimeout`
2. Ensure shuffle service is enabled: `spark.shuffle.service.enabled`
3. Verify no cached data: Check Spark UI for storage

### Cluster Autoscaler Not Scaling

**Problem:** Nodes not added despite pending pods

**Solutions:**
1. Check node group labels match Cluster Autoscaler config
2. Verify max node limit not reached
3. Check Cluster Autoscaler logs: `kubectl logs -n kube-system deployment/cluster-autoscaler`

### Spot Instance Preemptions

**Problem:** Jobs failing due to spot preemption

**Solutions:**
1. Increase `spark.task.maxFailures` to 8+
2. Enable speculation: `spark.speculation=true`
3. Use checkpointing for streaming jobs
4. Mix spot and on-demand instances

## Further Reading

- [Spark Dynamic Allocation](https://spark.apache.org/docs/latest/job-scheduling.html#dynamic-resource-allocation)
- [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/README.md)
- [KEDA Scalers](https://keda.sh/docs/2.10/scalers/)
