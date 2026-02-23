# One-Click Observability Setup

Deploy Spark with full monitoring stack in a single command.

## Overview

This preset deploys:
- **Spark Connect** - Remote Spark server
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboards
- **Loki** - Log aggregation

## Quick Start

```bash
# Update dependencies
helm dependency update charts/spark-4.1

# Deploy everything
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/observability-values.yaml \
  --set observability.grafana.adminPassword=admin123 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  -n spark-operations \
  --create-namespace
```

## Access Dashboards

### Grafana
```bash
kubectl port-forward svc/spark-grafana 3000:80 -n spark-operations
# Open http://localhost:3000
# Login: admin / <adminPassword>
```

### Prometheus
```bash
kubectl port-forward svc/spark-prometheus-server 9090:80 -n spark-operations
# Open http://localhost:9090
```

### Loki (Log Queries)
```bash
# Query logs via LogCLI
logcli query '{app="spark-connect"}' --addr=http://localhost:3100
```

## Pre-Configured Dashboards

| Dashboard | Description |
|-----------|-------------|
| Spark Connect | Connect server metrics |
| Spark Executors | Executor memory/CPU |
| Spark Jobs | Job duration/failure rates |
| S3 Operations | MinIO/S3 metrics |

## Configuration

### Minimal (Development)

```yaml
observability:
  enabled: true
  prometheus:
    enabled: true
  grafana:
    enabled: true
    adminPassword: "dev123"
  loki:
    enabled: false  # Disable for dev
```

### Production

```yaml
observability:
  enabled: true
  prometheus:
    enabled: true
    prometheus:
      prometheusSpec:
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              resources:
                requests:
                  storage: 200Gi
  grafana:
    enabled: true
    adminPassword: ""  # Use ExternalSecrets
    persistence:
      enabled: true
      size: 10Gi
  loki:
    enabled: true
    loki:
      storage:
        type: s3
        s3:
          endpoint: http://minio:9000
          bucketnames: loki
```

## Spark Metrics

The following metrics are collected:

| Metric | Description |
|--------|-------------|
| `spark_executor_count` | Number of executors |
| `spark_driver_memory_used` | Driver memory usage |
| `spark_executor_memory_used` | Executor memory usage |
| `spark_job_duration` | Job execution time |
| `spark_stage_tasks` | Tasks per stage |
| `spark_sql_query_duration` | SQL query time |

## Log Aggregation

Spark logs are automatically shipped to Loki:

```logql
# Spark Connect logs
{app="spark-connect"} |= "error"

# Executor logs
{app="spark-executor"} | json | level="ERROR"

# Filter by job
{app="spark-connect"} |= "job_id=123"
```

## Alerting Rules

Pre-configured PrometheusRule:

```yaml
# Example alerts (customize as needed)
groups:
  - name: spark-alerts
    rules:
      - alert: SparkHighMemoryUsage
        expr: spark_executor_memory_used / spark_executor_memory_limit > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High executor memory usage"
```

## Troubleshooting

### Grafana Can't Connect to Prometheus

```bash
# Check Prometheus service
kubectl get svc -l app.kubernetes.io/name=prometheus -n spark-operations

# Verify datasource
kubectl exec -it deployment/spark-grafana -n spark-operations -- \
  curl http://spark-prometheus-server/api/v1/query?query=up
```

### No Metrics Appearing

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n spark-operations

# Verify Prometheus is scraping
kubectl port-forward svc/spark-prometheus-server 9090:80
# Check /targets page
```

### Logs Not Appearing in Loki

```bash
# Check Loki is receiving data
kubectl logs -l app.kubernetes.io/name=loki -n spark-operations

# Verify Promtail (if using)
kubectl logs -l app.kubernetes.io/name=promtail -n spark-operations
```

## Resources

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Prometheus | 500m-2 | 2-4Gi | 50-200Gi |
| Grafana | 100-500m | 256-512Mi | 1-10Gi |
| Loki | 100-500m | 512Mi-1Gi | 10-50Gi |

## Uninstall

```bash
helm uninstall spark -n spark-operations
kubectl delete pvc -l release=spark -n spark-operations
```
