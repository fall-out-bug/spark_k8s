# Budget Management Procedure

## Overview

This procedure defines the process for setting up, monitoring, and managing cost budgets for Spark on Kubernetes deployments.

## Budget Definition

### Budget Structure

Budgets are defined at multiple levels:

1. **Team Budgets**: Per-team spending limits
2. **Project Budgets**: Per-project spending limits
3. **Cluster Budgets**: Overall cluster spending limits
4. **Component Budgets**: Per-component limits (e.g., executors, storage)

### Budget Configuration

Budgets are stored as Kubernetes ConfigMaps:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-budgets
  namespace: spark-operations
data:
  budgets.yaml: |
    teams:
      data-science:
        monthly_budget: 5000
        alert_thresholds:
          warning: 70  # 70% of budget
          critical: 90  # 90% of budget
          exceed: 100  # 100% of budget
      data-engineering:
        monthly_budget: 3000
        alert_thresholds:
          warning: 70
          critical: 90
          exceed: 100
      analytics:
        monthly_budget: 2000
        alert_thresholds:
          warning: 70
          critical: 90
          exceed: 100

    projects:
      ml-pipeline:
        monthly_budget: 1000
      etl-jobs:
        monthly_budget: 500
      reporting:
        monthly_budget: 300

    cluster:
      monthly_budget: 10000
      alert_thresholds:
        warning: 75
        critical: 95
        exceed: 100
```

## Budget Monitoring

### Daily Budget Checks

```bash
# Check budget status
scripts/operations/cost/check-budget.sh --period daily

# Output example:
# Team: data-science
#   Budget: $5,000
#   Current: $3,500 (70%)
#   Forecast: $5,200 (104%)
#   Status: WARNING
```

### Weekly Budget Reports

```bash
# Generate weekly budget report
scripts/operations/cost/check-budget.sh --period weekly --output weekly-budget-report.md

# Report includes:
# - Budget vs actual spending
# - Spending trends
# - Forecast for month end
# - Over/under budget items
# - Cost optimization opportunities
```

### Monthly Budget Reviews

Monthly reviews include:
- Actual vs budget comparison
- Variance analysis
- Trend analysis
- Next month forecasting
- Budget adjustment recommendations

## Budget Alerts

### Alert Thresholds

| Threshold | Trigger | Action |
|-----------|---------|--------|
| Warning | 70% of budget | Notify team lead |
| Critical | 90% of budget | Notify team + manager |
| Exceed | 100% of budget | Notify all + consider auto-disable |

### Alert Configuration

Prometheus alert rules:

```yaml
groups:
- name: budget_alerts
  rules:
  - alert: TeamBudgetWarning
    expr: |
      (sum by (team) (spark_job_cost_total{namespace="spark-operations"})
       /
       sum by (team) (kube_configmap_data{configmap="cost-budgets",key="monthly_budget"})) > 0.7
    for: 1h
    annotations:
      summary: "Team {{ $labels.team }} at 70% of budget"
    labels:
      severity: warning

  - alert: TeamBudgetCritical
    expr: |
      (sum by (team) (spark_job_cost_total{namespace="spark-operations"})
       /
       sum by (team) (kube_configmap_data{configmap="cost-budgets",key="monthly_budget"})) > 0.9
    for: 15m
    annotations:
      summary: "Team {{ $labels.team }} at 90% of budget"
    labels:
      severity: critical

  - alert: TeamBudgetExceeded
    expr: |
      (sum by (team) (spark_job_cost_total{namespace="spark-operations"})
       /
       sum by (team) (kube_configmap_data{configmap="cost-budgets",key="monthly_budget"})) > 1.0
    for: 5m
    annotations:
      summary: "Team {{ $labels.team }} exceeded budget"
    labels:
      severity: critical
```

### Alert Notification

Alerts are sent via:
- Slack (#cost-alerts channel)
- Email (team leads, managers)
- PagerDuty (for critical/exceed alerts)

## Budget Enforcement

### Overspend Prevention

When budget is exceeded:

1. **Warning Stage (70%)**:
   - Send notification to team
   - Generate cost optimization recommendations

2. **Critical Stage (90%)**:
   - Send notification to team + manager
   - Schedule budget review meeting
   - Identify cost reduction opportunities

3. **Exceed Stage (100%)**:
   - Send critical notification
   - Optionally auto-disable new jobs
   - Require approval for new spending

### Auto-Disable Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-policies
  namespace: spark-operations
data:
  policies.yaml: |
    auto_disable:
      enabled: true
      teams:
        # Auto-disable for these teams when budget exceeded
        - data-science
        - analytics

      # Exemptions (never auto-disable)
      exemptions:
        - data-engineering  # Critical ETL jobs

    approval_required:
      enabled: true
      threshold: 90  # Require approval at 90%

    grace_period:
      enabled: true
      duration: 4h  # Allow 4 hours grace after exceed
```

## Cost Optimization

### Right-sizing Recommendations

```bash
# Generate right-sizing recommendations
scripts/operations/cost/rightsizing-recommendations.sh --period 30d

# Output includes:
# - Over-provisioned jobs
# - Under-provisioned jobs
# - Spot instance opportunities
# - Dynamic allocation recommendations
```

### Spot Instance Recommendations

```
Spot Savings Analysis:
- Current on-demand cost: $8,500/month
- Potential spot cost: $2,550/month (70% savings)
- Recommended for spot: 80% of workload
- Risk assessment: Low (fault-tolerant workloads)
```

### Idle Resource Identification

```bash
# Identify idle resources
scripts/operations/cost/identify-idle-resources.sh --period 7d

# Output includes:
# - Idle executors
# - Unused volumes
# - Stale services
```

## Budget Planning

### Quarterly Budget Planning

Steps for quarterly budget planning:

1. **Review Historical Spending**:
   - Analyze last 3 months
   - Identify trends
   - Factor in seasonality

2. **Forecast Growth**:
   - Project new use cases
   - Data growth estimates
   - User growth estimates

3. **Calculate Budget**:
   - Base budget = current spending
   - Add growth factor (typically 10-20%)
   - Add buffer (10-20%)

4. **Allocate to Teams**:
   - Based on historical usage
   - Based on planned projects
   - Based on priority

5. **Review and Approve**:
   - Engineering manager review
   - Finance review
   - Final approval

### Budget Adjustment Process

To adjust a budget:

1. Submit budget adjustment request
2. Include justification:
   - Reason for increase/decrease
   - Impact on projects
   - Alternative funding sources
3. Get approval from:
   - Team lead
   - Engineering manager
   - Finance (for increases > 20%)
4. Update ConfigMap
5. Notify affected teams

## Reporting

### Daily Reports

- Budget status dashboard
- Alert summary
- Spending trend

### Weekly Reports

- Budget vs actual
- Forecast variance
- Team breakdown
- Top cost contributors

### Monthly Reports

- Monthly spending summary
- Budget variance analysis
- Optimization opportunities
- Next month forecast

### Quarterly Reports

- Quarterly spending summary
- Budget vs actual vs forecast
- Trend analysis
- Recommendations for next quarter

## Related Procedures

- [Cost Attribution](./cost-attribution.md)
- [Cost Optimization](./cost-optimization.md)

## References

- [Cloud Cost Management Best Practices](https://docs.aws.amazon.com/aws-cost-management/latest/userguide/best-practices.html)
- [Kubernetes Cost Optimization](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
