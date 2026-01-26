# Prometheus Monitoring Integration

**Source:** Integration recipes

## Overview

Настроить сбор Spark metrics через Prometheus для мониторинга production workload.

## Architecture

```
Spark Driver / Executors
    ↓
Spark Metrics Servlet (port 4040)
    ↓
Prometheus Scrape Config
    ↓
Prometheus Server
    ↓
Grafana Dashboards
```

## Deployment

### Шаг 1: Включить metrics в Spark

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.metrics.conf=\\*.sink.prometheus.class=org.apache.spark.metrics.sink.PrometheusSink \
  --set connect.sparkConf.spark\\.metrics.conf=\\*.sink.prometheus.period=10 \
  --set connect.podAnnotations.'prometheus\\.io/scrape'="true" \
  --set connect.podAnnotations.'prometheus\\.io/port'="4040" \
  --set connect.podAnnotations.'prometheus\\.io/path'="/metrics/executors" \
  --reuse-values
```

### Шаг 2: Добавить ServiceMonitor (если установлен Prometheus Operator)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spark-connect
  namespace: spark
spec:
  selector:
    matchLabels:
      app: spark-connect
  endpoints:
  - port: spark-metrics
    path: /metrics/executors
    interval: 15s
EOF
```

### Шаг 3: Добавить ConfigMapMap для Prometheus

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-spark
  namespace: prometheus
data:
  spark-scrape.yml: |
    - job_name: 'spark-connect'
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        - source_labels: [__meta_kubernetes_pod_label_app]
          regex: spark-connect
          action: keep
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
      metrics_path: /metrics/executors
      scrape_interval: 15s
EOF
```

## Metrics Available

### Core Metrics

```
spark.executor.metrics
  - memory.used
  - memory.remaining
  - disk.used
  - disk.remaining
  - threadpool.activeTasks
  - threadpool.runningTasks

spark.driver.BlockManager
  - memory.memUsed_MB
  - memory.remainingMem_MB

spark.status
  - executor.instances
```

### Application Metrics

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit
import mlflow

spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()

# User-defined metrics
spark.sparkContext.setJobGroup("my-job", "My Spark Job")

# MLflow metrics
mlflow.log_metric("custom_metric", 123)

# Spark accumulators
from pyspark.accumulators import AccumulatorParam
class CustomAccumulator(AccumulatorParam):
    def zero(self): return 0
    def addInPlace(self, val1, val2): self.value += val1 + val2
```

## Grafana Dashboards

### Dashboard Configuration

```json
{
  "dashboard": {
    "title": "Spark Metrics",
    "panels": [
      {
        "title": "Executor Memory",
        "targets": [
          {
            "expr": "spark_executor_memory_bytes_used",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Active Tasks",
        "targets": [
          {
            "expr": "spark_threadpool_activeTasks",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Job Duration",
        "targets": [
          {
            "expr": "spark_job_duration_seconds",
            "legendFormat": "{{job}}"
          }
        ]
      }
    ]
  }
}
```

### Import Dashboard

```bash
# Добавить Prometheus datasource
kubectl port-forward -n prometheus svc/prometheus 9090:9090
# Откройте Grafana: http://localhost:3000
# Configuration -> Data Sources -> Prometheus
# URL: http://prometheus:9090
```

## Alerting Rules

```yaml
# prometheus-alerts.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
data:
  alerts.yml: |
    groups:
      - name: spark
        rules:
          - alert: SparkExecutorOOM
            expr: rate(spark_executor_memory_bytes_reclaimed[5m]) > 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Spark executor OOM detected"

          - alert: SparkJobStalled
            expr: spark_job_duration_seconds > 3600
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Spark job running longer than 1 hour"

          - alert: SparkExecutorsDown
            expr: count(spark_status_executor_instances) < 3
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Less than 3 executors running"
```

## Production Configuration

```yaml
connect:
  sparkConf:
    # Metrics configuration
    spark.metrics.conf: "*.sink.prometheus.class=org.apache.spark.metrics.sink.PrometheusSink"
    spark.metrics.conf: "*.sink.prometheus.period=10"
    spark.metrics.conf: "*.sink.prometheus.unit=seconds"
    spark.metrics.dynamicAllocation.enabled=true
    spark.metrics.executor.metrics.polling.enabled=true

  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "4040"
    prometheus.io/path: "/metrics/executors"

  resources:
    requests:
      memory: "2Gi"
    limits:
      memory: "4Gi"
```

## Verification

```bash
# 1. Проверить metrics endpoint
kubectl port-forward -n spark <spark-connect-pod> 4040:4040
curl http://localhost:4040/metrics/executors | jq .

# 2. Проверить Prometheus targets
kubectl port-forward -n prometheus svc/prometheus 9090:9090
# http://localhost:9090/targets

# 3. Проверить метрики в Prometheus
curl -s http://localhost:9090/api/v1/label/__name__/values | jq .

# 4. Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=spark_executor_memory_bytes_used' | jq .
```

## Performance Tuning

```yaml
connect:
  sparkConf:
    # Reduce metrics overhead
    spark.metrics.conf: "*.sink.prometheus.period=30"
    spark.metrics.json.enabled=false
    spark.metrics.csv.enabled=false

    # Collect only essential metrics
    spark.metrics.app.enabled=true
    spark.metrics.executor.enabled=true
    spark.metrics.driver.enabled=true
```

## Troubleshooting

```bash
# Если metrics не scraping
# Проверьте pod annotations
kubectl get pod -n spark <pod> -o yaml | grep prometheus

# Проверьте ServiceMonitor
kubectl get servicemonitor -n spark

# Проверьте Prometheus logs
kubectl logs -n prometheus deploy/prometheus --tail=100

# Если metrics port недоступен
kubectl port-forward -n spark <pod> 4040:4040
curl http://localhost:4040/metrics/executors

# Проверьте что metrics servlet включен
kubectl exec -n spark <pod> -- \
  cat /opt/spark/conf/metrics.properties
```

## Monitoring Dashboard Examples

### Cluster Overview

```
- Total Executors: 10
- Active Jobs: 3
- Memory Usage: 40GB / 80GB
- CPU Usage: 15 cores / 20 cores
- Throughput: 1M rows/sec
```

### Per-Job Metrics

```
- Job Duration: 5m 23s
- Input Rows: 1,000,000
- Output Rows: 500,000
- Shuffle Read: 10GB
- Shuffle Write: 5GB
```

### Per-Executor Metrics

```
- executor-1: 8GB memory, 2 cores, active tasks: 4
- executor-2: 8GB memory, 2 cores, active tasks: 4
- executor-3: 8GB memory, 2 cores, active tasks: 0 (idle)
```

## References

- Spark Metrics: https://spark.apache.org/docs/latest/monitoring.html
- Prometheus: https://prometheus.io/docs/practices/naming/
- Grafana: https://grafana.com/docs/grafana/latest/
- Prometheus Operator: https://prometheus-operator.dev/
