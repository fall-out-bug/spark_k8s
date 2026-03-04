# Alert Configuration

> **Audience:** Operators
> **Related:** [Monitoring](./monitoring.md)

## Overview

Prometheus rules and AlertManager examples for Spark on Kubernetes.

## Prometheus Rules

### Job Failure

```yaml
groups:
- name: spark-alerts
  rules:
  - alert: SparkJobFailed
    expr: spark_application_status{status="failed"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Spark job {{ $labels.app_id }} failed"
```

### Driver Crash

```yaml
  - alert: SparkDriverCrashLoop
    expr: rate(kube_pod_container_status_restarts_total{pod=~"spark-driver-.*"}[15m]) > 0
    for: 5m
    labels:
      severity: critical
```

### Executor OOM

```yaml
  - alert: SparkExecutorOOM
    expr: kube_pod_container_status_last_terminated_reason{pod=~"spark-executor-.*"} == "OOMKilled"
    labels:
      severity: warning
```

### High Memory

```yaml
  - alert: SparkHighMemoryUsage
    expr: |
      spark_executor_metrics_memoryUsed / spark_executor_metrics_maxMemUsed > 0.9
    for: 10m
    labels:
      severity: warning
```

## AlertManager Routing

```yaml
route:
  receiver: spark-ops
  group_by: [app_id, namespace]
  routes:
  - match:
      severity: critical
    receiver: pagerduty
  - match:
      severity: warning
    receiver: slack
```

## Runbook Links

Add to annotations:

```yaml
annotations:
  runbook_url: "https://docs.example.com/runbooks/spark/oom-kill-mitigation"
```
