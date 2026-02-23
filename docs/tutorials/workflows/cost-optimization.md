# Cost Optimization Tutorial

Learn strategies and techniques to optimize Spark job costs on Kubernetes.

## Overview

This tutorial covers:
1. Rightsizing resources
2. Using spot instances
3. Dynamic resource allocation
4. Cost monitoring and alerts

## Prerequisites

- Kubernetes cluster with spot instance support
- Prometheus metrics configured
- Cost monitoring tools

## Tutorial: Optimize a Daily ETL Job

### Step 1: Analyze Current Costs

```bash
# Get job cost breakdown
./scripts/operations/cost/calculate-job-cost.sh \
  --namespace spark-prod \
  --app-id daily-etl-job \
  --start-date 2024-01-01 \
  --end-date 2024-01-31

# Output:
# Total cost: $456.78
# Driver: $23.45 (5%)
# Executors: $433.33 (95%)
```

### Step 2: Identify Optimization Opportunities

```python
# analyze_job.py
from pyspark.sql import SparkSession
import json

def analyze_job_performance(app_id):
    """Analyze job metrics for optimization."""
    spark = SparkSession.builder \
        .appName("job-analysis") \
        .getOrCreate()

    # Query Prometheus for metrics
    import requests

    prometheus_url = "http://prometheus.observability.svc.cluster.local:9090"

    queries = {
        "executor_count": f'sum(spark_executor_count{{app_id="{app_id}"}})',
        "avg_cpu": f'avg(rate(spark_executor_cpu_time_seconds_total{{app_id="{app_id}"}}[5m]))',
        "avg_memory": f'avg(spark_executor_memory_used_bytes{{app_id="{app_id}"}})',
        "gc_time": f'avg(rate(jvm_gc_time_seconds{{app_id="{app_id}"}}[5m])) * 100',
        "shuffle_read": f'sum(spark_task_shuffle_read_bytes{{app_id="{app_id}"}})',
        "shuffle_write": f'sum(spark_task_shuffle_write_bytes{{app_id="{app_id}"}})',
    }

    metrics = {}
    for name, query in queries.items():
        response = requests.get(
            f"{prometheus_url}/api/v1/query",
            params={"query": query}
        )
        result = response.json()
        if result["data"]["result"]:
            metrics[name] = float(result["data"]["result"][0]["value"][1])

    # Analyze and recommend
    recommendations = []

    # CPU underutilized
    if metrics["avg_cpu"] < 0.3:
        recommendations.append({
            "issue": "CPU underutilized",
            "current": f"{metrics['avg_cpu']:.1%}",
            "recommendation": "Reduce executor cores or increase parallelism"
        })

    # Memory pressure
    if metrics["gc_time"] > 20:
        recommendations.append({
            "issue": "High GC time",
            "current": f"{metrics['gc_time']:.1f}%",
            "recommendation": "Increase executor memory"
        })

    # Large shuffle
    if metrics["shuffle_write"] > 100_000_000_000:  # 100GB
        recommendations.append({
            "issue": "Large shuffle",
            "current": f"{metrics['shuffle_write'] / 1e9:.1f}GB",
            "recommendation": "Consider map-side aggregation or partitioning"
        })

    print(json.dumps(recommendations, indent=2))

    return recommendations

if __name__ == "__main__":
    analyze_job_performance("daily-etl-job")
```

### Step 3: Apply Optimizations

#### 3.1 Enable Dynamic Allocation

```python
# Optimized configuration
config = {
    # Dynamic allocation
    "spark.dynamicAllocation.enabled": "true",
    "spark.dynamicAllocation.minExecutors": "2",
    "spark.dynamicAllocation.maxExecutors": "20",
    "spark.dynamicAllocation.initialExecutors": "5",
    "spark.dynamicAllocation.executorIdleTimeout": "60s",
    "spark.dynamicAllocation.schedulerBacklogTimeout": "5s",

    # Shuffle optimization
    "spark.sql.shuffle.partitions": "200",
    "spark.shuffle.compress": "true",
    "spark.shuffle.spill.compress": "true",

    # Memory optimization
    "spark.executor.memoryOverhead": "1g",
    "spark.memory.fraction": "0.8",
    "spark.memory.storageFraction": "0.3",

    # Parallelism
    "spark.default.parallelism": "200",
    "spark.sql.context.spark.sql.partitions": "200",
}
```

#### 3.2 Use Spot Instances

```yaml
# manifests/spot-optimized-job.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: daily-etl-optimized
  namespace: spark-prod
spec:
  type: Python
  mode: cluster
  image: your-registry/spark-jobs:latest
  mainApplicationFile: local:///app/jobs/daily_etl.py

  # Use spot instances for executors
  executor:
    cores: 4
    instances: 10  # Max instances
    memory: "8g"
    memoryOverhead: "1g"
    # Spot instance configuration
    nodeSelector:
      node.kubernetes.io/instance-type: "spot"
    tolerations:
    - key: "spot-instance"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  # Use on-demand for driver
  driver:
    cores: 2
    memory: "4g"
    nodeSelector:
      node.kubernetes.io/instance-type: "on-demand"

  # Dynamic allocation
  sparkConf:
    spark.dynamicAllocation.enabled: "true"
    spark.dynamicAllocation.minExecutors: "2"
    spark.dynamicAllocation.maxExecutors: "20"
    spark.dynamicAllocation.initialExecutors: "5"
```

### Step 4: Monitor Cost Impact

```bash
# Before optimization
./scripts/operations/cost/calculate-job-cost.sh --app-id daily-etl-regular
# Result: $456.78 for January

# After optimization (run for February)
./scripts/operations/cost/calculate-job-cost.sh --app-id daily-etl-optimized
# Result: $234.56 for February (49% savings!)
```

### Step 5: Set Budget Alerts

```yaml
# Cost alert configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: budget-alerts
data:
  budget.yaml: |
    budgets:
      - name: daily-etl-monthly
        amount: 300  # USD
        period: monthly
        thresholds:
          - percent: 80
            action: notify
          - percent: 100
            action: throttle
```

## Optimization Strategies

### 1. Rightsize Resources

```python
# Calculate optimal executor count
def calculate_optimal_executors(data_size_gb, executor_memory_gb):
    """Calculate optimal number of executors."""
    # Each core processes ~2-3GB
    cores_per_executor = 4
    data_per_core_gb = 2

    required_cores = data_size_gb / data_per_core_gb
    executors = int(required_cores / cores_per_executor)

    return max(2, min(executors, 100))  # Between 2 and 100
```

### 2. Optimize Shuffle

```python
# Reduce shuffle
df = df \
    .filter(col("status") == "active") \
    .select("user_id", "amount") \
    .coalesce(100)  # Reduce partitions before shuffle

# Broadcast small tables
from pyspark.sql.functions import broadcast

result = large_df.join(
    broadcast(small_df),
    "user_id"
)
```

### 3. Cache Wisely

```python
# Cache only what's needed
df = spark.read.parquet("s3a://data/large")

# Cache filtered data instead
active_df = df.filter(col("status") == "active").cache()

# Use appropriate storage level
from pyspark.storagelevel import StorageLevel
df_cached = df.persist(StorageLevel.MEMORY_AND_DISK_SER)
```

### 4. Schedule Optimization

```yaml
# Run during cheaper hours
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: off-hours-etl
spec:
  # Schedule for off-peak hours (cheaper spot rates)
  schedule: "0 2 * * *"  # 2 AM
  restartPolicy:
    type: OnFailure
    onSubmissionFailureRetries: 3
```

## Cost Monitoring Dashboard

Create a Grafana dashboard to track costs:

```json
{
  "title": "Spark Job Costs",
  "panels": [
    {
      "title": "Daily Job Cost",
      "targets": [
        {
          "expr": "sum(increase(spark_cost_total[1d])) by (app_id)"
        }
      ]
    },
    {
      "title": "Cost per GB Processed",
      "targets": [
        {
          "expr": "sum(spark_cost_total) / sum(spark_input_bytes_total) / 1e9"
        }
      ]
    },
    {
      "title": "Spot vs On-Demand Cost",
      "targets": [
        {
          "expr": "sum(spark_cost_total{instance_type=\"spot\"})",
          "legendFormat": "Spot"
        },
        {
          "expr": "sum(spark_cost_total{instance_type=\"on-demand\"})",
          "legendFormat": "On-Demand"
        }
      ]
    }
  ]
}
```

## Best Practices Summary

| Practice | Impact |
|----------|--------|
| Use spot instances | 50-70% savings |
| Enable dynamic allocation | 30-40% savings |
| Rightsize executors | 20-30% savings |
| Optimize shuffle | 15-25% savings |
| Schedule off-peak | 10-20% savings |

## Checklist

- [ ] Analyze current job costs
- [ ] Identify optimization opportunities
- [ ] Enable dynamic allocation
- [ ] Configure spot instances
- [ ] Set budget alerts
- [ ] Monitor cost impact
- [ ] Document optimization results

## Next Steps

- [ ] Implement automated rightsizing
- [ ] Set up multi-region execution
- [ ] Create cost anomaly detection
- [ ] Build cost optimization dashboard

## Related

- [Budget Alerts](../../docs/operations/procedures/cost/budget-alerts.md)
- [Cost Attribution](../../docs/operations/procedures/cost/cost-attribution.md)
