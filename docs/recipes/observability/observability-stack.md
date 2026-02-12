# Observability Stack Guide

## Overview

Этот guide описывает observability stack для Spark K8s Constructor deployment в production.

## Components

### Prometheus

**ServiceMonitor** — для Prometheus Operator scraping:

```yaml
# Enable in values.yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: "15s"
    scrapeTimeout: "10s"
    labels:
      release: prometheus
```

**PodMonitor** — для dynamic Spark executor scraping:

```yaml
monitoring:
  podMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
```

### Grafana Dashboards

**Pre-built dashboards:**

1. **Spark Overview** — Cluster health overview
   - Running Executors
   - Cluster CPU Usage
   - Memory Usage
   - Jobs Completed Rate

2. **Executor Metrics** — Detailed executor metrics
   - Memory Usage per Executor
   - Cores per Executor
   - Active Tasks per Executor
   - Disk Usage per Executor

3. **Job Performance** — Job performance analytics
   - Job Duration Percentiles (p50, p95)
   - Failed Tasks Rate
   - Shuffle Throughput
   - Task Duration

4. **Job Phase Timeline** — Resource wait / compute / I/O breakdown
   - Gantt timeline showing resource wait, compute, and I/O phases
   - Phase breakdown ratios (wait:compute:io)
   - Time to first executor metric
   - S3 write throughput tracking

5. **Spark Profiling** — Performance bottleneck analysis
   - GC time percentage
   - Serialization time
   - Shuffle skew detection
   - Spill to disk metrics
   - Executor utilization
   - Task duration heatmap

**Enable dashboards:**

```yaml
monitoring:
  grafanaDashboards:
    enabled: true
    namespace: monitoring  # Where Grafana is installed
```

Dashboards автоматически создаются как ConfigMaps с label `grafana_dashboard: "1"`.

### Structured JSON Logging

**Log4j2 Configuration:**

```bash
# JSON logging enabled in docker/spark-4.1/conf/log4j2.properties
# Two appenders available:
# 1. console - text format (development)
# 2. json_console - JSON format (production)
```

**JSON log format:**

```json
{
  "time": "2026-01-28T12:34:56.789Z",
  "level": "INFO",
  "logger": "org.apache.spark.sql.connect",
  "message": "Spark Connect server started",
  "service": "spark-connect",
  "environment": "prod"
}
```

**Enable JSON logging:**

```bash
# Set environment variable
export SPARK_ENV=prod

# Or in values.yaml
connect:
  sparkConf:
    spark.driver.extraJavaOptions: "-Dlog4j.configurationFile=file:///opt/spark/conf/log4j2.properties"
```

### OpenTelemetry Integration

**Tracing с Tempo:**

```yaml
monitoring:
  openTelemetry:
    enabled: true
    endpoint: "http://opentelemetry-collector:4317"
    protocol: "grpc"
```

**Spark OpenTelemetry listener:**

```bash
# Add to spark-defaults.conf
spark.extraListeners=org.apache.spark.sql.SparkSessionExtension
spark.sql.queryExecutionListeners=org.apache.spark.sql.telemetry.TelemetryListener
```

## Metrics Reference

### Spark Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `spark_executor_count` | Gauge | Number of running executors |
| `spark_executor_memory_bytes` | Gauge | Memory usage per executor |
| `spark_executor_cores` | Gauge | Cores allocated per executor |
| `spark_task_duration_seconds` | Histogram | Task duration distribution |
| `spark_job_duration_seconds` | Histogram | Job duration distribution |
| `spark_task_failed_total` | Counter | Total failed tasks |
| `spark_shuffle_read_bytes_total` | Counter | Total shuffle bytes read |
| `spark_shuffle_write_bytes_total` | Counter | Total shuffle bytes written |

## Grafana Setup

### 1. Install Grafana Operator

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana -n monitoring --create-namespace
```

### 2. Configure Dashboard Auto-discovery

```bash
# Enable sidecar for dashboards
helm upgrade grafana grafana/grafana -n monitoring \
  --set sidecar.dashboards.enabled=true \
  --set sidecar.dashboards.label=grafana_dashboard \
  --set sidecar.dashboards.searchNamespace=*
```

### 3. Access Dashboards

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open http://localhost:3000
# Default credentials: admin / admin
```

## Prometheus Setup

### 1. Install Prometheus Operator

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 2. Verify ServiceMonitors

```bash
# Check ServiceMonitors are created
kubectl get servicemonitors -n spark

# Check targets in Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets
```

## Tempo Setup

### 1. Install Tempo

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install tempo grafana/tempo -n monitoring --create-namespace
```

### 2. Configure OpenTelemetry Collector

```yaml
# otel-collector-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: monitoring
data:
  otel-collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    processors:
      batch:
    exporters:
      otlp:
        endpoint: tempo:4317
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlp]
```

## Log Aggregation

### Option 1: Loki (optional, Phase 3)

```bash
helm install loki grafana/loki-stack -n monitoring --create-namespace
```

### Option 2: Elasticsearch + Kibana

```bash
# Install Elasticsearch
helm install elasticsearch elastic/elasticsearch -n monitoring --create-namespace

# Install Filebeat on Spark nodes
helm install filebeat elastic/filebeat -n spark
```

## Monitoring Best Practices

### 1. Alerting Rules

```yaml
# Example Prometheus alert rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: spark-alerts
  namespace: spark
spec:
  groups:
    - name: spark.rules
      rules:
        - alert: SparkHighFailedTasksRate
          expr: rate(spark_task_failed_total[5m]) > 10
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High task failure rate in Spark"
            description: "{{ $labels.app }} has {{ $value }} failed tasks/sec"
```

### 2. Recording Rules

```yaml
# Pre-compute expensive queries
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: spark-recording
  namespace: spark
spec:
  groups:
    - name: spark.recording
      interval: 30s
      rules:
        - record: spark:job_duration_p95
          expr: histogram_quantile(0.95, sum(rate(spark_job_duration_seconds_bucket[5m])) by (le))
```

### 3. Dashboards Annotations

```json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  }
}
```

## Troubleshooting

### ServiceMonitor not picking up targets

```bash
# Check ServiceMonitor exists
kubectl get servicemonitors -n spark

# Check selector matches
kubectl describe servicemonitor spark-connect

# Check Prometheus configuration
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Browse to http://localhost:9090/config
```

### Grafana dashboards not appearing

```bash
# Check ConfigMaps created
kubectl get configmaps -n spark -l grafana_dashboard=1

# Check Grafana sidecar logs
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboards

# Manually reload dashboards
kubectl rollout restart deployment/grafana -n monitoring
```

### JSON logs not parsed

```bash
# Verify log4j2.properties is mounted
kubectl exec -n spark spark-connect-0 -- cat /opt/spark/conf/log4j2.properties

# Check logs format
kubectl logs -n spark spark-connect-0 | jq .

# Verify SPARK_ENV is set
kubectl exec -n spark spark-connect-0 -- env | grep SPARK_ENV
```

## References

- Prometheus Operator: https://prometheus-operator.dev/
- Grafana: https://grafana.com/docs/grafana/latest/
- Tempo: https://grafana.com/docs/tempo/latest/
- OpenTelemetry: https://opentelemetry.io/docs/instrumentation/java/
- Spark Monitoring: https://spark.apache.org/docs/latest/monitoring.html

---

**Observability Status:** Stack created. Follow this guide for production deployment.
