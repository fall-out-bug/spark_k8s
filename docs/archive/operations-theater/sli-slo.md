# SLI/SLO Definitions & Monitoring

Service Level Indicators (SLIs), Service Level Objectives (SLOs), and monitoring setup for Apache Spark on Kubernetes platform.

## 🎯 Overview

This document defines the SLIs and SLOs for the Spark K8s platform, along with monitoring setup, alerting rules, and error budget calculations.

---

## 📊 SLI Definitions

### SLI 1: Availability

**Definition:** Percentage of time the Spark platform is operational.

**Measurement:**
```promql
# Uptime percentage
(
  sum(rate(spark_platform_up{job="spark-platform"}[5m]))
  /
  sum(spark_platform_up{job="spark-platform"})
) * 100
```

**Data Source:** Prometheus /health endpoint

**Granularity:** 5 minutes

### SLI 2: Job Success Rate

**Definition:** Percentage of Spark jobs that complete successfully.

**Measurement:**
```promql
# Job success rate
(
  sum(rate(spark_job_completed_total{status="success"}[5m]))
  /
  sum(rate(spark_job_completed_total[5m]))
) * 100
```

**Data Source:** Spark metrics

**Granularity:** Per job

### SLI 3: Latency (p95)

**Definition:** 95th percentile time from job submission to job start.

**Measurement:**
```promql
# Time to first task start (p95)
histogram_quantile(0.95,
  sum(rate(spark_job_submission_to_start_seconds_bucket[5m])) by (le)
)
```

**Data Source:** Spark metrics

**Granularity:** Per job

### SLI 4: Throughput

**Definition:** Number of jobs completed per hour.

**Measurement:**
```promql
# Jobs per hour
sum(rate(spark_job_completed_total[1h])) * 3600
```

**Data Source:** Spark metrics

**Granularity:** Hourly

### SLI 5: Error Rate

**Definition:** Percentage of failed jobs due to platform errors (not user errors).

**Measurement:**
```promql
# Platform error rate
(
  sum(rate(spark_job_failed_total{error_type="platform"}[5m]))
  /
  sum(rate(spark_job_completed_total[5m]))
) * 100
```

**Data Source:** Spark metrics

**Granularity:** 5 minutes

---

## 🎯 SLO Targets

### Primary SLOs

| SLI | Target | Measurement Period | Error Budget |
|-----|--------|-------------------|--------------|
| **Availability** | 99.9% | Monthly | 43.2 minutes/month |
| **Job Success Rate** | 99% | Weekly | 1.68% weekly failures |
| **Latency (p95)** | <5s | Daily | N/A |
| **Throughput** | 100 jobs/hour | Daily | N/A |
| **Error Rate** | <1% | Weekly | 1% weekly errors |

### Error Budget Calculation

**Monthly Availability Budget (99.9%):**
```
Total minutes per month: 43,200 (30 days × 24 × 60)
Allowed downtime: 43.2 minutes (43,200 × 0.001)
```

**Weekly Job Success Budget (99%):**
```
Total jobs per week: ~10,000 (estimated)
Allowed failures: 100 jobs (10,000 × 0.01)
```

### Error Budget Burn Rate

| Burn Rate | Meaning | Action |
|-----------|---------|--------|
| **<1x** | Consuming budget slower than allocation | ✅ Normal |
| **1-2x** | Consuming budget as expected | ⚠️ Monitor closely |
| **2-10x** | Consuming budget too fast | 🚨 Stop releases, investigate |
| **>10x** | Burning budget rapidly | 🔴 Page on-call, stop all changes |

---

## 🚨 Alerting Rules

### Critical Alerts (P0)

```yaml
# Alert: High Failure Rate
- alert: HighFailureRate
  expr: |
    (
      sum(rate(spark_job_failed_total{error_type="platform"}[5m]))
      /
      sum(rate(spark_job_completed_total[5m]))
    ) > 0.05
  for: 10m
  labels:
    severity: critical
    runbook: https://docs/spark-k8s/runbooks/job-failures.md
  annotations:
    summary: "High job failure rate detected"
    description: "{{ $value | humanizePercentage }} of jobs failing (platform errors)"
    impact: "Multiple users affected"

# Alert: Platform Availability Down
- alert: PlatformDown
  expr: up{job="spark-platform"} == 0
  for: 5m
  labels:
    severity: critical
    runbook: https://docs/spark-k8s/runbooks/incident-response.md
  annotations:
    summary: "Spark platform is down"
    description: "Platform has been down for more than 5 minutes"
    impact: "All users affected"

# Alert: Driver OOM
- alert: DriverOOM
  expr: |
    sum(rate(driver_pod_oom_killed_total[5m])) > 0
  for: 5m
  labels:
    severity: critical
    runbook: https://docs/spark-k8s/troubleshooting.md#memory-issues
  annotations:
    summary: "Driver pods being OOM killed"
    description: "{{ $value }} driver pods killed due to OOM in last 5 minutes"
    impact: "Jobs failing, users affected"
```

### Warning Alerts (P1)

```yaml
# Alert: Elevated Failure Rate
- alert: ElevatedFailureRate
  expr: |
    (
      sum(rate(spark_job_failed_total{error_type="platform"}[5m]))
      /
      sum(rate(spark_job_completed_total[5m]))
    ) > 0.02
  for: 15m
  labels:
    severity: warning
    runbook: https://docs/spark-k8s/runbooks/job-failures.md
  annotations:
    summary: "Elevated job failure rate"
    description: "{{ $value | humanizePercentage }} of jobs failing (platform errors)"

# Alert: High Latency
- alert: HighLatency
  expr: |
    histogram_quantile(0.95,
      sum(rate(spark_job_submission_to_start_seconds_bucket[5m])) by (le)
    ) > 10
  for: 15m
  labels:
    severity: warning
    runbook: https://docs/spark-k8s/runbooks/performance.md
  annotations:
    summary: "High job submission latency"
    description: "p95 latency is {{ $value }}s (target: <5s)"

# Alert: Low Throughput
- alert: LowThroughput
  expr: |
    sum(rate(spark_job_completed_total[1h])) * 3600 < 50
  for: 30m
  labels:
    severity: warning
  annotations:
    summary: "Low job throughput"
    description: "{{ $value }} jobs/hour (target: 100 jobs/hour)"
```

### Info Alerts (P2)

```yaml
# Alert: Executor Loss
- alert: ExecutorLoss
  expr: |
    sum(rate(spark_executor_removed_total[5m])) > 0.1
  for: 10m
  labels:
    severity: info
    runbook: https://docs/spark-k8s/troubleshooting.md#performance-issues
  annotations:
    summary: "Executor pods being lost"
    description: "{{ $value }} executors/second being removed"

# Alert: High GC Time
- alert: HighGCTime
  expr: |
    sum(rate(spark_executor_gc_time_ms_total[5m])) /
    sum(rate(spark_executor_task_time_ms_total[5m])) > 0.2
  for: 15m
  labels:
    severity: info
    runbook: https://docs/spark-k8s/troubleshooting.md#memory-issues
  annotations:
    summary: "High GC time detected"
    description: "GC time is >20% of task time (possible memory pressure)"
```

---

## 📈 Dashboards

### Dashboard 1: Platform Overview

**Panels:**
1. **Availability Uptime** (Gauge)
   - Target: 99.9%
   - Current: [Value]

2. **Job Success Rate** (Graph)
   - Time series: Last 24 hours
   - Target: 99%

3. **Jobs Per Hour** (Graph)
   - Time series: Last 7 days
   - Target: 100 jobs/hour

4. **Active Jobs** (Stat)
   - Current count

5. **Failed Jobs (24h)** (Stat)
   - Count by error type

### Dashboard 2: Performance

**Panels:**
1. **Submission Latency (p50, p95, p99)** (Graph)
   - Time series: Last 24 hours

2. **Stage Duration** (Heatmap)
   - Distribution of stage durations

3. **Task Duration** (Histogram)
   - Distribution of task durations

4. **Executor Utilization** (Gauge)
   - CPU and memory percentage

### Dashboard 3: Infrastructure

**Panels:**
1. **Pod Status** (Pie Chart)
   - Running, Pending, Failed, OOMKilled

2. **Node Resources** (Graph)
   - CPU and memory usage over time

3. **Storage I/O** (Graph)
   - Read/write throughput

4. **Network Traffic** (Graph)
   - Inbound/outbound traffic

### Dashboard 4: Error Budget

**Panels:**
1. **Error Budget Remaining** (Gauge)
   - Monthly availability budget

2. **Budget Burn Rate** (Stat)
   - Current burn rate (x of allocation)

3. **SLO Attainment** (Graph)
   - Rolling 30-day window

---

## 🔧 Monitoring Setup

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Spark platform health
  - job_name: 'spark-platform'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - spark
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_part_of]
        regex: spark-k8s
        action: keep
      - source_labels: [__meta_kubernetes_pod_ip]
        target_label: __address__
        replacement: $1:8080

  # Spark Connect metrics
  - job_name: 'spark-connect'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - spark
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_component]
        regex: spark-connect
        action: keep
      - source_labels: [__meta_kubernetes_pod_ip]
        target_label: __address__
        replacement: $1:4040

  # Spark History Server metrics
  - job_name: 'spark-history'
    kubernetes_sd_configs:
      - role: service
        namespaces:
          names:
            - spark
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: spark-history
        action: keep
      - source_labels: [__meta_kubernetes_service_name]
        target_label: __address__
        replacement: $1:18080
```

### Grafana Dashboard Import

```bash
# Import dashboards
kubectl create configmap grafana-dashboards \
  --from-file=config/monitoring/dashboards/ \
  -n monitoring

# Restart Grafana to load dashboards
kubectl rollout restart deployment/grafana -n monitoring
```

---

## 📊 SLO Reporting

### Monthly SLO Report Template

```markdown
# SLO Report: [Month Year]

## Executive Summary

| SLO | Target | Actual | Met? | Budget Burn |
|-----|--------|--------|------|-------------|
| Availability | 99.9% | [X%] | [Yes/No] | [X] minutes |
| Job Success Rate | 99% | [X%] | [Yes/No] | [X]% |

## Availability

- **Total downtime:** [X] minutes
- **Incidents:** [X] P0, [X] P1
- **Major incidents:** [List]

## Job Success Rate

- **Total jobs:** [X]
- **Successful:** [X] ([X]%)
- **Failed:** [X] ([X]%)
- **Platform errors:** [X] ([X]%)

## Error Budget Status

- **Starting budget:** 43.2 minutes
- **Consumed:** [X] minutes ([X]%)
- **Remaining:** [X] minutes ([X]%)
- **Burn rate:** [X]x of allocation

## Actions Taken

- [ ] [Action items from incidents]
- [ ] [Improvements made]
- [ ] [Planned improvements]

## Next Month Goals

- [ ] [Goal 1]
- [ ] [Goal 2]
```

---

## 🔄 Continuous Improvement

### Quarterly SLO Review

- Review SLO targets based on user feedback
- Adjust targets if consistently missed/exceeded
- Evaluate new SLIs to add
- Remove obsolete SLIs

### Monthly Metrics Review

- Analyze trends and patterns
- Identify areas for improvement
- Create action items for platform team
- Update dashboards and alerts

---

## 📚 Related Resources

- [Incident Response Runbook](runbooks/incident-response.md) — Emergency procedures
- [Alert Configuration](alert-configuration.md) — Alert setup
- [Troubleshooting Guide](troubleshooting.md) — Common issues
- [Grafana Dashboards](../guides/en/observability/) — Dashboard configurations

---

**Last Updated:** 2026-02-04
**Part of:** [F18: Production Operations Suite](../../drafts/feature-production-operations.md)
**Next Review:** 2026-03-04
