# Budget Alerts and Cost Management

This guide describes the budget alerting system and cost optimization practices.

## Budget Thresholds

Budget alerts are configured at three threshold levels:

| Threshold | Action | Description |
|-----------|--------|-------------|
| 50% | Warning | Notify team, review spend rate |
| 80% | Critical | Notify management, investigate anomalies |
| 100% | Blocking | Prevent non-critical jobs, require approval |

## Budget Configuration

Budgets are defined per namespace, team, or application.

### YAML Configuration

```yaml
# budgets/spark-production.yaml
apiVersion: cost.example.com/v1
kind: Budget
metadata:
  name: spark-production-monthly
  namespace: spark-prod
spec:
  period: monthly
  amount: 10000  # USD
  currency: USD
  thresholds:
    - percent: 50
      action: notify
      recipients:
        - team@company.com
    - percent: 80
      action: notify
      recipients:
        - team@company.com
        - finance@company.com
    - percent: 100
      action: block
      excludeLabels:
        - criticality: essential
```

### Prometheus Alert Rules

```yaml
# alerts/budget.yaml
groups:
  - name: budget
    interval: 1h
    rules:
      - alert: BudgetWarning50
        expr: |
          sum(spark_cost_total{namespace="spark-prod"})
          / spark_budget_limit{namespace="spark-prod"} > 0.5
        labels:
          severity: warning
          threshold: "50%"
        annotations:
          summary: "50% of budget consumed"

      - alert: BudgetCritical80
        expr: |
          sum(spark_cost_total{namespace="spark-prod"})
          / spark_budget_limit{namespace="spark-prod"} > 0.8
        labels:
          severity: critical
          threshold: "80%"
        annotations:
          summary: "80% of budget consumed"

      - alert: BudgetExceeded100
        expr: |
          sum(spark_cost_total{namespace="spark-prod"})
          / spark_budget_limit{namespace="spark-prod"} > 1.0
        labels:
          severity: emergency
          threshold: "100%"
        annotations:
          summary: "Budget exceeded!"
```

## Alert Management

### Creating a Budget

```bash
# Apply budget manifest
kubectl apply -f budgets/spark-production.yaml

# Verify
kubectl get budgets -n spark-prod
```

### Updating Budget Limits

```bash
# Edit budget
kubectl edit budget spark-production-monthly -n spark-prod

# Or via script
./scripts/operations/cost/update-budget.sh \
  --namespace spark-prod \
  --amount 15000
```

### Temporary Override

For emergency overrides:

```bash
# Add override annotation
kubectl annotate budget spark-production-monthly \
  -n spark-prod \
  override reason="Q4 surge" \
  override.until="2024-12-31"
```

## Cost Anomaly Detection

Anomalies are detected using statistical analysis of historical spend.

### Detection Methods

1. **Z-Score**: Standard deviations from mean
2. **Moving Average**: Deviation from N-day average
3. **Forecast**: Comparison to predicted spend

### Alert on Anomaly

```yaml
- alert: CostAnomalyDetected
  expr: |
    abs(
      rate(spark_cost_total[1h]) -
      avg_over_time(rate(spark_cost_total[1h])[7d:])
    ) / stddev_over_time(rate(spark_cost_total[1h])[7d:]) > 3
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Cost anomaly detected (>3σ)"
```

## Rightsizing Recommendations

### Identify Overprovisioned Jobs

```bash
./scripts/operations/cost/rightsize-jobs.sh --namespace spark-prod
```

### Metrics for Rightsizing

| Metric | Underutilized | Action |
|--------|---------------|--------|
| CPU < 20% | Yes | Reduce executor cores |
| Memory < 30% | Yes | Reduce executor memory |
| Shuffle < 10% | Yes | Reduce parallelism |
| GC > 20% | No | Increase memory |

### Example Recommendation

```
Job: etl-daily
Current: 100 executors, 4 cores, 8GB each
Recommendation: Reduce to 60 executors (40% savings)
Reason: Avg CPU 12%, Avg memory 25%
```

## Idle Resource Detection

Identify and eliminate idle resources.

### Detection Rules

1. **Idle Executors**: Running without tasks for >10 min
2. **Unused Drivers**: Drivers with no active jobs
3. **Orphaned Pods**: Pods not managed by Spark

### Idle Resource Alert

```yaml
- alert: IdleExecutors
  expr: |
    spark_executor_active_tasks == 0
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Idle executors detected"
```

### Cleanup Script

```bash
./scripts/operations/cost/cleanup-idle-resources.sh --dry-run
```

## Cost Optimization Checklist

- [ ] Review budget alerts daily
- [ ] Investigate anomalies within 1 hour
- [ ] Rightsize overprovisioned jobs
- [ ] Remove idle resources
- [ ] Use spot instances where possible
- [ ] Enable dynamic allocation
- [ ] Optimize shuffle operations
- [ ] Review data partitioning

## Emergency Procedures

### Budget Exhausted

1. **Immediate**: Pause non-critical jobs
   ```bash
   ./scripts/operations/scale-down-spark.sh --namespace spark-prod
   ```

2. **Short-term**: Request budget increase
   ```bash
   ./scripts/operations/cost/request-budget-increase.sh \
     --namespace spark-prod \
     --amount 5000 \
     --reason "Q4 surge"
   ```

3. **Long-term**: Optimize workloads

### Cost Spike Detected

1. Identify culprit:
   ```bash
   ./scripts/operations/cost/find-top-spenders.sh --hours 1
   ```

2. Kill runaway jobs:
   ```bash
   kubectl delete sparkapplication runaway-job -n spark-prod
   ```

3. Prevent recurrence:
   ```bash
   ./scripts/operations/cost/set-job-budget-limit.sh \
     --job-id runaway-job \
     --max-cost 100
   ```

## Reference

- [Cost Attribution](./cost-attribution.md)
- [Cost Breakdown Script](../../../scripts/operations/cost/cost-breakdown.sh)
- [Cost Forecast Script](../../../scripts/operations/cost/forecast-cost.sh)
