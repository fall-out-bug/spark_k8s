# Cost Attribution

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Budget Management](./budget-management.md), [Rightsizing](../capacity/rightsizing.md)

## Overview

Cost attribution assigns Spark infrastructure costs to specific jobs, teams, and projects. This enables accurate chargeback, cost optimization, and accountability.

## Cost Calculation Formula

### Per-Job Cost

```
Job Cost = Driver Cost + Executor Cost + Storage Cost + Network Cost

Driver Cost = (CPU Hours × CPU Rate) + (Memory GB-Hours × Memory Rate)
Executor Cost = Σ(Executor CPU Hours × CPU Rate + Executor Memory GB-Hours × Memory Rate)
Storage Cost = Data Size × Storage Rate × Retention Period
Network Cost = Data Transfer × Network Rate
```

### Resource-Based Rates

| Instance Type | CPU Rate | Memory Rate | Storage Rate | Network Rate |
|--------------|----------|-------------|--------------|--------------|
| **m5.xlarge** | $0.192/hr | $0.002/GB-hr | $0.023/GB | $0.09/GB |
| **m5.2xlarge** | $0.384/hr | $0.002/GB-hr | $0.023/GB | $0.09/GB |
| **m5.4xlarge** | $0.768/hr | $0.002/GB-hr | $0.023/GB | $0.09/GB |
| **Spot (m5.xlarge)** | $0.058/hr | $0.001/GB-hr | $0.023/GB | $0.09/GB |

## Cost Components

### 1. Compute Cost

**Driver Pod:**
- 24/7 uptime for streaming jobs
- Job duration for batch jobs
- CPU + memory allocation

**Executor Pods:**
- Number of executors × duration
- Dynamic allocation affects cost
- Spot vs on-demand pricing

### 2. Storage Cost

**S3/MinIO:**
- Input data storage
- Output data storage
- Intermediate shuffle data (if persisted)
- Logs storage

**Hive Metastore:**
- Metadata storage cost
- Proportional to number of objects

### 3. Network Cost

**Data Transfer:**
- Inter-zone traffic: $0.01/GB
- Inter-region traffic: $0.02/GB
- Internet egress: varies

## Cost Tracking Implementation

### Job Labels

Add cost attribution labels to Spark jobs:

```yaml
spark:
  extraLabels:
    team: data-science
    project: ml-pipeline
    cost-center: engineering-001
    environment: production
```

### Prometheus Metrics

Track cost-relevant metrics:

```yaml
# Executor seconds by job
sum(spark_executor_task_count{job_name="$JOB"}) by (pod_name)

# Memory usage
sum(container_memory_working_set_bytes{pod_name=~"spark-executor-*",job_name="$JOB"})

# CPU usage
sum(rate(container_cpu_usage_seconds_total{pod_name=~"spark-executor-*",job_name="$JOB"}[5m]))
```

### Cost Calculation Script

```bash
# Calculate job cost
scripts/operations/cost/calculate-job-cost.sh \
  --job-id spark-job-123 \
  --start-time 2026-02-01T00:00:00Z \
  --end-time 2026-02-01T01:00:00Z \
  --region us-east-1 \
  --instance-type m5.2xlarge
```

## Cost Breakdown by Component

| Component | Percentage | Driver | Executors | Storage | Network |
|-----------|------------|--------|-----------|---------|---------|
| **ETL Batch** | 100% | 5% | 85% | 8% | 2% |
| **Streaming** | 100% | 10% | 85% | 3% | 2% |
| **Interactive SQL** | 100% | 15% | 80% | 3% | 2% |

## Per-Team Cost Aggregation

### Team Definition

Teams are identified by pod labels:
```yaml
labels:
  team: data-science    # Team identifier
  project: churn-model  # Project identifier
  cost-center: eng-001  # Cost center for billing
```

### Aggregation Query

```promql
# Team cost per day
sum by (team) (
  spark_job_cost{team=~".+"}
  * on (team) group_left()
  label_replace(spark_job_cost{team="$1"}, team, "$1")
)
```

## Spot vs On-Demand Comparison

### Cost Comparison

| Job Type | On-Demand | Spot (80% savings) | Mixed (50% spot) |
|----------|-----------|---------------------|------------------|
| **Batch ETL** | $100 | $20 | $60 |
| **Streaming** | $500 | $100 | $300 |
| **Interactive** | $50 | N/A | N/A |

**Recommendation:** Use spot for batch jobs, on-demand for streaming and interactive workloads.

### Spot Interruption Cost

**Interruption Impact:**
- Job restart time: 5-10 minutes
- Data recomputation cost
- SLA impact

**Mitigation:**
- Checkpointing every 5 minutes
- Use dynamic allocation
- Save intermediate results

## Cost Forecasting

### Linear Forecasting

```
Forecast = Current Cost × (1 + Growth Rate) × Period

Example:
Current monthly cost: $10,000
Growth rate: 5% per quarter
Forecast for next quarter: $10,000 × 1.05 = $10,500
```

### Trend Analysis

```python
# Calculate trend from historical data
import numpy as np
from sklearn.linear_model import LinearRegression

# Prepare data: [cost_jan, cost_feb, cost_mar, ...]
costs = np.array([10000, 10500, 11000, 12000, 13000]).reshape(-1, 1)
months = np.array([1, 2, 3, 4, 5]).reshape(-1, 1)

model = LinearRegression()
model.fit(months, costs)

# Forecast next month
next_month = np.array([[6]])
forecast = model.predict(next_month)
print(f"Forecast for month 6: ${forecast[0]:.2f}")
```

## Cost Dashboards

### Grafana Dashboards

- **Cost by Job:** Per-job cost breakdown
- **Cost by Team:** Team-level cost aggregation
- **Cost Breakdown:** Component-wise breakdown
- **Cost Trends:** Historical and forecasted costs

### Dashboard Queries

```promql
# Cost by job (last 7 days)
sum by (job_name) (
  increase(spark_job_cost_total[7d])
)

# Cost by team (last 30 days)
sum by (team) (
  increase(spark_job_cost_total[30d])
  * on (team) group_left()
  label_replace(spark_job_cost_total{team="$1"}, team, "$1")
)

# Spot vs on-demand cost comparison
sum(rate(spark_executor_cost_spot[1h])) vs sum(rate(spark_executor_cost_ondemand[1h]))
```

## Cost Export

### Export for Billing Systems

```bash
# Export monthly cost report
./scripts/operations/cost/export-cost.sh \
  --month 2026-02 \
  --format csv \
  --output reports/cost-2026-02.csv
```

**CSV Format:**
```csv
team,project,job_id,cost_usd,driver_cost,executor_cost,storage_cost,network_cost
data-science,churn-model,spark-123,123.45,10.50,100.00,8.00,4.95
```

## Best Practices

1. **Tag all jobs:** Require team/project labels on all jobs
2. **Review monthly:** Analyze cost trends each month
3. **Set budgets:** Use cost attribution to set team budgets
4. **Optimize regularly:** Review for over-provisioned jobs
5. **Use spot instances:** For batch jobs without SLA constraints

## References

- [Budget Management](./budget-management.md)
- [Rightsizing](../capacity/rightsizing.md)
- [Cost Optimization](../capacity/cost-optimization.md)
