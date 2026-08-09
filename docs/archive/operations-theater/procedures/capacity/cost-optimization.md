# Cost Optimization Strategies

> **Last Updated:** 2026-02-11
> **Owner:** Platform Team
> **Related:** [Rightsizing](./rightsizing.md), [Budget Management](../cost/budget-management.md)

## Overview

This guide covers cost optimization strategies for Spark on Kubernetes deployments, focusing on reducing cloud infrastructure costs while maintaining performance and reliability.

## Cost Optimization Strategies

### 1. Dynamic Allocation

Enable Spark dynamic allocation to scale executors based on workload:

```yaml
spark:
  dynamicAllocation:
    enabled: true
    initialExecutors: 2
    minExecutors: 2
    maxExecutors: 100
    executorIdleTimeout: 60s
    cachedExecutorIdleTimeout: 120s
```

**Savings:** 30-60% for batch workloads with variable load.

### 2. Spot/Preemptible Instances

Use spot instances for non-critical workloads:

```yaml
executor:
  nodeSelector:
    cloud.google.com/gke-preemptible: "true"
  tolerations:
    - key: cloud.google.com/gke-preemptible
      operator: Equal
      value: "true"
      effect: NoSchedule
```

**Considerations:**
- Use for batch jobs, not streaming
- Implement checkpointing for fault tolerance
- Set appropriate Pod Disruption Budgets

**Savings:** 60-80% compared to on-demand instances.

### 3. Rightsizing Resources

Regularly review and adjust resource allocations:

```bash
# Generate rightsizing report
./scripts/operations/scaling/rightsizing-recommendations.sh \
  --namespace spark-prod \
  --days 30
```

Target utilization: **70-80%** for CPU and memory.

**Savings:** 20-40% by eliminating over-provisioning.

### 4. Optimize Shuffle Operations

Reduce shuffle overhead:

```properties
# Enable compression
spark.shuffle.compress=true
spark.shuffle.spill.compress=true

# Tune shuffle file size
spark.executor.memoryOverhead=2g

# Consider Celeborn for large shuffles
spark.shuffle.service.enabled=true
```

**Savings:** 15-30% reduction in network and storage costs.

### 5. Auto-Terminate Idle Resources

Automatically terminate idle clusters:

```yaml
# Auto-termination policy
spark:
  idleTimeout: 1800  # 30 minutes
```

For interactive environments, use Kubernetes TTL controller:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-driver
spec:
  ttlSecondsAfterFinished: 3600  # 1 hour
```

### 6. Use Appropriate Storage Tiers

Match storage to workload requirements:

| Data Type | Storage Class | Cost | Use Case |
|-----------|---------------|------|----------|
| **Hot** | ssd | $$ | Frequent access, shuffle |
| **Warm** | standard | $ | Intermediate data |
| **Cold** | cold/nearline | $ | Archive, backups |

**Savings:** 40-70% by using appropriate storage tiers.

### 7. Schedule Workloads for Off-Peak Hours

Run non-urgent batch jobs during off-peak hours:

```yaml
# Kubernetes Time-of-Sky scheduling
nodeSelector:
  workload-type: "batch-offpeak"
```

**Savings:** 30-50% for time-flexible workloads.

### 8. Enable Resource Quotas

Set resource quotas per team/namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: spark-team-quota
  namespace: spark-team-a
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 400Gi
    limits.cpu: "200"
    limits.memory: 800Gi
```

## Cost Monitoring

### Cost Attribution

Track costs by job, team, and project:

```bash
# Calculate job costs
./scripts/operations/cost/calculate-job-cost.sh \
  --job-id spark-job-123 \
  --start-time 2026-02-01 \
  --end-time 2026-02-08
```

### Cost Dashboards

View costs in Grafana:
- Cost by Job (`cost-by-job.json`)
- Cost by Team (`cost-by-team.json`)
- Cost Breakdown (`cost-breakdown.json`)
- Cost Trends (`cost-trends.json`)

### Budget Alerts

Set up budget alerts:
```yaml
budgets:
  - name: team-a-monthly
    period: monthly
    limit: 5000
    currency: USD
    alerts:
      - at: 50%  # $2500
      - at: 80%  # $4000
      - at: 100% # $5000
```

## Cost Optimization Checklist

### Daily
- [ ] Review cost dashboard for anomalies
- [ ] Check for orphaned resources
- [ ] Verify spot instance usage

### Weekly
- [ ] Review over-provisioned applications
- [ ] Generate cost attribution report
- [ ] Check budget status

### Monthly
- [ ] Conduct rightsizing review
- [ ] Analyze cost trends
- [ ] Review storage costs
- [ ] Optimize instance types

### Quarterly
- [ ] Conduct architecture review
- [ ] Evaluate new cloud pricing models
- [ ] Update cost baseline
- [ ] Review reserved instance contracts

## Cost Calculation Formula

```
Job Cost = (Driver Cost) + (Executor Cost) + (Storage Cost) + (Network Cost)

Driver Cost = Driver Duration × Driver Instance Rate
Executor Cost = Σ(Executor Duration × Executor Instance Rate)
Storage Cost = Data Size × Storage Rate × Retention Period
Network Cost = Data Transfer × Network Rate
```

Example for a 1-hour batch job:
- Driver: 1 × m5.xlarge ($0.192/hr) = $0.192
- Executors: 10 × m5.2xlarge ($0.384/hr) = $3.84
- Storage: 500GB × $0.023/GB/month = $11.50/month
- Network: 100GB × $0.09/GB = $9.00
- **Total: ~$13/hour**

## ROI Analysis

### Cost vs. Performance Trade-offs

| Strategy | Cost Reduction | Performance Impact | Use Case |
|----------|---------------|-------------------|----------|
| **Spot Instances** | 60-80% | Potential interruption | Batch jobs |
| **Dynamic Allocation** | 30-60% | None (or improved) | Variable workloads |
| **Rightsizing** | 20-40% | None | All workloads |
| **Compression** | 15-30% | Minimal CPU overhead | I/O intensive |
| **Off-Peak Scheduling** | 30-50% | Delayed processing | Non-urgent jobs |

### When to Optimize

Optimize when monthly costs exceed:
- **Development:** $100/month
- **Testing:** $500/month
- **Production:** $2,000/month

## Troubleshooting

### High Costs Despite Optimization

1. **Check for leaks:** Orphaned pods, unreleased storage
2. **Review spot instance replacement rate:** High churn increases costs
3. **Verify cost attribution:** Ensure costs are correctly assigned
4. **Analyze data transfer:** Cross-region/AZ transfers are expensive

### Cost Spike Alert

If costs spike unexpectedly:
1. Identify the responsible application/team
2. Check for runaway jobs or infinite loops
3. Verify spot instance availability
4. Review recent configuration changes

## References

- [AWS Spot Instances](https://aws.amazon.com/ec2/spot/)
- [GKE Preemptible VMs](https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms)
- [Azure Spot VMs](https://docs.microsoft.com/azure/virtual-machines/spot-vms)
- [Spark Tuning Guide](https://spark.apache.org/docs/latest/tuning.html)
- [Cost Attribution](../cost/cost-attribution.md)
