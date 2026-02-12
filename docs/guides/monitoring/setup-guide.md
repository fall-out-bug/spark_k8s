# Monitoring Setup Guide

This guide explains how to set up comprehensive monitoring for Spark on Kubernetes.

## Overview

The monitoring stack includes:
- **Prometheus**: Metrics collection
- **Grafana**: Visualization
- **Alertmanager**: Alert routing
- **Pushgateway**: Push-based metrics

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Spark     │────▶│ Prometheus  │────▶│  Grafana    │
│  Executors  │     │  (TSDB)     │     │ (Dashboard) │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌─────────────┐
│ Pushgateway │     │Alertmanager │
│  (metrics)  │     │  (alerts)   │
└─────────────┘     └─────────────┘
```

## Step 1: Install Prometheus Operator

```bash
# Add the repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --values - <<EOF
prometheus:
  prometheusSpec:
    retention: 30d
    retentionSize: 50GB
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: fast-ssd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi
    resources:
      requests:
        memory: "4Gi"
        cpu: "2"

grafana:
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"

alertmanager:
  alertmanagerSpec:
    retention: 120h
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: fast-ssd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
EOF
```

## Step 2: Configure Spark Metrics

### 2.1 Enable Prometheus Metrics

```yaml
# SparkApplication with metrics
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-with-metrics
spec:
  sparkVersion: "3.5.0"

  # Enable metrics
  sparkConf:
    # Enable Prometheus metrics
    spark.ui.prometheus.enabled: "true"
    spark.metrics.conf: |
      *.sink.prometheus.class=org.apache.spark.metrics.sink.PrometheusSink
      *.sink.prometheus.period=5s
      spark.executor.metrics.prometheus.enabled=true
      spark.driver.metrics.prometheus.enabled=true
      spark.executor.metrics.prometheus.port=4040
      spark.driver.metrics.prometheus.port=4040

  driver:
    cores: 2
    memory: "4g"
    # Expose metrics endpoint
    podLabels:
      prometheus.io/scrape: "true"
      prometheus.io/port: "4040"
      prometheus.io/path: "/metrics/prometheus/"

  executor:
    cores: 4
    instances: 10
    memory: "8g"
    podLabels:
      prometheus.io/scrape: "true"
      prometheus.io/port: "4040"
      prometheus.io/path: "/metrics/prometheus/"
```

### 2.2 Custom Metrics Configuration

```python
# Create custom metrics config
metrics_config = """
{
  "sink": {
    "prometheus": {
      "class": "org.apache.spark.metrics.sink.PrometheusSink",
      "period": "5",
      "host": "0.0.0.0",
      "port": "4040"
    }
  },
  "source": {
    "jvm": {
      "class": "org.apache.spark.metrics.source.JvmSource"
    }
  }
}
"""

# Save to ConfigMap
kubectl create configmap spark-metrics-config \
  --from-file=metrics.properties=<(echo "$metrics_config") \
  --namespace spark-prod
```

## Step 3: Create ServiceMonitors

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spark-executors
  namespace: observability
spec:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
  namespaceSelector:
    matchNames:
      - spark-prod
      - spark-staging
  endpoints:
    - port: prometheus
      path: /metrics/prometheus/
      interval: 15s
```

## Step 4: Import Grafana Dashboards

```bash
# Create ConfigMap for dashboards
kubectl create configmap grafana-spark-dashboards \
  --namespace=observability \
  --from-file=charts/observability/grafana/dashboards/

# Add to Grafana configuration
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=observability
```

## Step 5: Configure Alerts

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: spark-alerts
  namespace: observability
  labels:
    release: prometheus
spec:
  groups:
    - name: spark_jobs
      interval: 30s
      rules:
        # Job failure
        - alert: SparkJobFailed
          expr: |
            spark_job_status{app_id!="", namespace=~"spark-.*"} == 2
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Spark job {{ $labels.app_id }} failed"
            description: "Job in namespace {{ $labels.namespace }} has failed"

        # High task failure rate
        - alert: SparkHighTaskFailureRate
          expr: |
            rate(spark_task_failed_total[5m]) / rate(spark_task_completed_total[5m]) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High task failure rate for {{ $labels.app_id }}"
            description: "{{ $value | humanizePercentage }} of tasks are failing"

        # Executor loss
        - alert: SparkExecutorLost
          expr: |
            increase(spark_executor_removed_total[5m]) > 0
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Executor lost for {{ $labels.app_id }}"
            description: "An executor was removed from the application"

        # Memory pressure
        - alert: SparkMemoryPressure
          expr: |
            spark_executor_memory_used_bytes / spark_executor_memory_max_bytes > 0.9
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Memory pressure on {{ $labels.app_id }}"
            description: "Executor is using {{ $value | humanizePercentage }} of memory"

        # Data skew
        - alert: SparkDataSkew
          expr: |
            spark_task_duration_max / spark_task_duration_min > 10
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Data skew detected in {{ $labels.app_id }}"
            description: "Max/Min task duration ratio is {{ $value }}x"
```

## Step 6: Alert Routing

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: observability
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

    route:
      group_by: ['alertname', 'namespace']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'

      routes:
        - match:
            severity: critical
          receiver: 'critical-alerts'

        - match:
            severity: warning
          receiver: 'warning-alerts'

    receivers:
      - name: 'default'
        slack_configs:
          - channel: '#spark-alerts'

      - name: 'critical-alerts'
        slack_configs:
          - channel: '#spark-critical'
        pagerduty_configs:
          - service_key: 'YOUR_PAGERDUTY_KEY'

      - name: 'warning-alerts'
        slack_configs:
          - channel: '#spark-warnings'
```

## Metrics Reference

| Metric | Description | Labels |
|--------|-------------|--------|
| `spark_job_status` | Job status (0=running, 1=succeeded, 2=failed) | app_id, namespace |
| `spark_executor_count` | Number of executors | app_id |
| `spark_task_duration_max` | Max task duration | app_id, stage_id |
| `spark_task_duration_avg` | Average task duration | app_id, stage_id |
| `spark_memory_used` | Memory used | app_id, executor_id |
| `spark_gc_time` | GC time spent | app_id, executor_id |
| `spark_shuffle_read` | Shuffle bytes read | app_id |
| `spark_shuffle_write` | Shuffle bytes written | app_id |

## Dashboard Templates

Key dashboards to create:

1. **Job Overview**: All jobs, status, duration
2. **Resource Usage**: CPU, memory, network per job
3. **Performance**: Task duration, throughput, latency
4. **Shuffle**: Read/write bytes, spill
5. **GC**: Time spent in GC per executor

## Verification

```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check metrics are being collected
curl http://prometheus.observability.svc.cluster.local:9090/api/v1/query?query=spark_job_status

# Access Grafana
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
# Visit http://localhost:3000
```

## Next Steps

- [ ] Create custom dashboards for your use cases
- [ ] Set up SLO-based alerts
- [ ] Configure metrics retention
- [ ] Set up alert notification channels

## Related

- [Grafana Dashboards](../../charts/observability/grafana/dashboards/)
- [Alert Rules](../../charts/observability/prometheus/rules/)
