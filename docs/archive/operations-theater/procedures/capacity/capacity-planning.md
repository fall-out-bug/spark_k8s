# Capacity Planning Procedure

## Overview

This procedure provides guidelines for planning and managing cluster capacity for Spark on Kubernetes deployments.

## Prerequisites

- Access to cluster metrics (Prometheus/Grafana)
- Historical workload data
- Understanding of resource requirements
- Cloud cost information

## Capacity Planning Process

### Step 1: Baseline Assessment

#### 1.1. Collect Current Metrics

```bash
# Run capacity assessment script
scripts/scaling/capacity-report.sh --output baseline-$(date +%Y%m%d).json

# Collect manually:
# - Node count and types
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'

# - Pod resource requests/limits
kubectl get pods -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name) \(.spec.containers[].resources.requests.cpu) \(.spec.containers[].resources.requests.memory)"'

# - Current utilization
kubectl top nodes
kubectl top pods -A
```

#### 1.2. Analyze Historical Data

```bash
# Query Prometheus for 30-day trends
# CPU utilization
kubectl exec -n monitoring prometheus-0 -- promtool query range 'avg(rate(container_cpu_usage_seconds_total{namespace="spark-operations"}[5m]))' --start 30d --end now --step 1h

# Memory utilization
kubectl exec -n monitoring prometheus-0 -- promtool query range 'avg(container_memory_working_set_bytes{namespace="spark-operations"} / container_spec_memory_limit_bytes{namespace="spark-operations"})' --start 30d --end now --step 1h

# Job submission rate
kubectl exec -n monitoring prometheus-0 -- promtool query range 'rate(spark_job_submissions_total[5m])' --start 30d --end now --step 1h
```

#### 1.3. Identify Trends

Document patterns in:
- **Seasonal**: Monthly/quarterly spikes
- **Weekly**: Business day vs weekend
- **Daily**: Peak hours
- **Events**: Known high-load periods (e.g., month-end processing)

### Step 2: Workload Analysis

#### 2.1. Profile Job Types

Create inventory of job types:

| Job Type | Avg Duration | Peak Concurrent | CPU per Job | Memory per Job | Frequency |
|----------|-------------|------------------|-------------|---------------|-----------|
| ETL Daily | 30 min | 10 | 4 cores | 8 GB | Daily |
| Ad-hoc | 5 min | 50 | 2 cores | 4 GB | Hourly |
| ML Training | 2 hrs | 5 | 16 cores | 64 GB | Weekly |
| Reporting | 10 min | 20 | 4 cores | 16 GB | Daily |

#### 2.2. Calculate Requirements

```bash
# Use sizing calculator
scripts/scaling/calculate-executor-sizing.sh \
  --job-type etl \
  --concurrent-jobs 10 \
  --parallelism 100 \
  --data-size 1TB
```

**Formula:**
```
Total CPU = (Jobs × Executors per Job × Cores per Executor) + Buffer
Total Memory = (Jobs × Executors per Job × Memory per Executor) + Buffer
Buffer = 20-30% for dynamic allocation overhead
```

### Step 3: Future Growth Planning

#### 3.1. Estimate Growth Rate

Based on historical trends:
```
Growth Rate = (Current Usage - Usage 6 Months Ago) / Usage 6 Months Ago
```

Common factors:
- **Data volume growth**: +20-50% annually
- **User growth**: +10-30% annually
- **New use cases**: +10-20% per quarter

#### 3.2. Project Capacity Needs

```python
# Capacity projection
# For 6-month horizon:
Projected = Current × (1 + Growth_Rate × Periods)

# Example: Current 100 vCPUs, 25% annual growth, 6 months
Projected = 100 × (1 + 0.25 × 0.5) = 112.5 vCPUs
```

### Step 4: Right-sizing Strategy

#### 4.1. Determine Node Pool Configuration

**Driver Node Pool:**
- Use: Stable, on-demand instances
- Size: 10-20% of total capacity
- Instance type: Balanced CPU/memory (e.g., m5.2xlarge)

**Executor Node Pool:**
- Use: Spot instances (70-90% cost savings)
- Size: 80-90% of total capacity
- Instance type: Memory-optimized (e.g., r5.4xlarge)

**Example Configuration:**

| Node Pool | Instance Type | vCPU | Memory | Min | Max | Use Case |
|-----------|---------------|------|--------|-----|-----|----------|
| Drivers | m5.2xlarge | 8 | 32GB | 3 | 10 | Job drivers |
| Executors (spot) | r5.4xlarge | 16 | 128GB | 5 | 50 | Executors |
| Infrastructure | m5.xlarge | 4 | 16GB | 2 | 4 | Services |

#### 4.2. Set Autoscaling Bounds

```bash
# Minimum nodes: Baseline infrastructure + minimal driver capacity
min_drivers = 2  # Minimum for HA
min_executors = 5  # Minimum for dev/testing
min_infrastructure = 2
total_min = 9 nodes

# Maximum nodes: Budget limit / node cost
monthly_budget = 10000
cost_per_node = 200
total_max = monthly_budget / cost_per_node = 50 nodes
```

### Step 5: Cost Optimization

#### 5.1. Right-sizing Recommendations

```bash
# Run rightsizing analyzer
scripts/scaling/rightsizing-recommendations.sh \
  --period 30d \
  --target-utilization 70 \
  --output recommendations.json
```

**Analysis output:**
```
Nodes over-provisioned: 15 (30%)
Potential monthly savings: $3,000
Right-sizing actions:
  - Reduce 5 driver nodes from m5.2xlarge to m5.xlarge
  - Reduce executor memory requests from 16GB to 12GB
  - Enable spot instances for non-critical jobs
```

#### 5.2. Spot Instance Strategy

```
Spot Savings:
- On-demand cost: $0.408/vCPU-hour (m5.2xlarge)
- Spot cost: $0.122/vCPU-hour (70% savings)
- Annual savings: $25,000 for 100 vCPUs

Spot Best Practices:
- Use for: Executors, dev/testing, fault-tolerant workloads
- Avoid for: Stateful services, critical drivers
- Diversify across: Multiple AZs, multiple instance types
```

### Step 6: Capacity Planning Report

#### 6.1. Generate Monthly Report

```bash
# Generate comprehensive report
scripts/scaling/capacity-report.sh \
  --period 30d \
  --format markdown \
  --output reports/capacity-report-$(date +%Y%m).md
```

**Report Template:**

```markdown
# Capacity Planning Report - January 2026

## Executive Summary
- Current cluster capacity: 500 vCPUs, 2TB RAM
- Average utilization: 65% CPU, 58% Memory
- Growth rate: 8% QoQ
- Recommendations: Add 100 vCPUs by Q2

## Utilization Trends
[CPU/Memory utilization graphs]

## Capacity Projection
[6-month projection table]

## Cost Analysis
- Current monthly cost: $25,000
- Spot instance savings: $7,500 (30%)
- Rightsizing opportunities: $3,000

## Recommendations
1. Add 2 additional driver nodes by March
2. Increase max executor count to 50
3. Enable spot for 80% of executor workloads

## Action Items
- [ ] Execute node pool resize (Owner: SRE Team, Due: Feb 15)
- [ ] Update spot instance configuration (Owner: DevOps, Due: Feb 20)
- [ ] Review capacity at next planning session (Mar 1)
```

### Step 7: Review and Update

#### 7.1. Monthly Capacity Review

Meeting agenda:
1. Review utilization vs projection
2. Assess growth rate changes
3. Identify new workloads
4. Validate autoscaling effectiveness
5. Review cost optimization opportunities
6. Update capacity plan

#### 7.2. Quarterly Strategic Review

Meeting agenda:
1. Validate 6-month projections
2. Assess budget alignment
3. Plan for major events (e.g., Black Friday)
4. Review architecture changes
5. Update capacity strategy

## Monitoring and Alerts

### Capacity Alerts

```yaml
# Prometheus alert rules
groups:
- name: capacity
  rules:
  - alert: ClusterCapacityInsufficient
    expr: |
      (sum(kube_node_status_capacity{resource="cpu"})
       /
       sum(spark_executor_cores{state="running"} * spark_executor_count)) < 1.2
    for: 15m
    annotations:
      summary: "Cluster near capacity"
      description: "CPU utilization approaching 90% for 15 minutes"

  - alert: CapacityProjectionExceeded
    expr: |
      predict_linear(cluster_cpu_usage[7d], 30*24*3600) > cluster_capacity * 0.9
    annotations:
      summary: "Capacity will be exceeded in 30 days"
```

## Reference Data

### Instance Type Reference

| Instance | vCPUs | Memory | Cost/hr (On-Demand) | Cost/hr (Spot) | Use Case |
|----------|-------|--------|---------------------|----------------|----------|
| m5.xlarge | 4 | 16GB | $0.204 | $0.058 | Small drivers |
| m5.2xlarge | 8 | 32GB | $0.408 | $0.122 | Medium drivers |
| m5.4xlarge | 16 | 64GB | $0.816 | $0.239 | Large drivers |
| r5.2xlarge | 8 | 64GB | $0.504 | $0.158 | Memory-bound executors |
| r5.4xlarge | 16 | 128GB | $1.008 | $0.295 | Large executors |

### Sizing Calculator

```bash
# Quick sizing calculation
# Inputs: concurrent_jobs, tasks_per_job, task_duration_sec

# Example: 20 jobs, 1000 tasks each, 30s per task
# Total tasks = 20 × 1000 = 20,000 tasks
# Task throughput per core = 8 tasks/30s (assuming 8 threads)
# Cores needed = 20,000 / (8 tasks/core) = 2,500 cores
# With 16-core nodes = 157 nodes

# Add 30% buffer for overhead
# 157 × 1.3 = 204 nodes max

# Minimum: 10 nodes for baseline
# Target: 100 nodes for average load
# Maximum: 204 nodes for peak
```

## Related Procedures

- [Horizontal Pod Autoscaler](../runbooks/scaling/horizontal-pod-autoscaler.md)
- [Cluster Scaling](../runbooks/scaling/cluster-scaling.md)
- [Cost Attribution](./cost-attribution.md)

## References

- [Spark Capacity Planning Guide](https://spark.apache.org/docs/latest/cluster-overview.html)
- [Kubernetes Capacity Planning](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- [Cost Optimization Best Practices](https://aws.amazon.com/blogs/architecture/cost-optimization-for-apache-spark-on-amazon-eks/)
