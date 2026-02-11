# Spark Observability Stack Guide

This guide explains how to observe and debug Spark applications using the integrated observability stack.

## Components

### 1. OpenTelemetry Tracing
- **What**: Distributed tracing from Airflow → Spark Connect → Spark Driver → Executors
- **Why**: See request flow across service boundaries
- **How**: Check Jaeger/OTel collector UI with `trace_id` from Airflow DAG

### 2. Resource Wait Tracking
- **What**: Time between `app_start` and first executor registration
- **Metric**: `spark_resource_wait_seconds`
- **Dashboard**: Job Phase Timeline → "Resource Wait" panel shows bottleneck
- **Action**: If >300s, check K8s scheduling, PriorityClass, resource quotas

### 3. Spark Metrics (Prometheus)
- **What**: Executor-level metrics exposed by Spark Connect
- **Key Metrics**:
  - `sum(rate(spark_executor_memory_task_bytes))` - Memory allocation rate
  - `sum(rate(spark_executor_shuffle_write_bytes))` - Shuffle write throughput
  - `sum(rate(spark_stage_duration_milliseconds))` - Stage compute time
- **Dashboard**: Access via `/metrics` endpoint in Spark Connect UI

### 4. S3A Metrics
- **What**: Hadoop S3A filesystem metrics
- **Key Metrics**:
  - `s3a_write_total` - Total multipart uploads
  - `s3a_write_duration` - Upload latency
  - `s3a_aborted_uploads` - Failed uploads
- **Dashboard**: Custom Prometheus dashboard required (see below)

## Troubleshooting Workflows

### Slow Job? (→ AC8)
1. Check **Job Phase Timeline** dashboard
   - Is "Resource Wait" phase >80% of job time?
   - Are there large gaps between `app_start` and `first_exec`?
2. Check **Task Duration Heatmap**
   - Which stages take longest? (sort, aggregate, shuffle)
3. Action: Profile long stage with Spark UI

### OOM/Spill? (→ AC10)
1. Check **Spark Profiling** dashboard
   - Is "Memory Used" near 100%?
   - Is "GC Time %" >20%?
   - Any "Spill to Disk" bytes?
2. Action: Increase executor memory, reduce partitions

### Shuffle Slow? (→ AC11)
1. Check **Spark Profiling** dashboard
   - Is "Shuffle Skew" >2.0? (max/avg ratio)
   - Are "Read/Write Ratio" panels unbalanced?
2. Action: Enable Celeborn, optimize partitioning, increase `spark.sql.shuffle.partitions`

## Quick Setup

```bash
# Enable OTel tracing
kubectl patch configmap spark-3.5-connect-config -n spark-infra --type=json \
  -p '
  {
    "data": {
      "spark-properties.conf": "spark.otel.exporter.protocol=otlp\nspark.otel.exporter.endpoint=http://otel-collector:4317\nspark.otel.resource.attributes=service.name=spark-connect-35\nspark.otel.sampling.ratio=1.0"
    }
  }
  '

# Check metrics in Spark Connect UI
curl -s http://localhost:15002/metrics/prometheus | jq '.[] | .name'
```

## Dashboards

| Dashboard | Purpose | Access |
|-----------|---------|--------|
| Job Phase Timeline | Resource wait vs compute phases | Grafana → Search "Job Phase" |
| Spark Profiling | Memory, GC, shuffle, executor utilization | Grafana → Search "Spark Profiling" |

## Advanced

### Custom SparkListener
See `docker/spark-3.5/listeners/resource-wait-tracker.py` for tracking custom metrics.

### Event Log Analysis
```bash
# Parse event logs from S3
aws s3api s3api-get-object --bucket spark-logs --key local-1770818928279 | zless
```
