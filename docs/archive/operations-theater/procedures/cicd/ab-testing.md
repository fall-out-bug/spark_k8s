# A/B Testing Framework

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Blue-Green Deployment](./blue-green-deployment.md), [Job CI/CD Pipeline](./job-cicd-pipeline.md)

## Overview

A/B testing allows testing new Spark job versions alongside the current version, with a percentage of traffic going to each. This enables data-driven decisions about rolling out changes.

## Use Cases

**When to use A/B testing:**
- Testing new Spark versions
- Validating performance optimizations
- Comparing query logic changes
- Testing configuration changes
- Evaluating UDF modifications

**When NOT to use:**
- Breaking changes (use blue-green)
- Schema changes (deploy to all)
- Emergency fixes (deploy immediately)

## Architecture

```
                        Load Balancer
                             |
              +------------+------------+
              | 90% traffic | 10% traffic |
              v            v
          Control       Treatment
          (version A)  (version B)
              |            |
          Spark Jobs    Spark Jobs
```

## Implementation

### 1. Deploy Treatment Version

```bash
# Deploy new version with canary annotation
helm install spark-treatment ./charts/spark-4.1 \
  --namespace spark-production \
  --values values/spark-job-v2.yaml \
  --set canary.enabled=true \
  --set canary.trafficPercent=10
```

### 2. Configure Traffic Split

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spark-jobs
spec:
  selector:
    app: spark-jobs
  ports:
    - port: 4040
---
# Control version (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-control
spec:
  replicas: 9
  selector:
    matchLabels:
      app: spark-jobs
      version: v1
---
# Treatment version (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-treatment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-jobs
      version: v2
```

### 3. Run A/B Test

```bash
scripts/cicd/ab-test-spark-job.sh \
  --control spark-control \
  --treatment spark-treatment \
  --metric "job_duration_seconds" \
  --canary-percent 10
```

## Metrics for Comparison

### Performance Metrics

| Metric | Control | Treatment | Significance |
|--------|---------|-----------|--------------|
| Job Duration | 360s | 340s | Faster |
| Executor Time | 1200s | 1150s | Faster |
| Shuffle Time | 180s | 175s | Faster |
| Memory Used | 48GB | 52GB | Higher |

### Quality Metrics

| Metric | Control | Treatment | Comparison |
|--------|---------|-----------|------------|
| Row Count | 1M | 1M | Equal |
| NULL Count | 0 | 0 | Equal |
| Data checksum | ABC123 | ABC123 | Equal |

### Statistical Significance

**Sample size calculation:**
```python
from scipy import stats
import numpy as np

# For detecting 10% improvement with 80% power, 5% significance
effect_size = 0.10  # 10% improvement
alpha = 0.05  # 5% significance
power = 0.80  # 80% power

# Required sample size per group
n_per_group = stats.norm.ppf(0.975) + stats.norm.ppf(0.80)
n_required = int((n_per_group / effect_size) ** 2)
# Result: ~1000 samples per group
```

## Test Duration

### Minimum Test Duration

| Metric Type | Minimum Duration | Reason |
|-------------|------------------|--------|
| **Latency** | 1000 requests | Statistical significance |
| **Throughput** | 24 hours | Daily cycle coverage |
| **Quality** | 1 full job run | End-to-end validation |
| **Cost** | 1 week | Account for variance |

### Increasing Canary Traffic

```bash
# Day 1: 10% traffic (canary)
./scripts/cicd/ab-test-spark-job.sh --canary-percent 10

# Day 2-3: Monitor metrics, no regression → increase to 25%
./scripts/cicd/ab-test-spark-job.sh --canary-percent 25

# Day 4-5: Continue monitoring → increase to 50%
./scripts/cicd/ab-test-spark-job.sh --canary-percent 50

# Day 6-7: Final validation → increase to 100%
./scripts/cicd/ab-test-spark-job.sh --canary-percent 100
```

## Decision Framework

### Go/No-Go Criteria

**Go (full rollout):**
- Treatment outperforms control by >5%
- Statistical significance p < 0.05
- No quality regressions
- No error rate increase
- Cost increase < 10%

**No-Go (rollback):**
- Control outperforms treatment
- Error rate increase > 10%
- Quality issues detected
- Statistical significance not achieved

**Continue testing:**
- Results inconclusive
- Variance too high
- Test duration too short

### Automated Decision

```bash
#!/bin/bash
# Automated A/B test decision

CONTROL_METRIC=$(get_metric "control" "job_duration_mean")
TREATMENT_METRIC=$(get_metric "treatment" "job_duration_mean")
CONTROL_STDDEV=$(get_metric "control" "job_duration_stddev")

# Calculate t-statistic
N=1000  # sample size
T_STAT=$(echo "scale=4; ($TREATMENT_METRIC - $CONTROL_METRIC) / ($CONTROL_STDDEV / sqrt($N))" | bc)

# Get p-value (two-tailed)
P_VALUE=$(echo "import scipy.stats as stats; print(2 * (1 - stats.norm.cdf(abs($T_STAT))))" | python)

echo "Control: ${CONTROL_METRIC}s"
echo "Treatment: ${TREATMENT_METRIC}s"
echo "T-statistic: ${T_STAT}"
echo "P-value: ${P_VALUE}"

# Decision
if (( $(echo "$P_VALUE < 0.05" | bc -l) )); then
    if (( $(echo "$TREATMENT_METRIC < $CONTROL_METRIC" | bc -l) )); then
        echo "✓ Treatment significantly better. Recommend rollout."
        exit 0
    else
        echo "✗ Treatment significantly worse. Recommend rollback."
        exit 1
    fi
else
    echo "? Results not significant. Continue testing."
    exit 2
fi
```

## Monitoring During Test

### Real-time Metrics Dashboard

```yaml
# Grafana dashboard for A/B test
{
  "title": "A/B Test Metrics",
  "panels": [
    {
      "title": "Job Duration by Version",
      "type": "graph",
      "targets": [
        {
          "expr": "avg(job_duration_seconds{version=\"control\"})",
          "legendFormat": "Control"
        },
        {
          "expr": "avg(job_duration_seconds{version=\"treatment\"})",
          "legendFormat": "Treatment"
        }
      ]
    },
    {
      "title": "Error Rate by Version",
      "type": "graph",
      "targets": [
        {
          "expr": "rate(job_errors_total{version=\"control\"}[5m])",
          "legendFormat": "Control"
        },
        {
          "expr": "rate(job_errors_total{version=\"treatment\"}[5m])",
          "legendFormat": "Treatment"
        }
      ]
    }
  ]
}
```

## Rollback Procedure

### Immediate Rollback

```bash
# 1. Scale down treatment
kubectl scale deployment spark-treatment --replicas=0

# 2. Scale up control to full capacity
kubectl scale deployment spark-control --replicas=10

# 3. Verify control handling all traffic
kubectl get pods -l app=spark-jobs,version=v1
```

### Gradual Rollback

```bash
# Reduce canary traffic gradually
./scripts/cicd/ab-test-spark-job.sh --canary-percent 5
./scripts/cicd/ab-test-spark-job.sh --canary-percent 0

# Remove treatment
helm uninstall spark-treatment
```

## Best Practices

1. **Start small:** Begin with 5-10% canary traffic
2. **Monitor closely:** Watch metrics in real-time during test
3. **Set clear criteria:** Define success/failure before starting
4. **Document results:** Record test results for future reference
5. **Communicate:** Inform stakeholders about test progress

## References

- [Blue-Green Deployment](./blue-green-deployment.md)
- [Job CI/CD Pipeline](./job-cicd-pipeline.md)
- [Smoke Tests](../../tests/README.md)
