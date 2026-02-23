# Spark Metrics Reference

Complete reference of available Spark metrics for monitoring.

## Metric Categories

Spark metrics are organized into:

1. **Application Metrics**: Job-level metrics
2. **Executor Metrics**: Per-executor metrics
3. **Task Metrics**: Per-task metrics
4. **Driver Metrics**: Driver-specific metrics
5. **JVM Metrics**: JVM-level metrics

## Application Metrics

### Job Status

| Metric | Type | Description |
|--------|------|-------------|
| `spark_job_status` | gauge | Job status (0=running, 1=succeeded, 2=failed) |
| `spark_job_duration` | gauge | Job duration in seconds |

### Stage Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `spark_stage_duration` | gauge | Stage duration |
| `spark_stage_tasks` | gauge | Number of tasks in stage |
| `spark_stage_completed_tasks` | gauge | Completed tasks |

## Executor Metrics

### Count

| Metric | Type | Description |
|--------|------|-------------|
| `spark_executor_count` | gauge | Current number of executors |
| `spark_executor_removed_total` | counter | Total executors removed |
| `spark_executor_added_total` | counter | Total executors added |

### Memory

| Metric | Type | Description |
|--------|------|-------------|
| `spark_executor_memory_used_bytes` | gauge | Memory used in bytes |
| `spark_executor_memory_max_bytes` | gauge | Max memory available |
| `spark_executor_storage_memory_used_bytes` | gauge | Storage memory used |
| `spark_executor_storage_memory_max_bytes` | gauge | Max storage memory |

### CPU

| Metric | Type | Description |
|--------|------|-------------|
| `spark_executor_cpu_time_seconds_total` | counter | Total CPU time |
| `spark_executor_cores` | gauge | Number of cores per executor |

## Task Metrics

### Duration

| Metric | Type | Description |
|--------|------|-------------|
| `spark_task_duration_max` | gauge | Max task duration |
| `spark_task_duration_min` | gauge | Min task duration |
| `spark_task_duration_avg` | gauge | Average task duration |

### Counters

| Metric | Type | Description |
|--------|------|-------------|
| `spark_task_completed_total` | counter | Completed tasks |
| `spark_task_failed_total` | counter | Failed tasks |
| `spark_task_killed_total` | counter | Killed tasks |

### Data Processing

| Metric | Type | Description |
|--------|------|-------------|
| `spark_task_input_bytes` | counter | Input bytes read |
| `spark_task_output_bytes` | counter | Output bytes written |
| `spark_task_shuffle_read_bytes` | counter | Shuffle bytes read |
| `spark_task_shuffle_write_bytes` | counter | Shuffle bytes written |
| `spark_task_disk_bytes_spilled` | counter | Bytes spilled to disk |

## Shuffle Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `spark_shuffle_read_bytes` | counter | Total shuffle read |
| `spark_shuffle_write_bytes` | counter | Total shuffle write |
| `spark_shuffle_records_read` | counter | Records read in shuffle |
| `spark_shuffle_records_written` | counter | Records written in shuffle |

## JVM Metrics

### Memory

| Metric | Type | Description |
|--------|------|-------------|
| `jvm_heap_used_bytes` | gauge | Heap memory used |
| `jvm_heap_max_bytes` | gauge | Max heap memory |
| `jvm_heap_committed_bytes` | gauge | Committed heap memory |
| `jvm_non_heap_used_bytes` | gauge | Non-heap memory used |

### GC

| Metric | Type | Description |
|--------|------|-------------|
| `jvm_gc_time_seconds` | gauge | Time spent in GC |
| `jvm_gc_count` | counter | Number of GC runs |
| `jvm_gc_pause_seconds` | summary | GC pause time |

### Threads

| Metric | Type | Description |
|--------|------|-------------|
| `jvm_threads_current` | gauge | Current thread count |
| `jvm_threads_daemon` | gauge | Daemon thread count |
| `jvm_threads_peak` | gauge | Peak thread count |

## Common Labels

All metrics include these labels:

| Label | Description |
|-------|-------------|
| `app_id` | Spark application ID |
| `namespace` | Kubernetes namespace |
| `executor_id` | Executor identifier |
| `stage_id` | Stage identifier |
| `attempt_id` | Attempt identifier |

## Prometheus Queries

### Job Health

```promql
# Job failure rate
rate(spark_job_status{app_id!="", status="2"}[1h])

# Job duration
spark_job_duration{app_id="my-app"}
```

### Resource Utilization

```promql
# Executor CPU usage
rate(spark_executor_cpu_time_seconds_total[5m]) / spark_executor_cores

# Memory usage percentage
spark_executor_memory_used_bytes / spark_executor_memory_max_bytes * 100

# GC overhead
rate(jvm_gc_time_seconds[5m]) * 100
```

### Performance

```promql
# Task duration skew
spark_task_duration_max / spark_task_duration_min

# Shuffle throughput
rate(spark_shuffle_write_bytes[5m])

# Task failure rate
rate(spark_task_failed_total[5m]) / rate(spark_task_completed_total[5m])
```

### Data Skew Detection

```promql
# High skew alert
spark_task_duration_max / spark_task_duration_avg > 5

# Shuffle read skew
max(spark_task_shuffle_read_bytes) / avg(spark_task_shuffle_read_bytes) > 10
```

## Dashboard Queries

### Executor Health

```promql
# Executor count over time
spark_executor_count{app_id="my-app"}

# Executor memory usage
spark_executor_memory_used_bytes{app_id="my-app"} / 1024 / 1024 / 1024

# Executor removal rate
rate(spark_executor_removed_total[5m])
```

### Performance Overview

```promql
# Jobs completed vs failed
sum(rate(spark_job_status{status="1"}[5m])) / sum(rate(spark_job_status[5m]))

# Average task duration
avg(spark_task_duration_avg{app_id="my-app"})

# Shuffle data volume
sum(rate(spark_shuffle_write_bytes{app_id="my-app"}[5m])) / 1024 / 1024
```

## Alerting Examples

### Critical Alerts

```yaml
- alert: SparkJobFailed
  expr: spark_job_status == 2
  for: 1m

- alert: SparkHighMemoryUsage
  expr: spark_executor_memory_used_bytes / spark_executor_memory_max_bytes > 0.9
  for: 10m

- alert: SparkHighGC
  expr: rate(jvm_gc_time_seconds[5m]) * 100 > 20
  for: 10m
```

### Warning Alerts

```yaml
- alert: SparkExecutorLoss
  expr: increase(spark_executor_removed_total[5m]) > 0

- alert: SparkTaskFailureRate
  expr: rate(spark_task_failed_total[5m]) / rate(spark_task_completed_total[5m]) > 0.05

- alert: SparkDataSkew
  expr: spark_task_duration_max / spark_task_duration_avg > 5
```

## Custom Metrics

Add custom metrics:

```python
from pyspark import TaskContext
from prometheus_client import Counter, Gauge

# Create custom metrics
custom_counter = Counter('my_custom_counter', 'Description')
custom_gauge = Gauge('my_custom_gauge', 'Description')

def my_udf(value):
    # Update custom metrics
    custom_counter.inc()
    custom_gauge.set(value)
    return value * 2

spark.udf.register("my_udf", my_udf)
```

## Related

- [Monitoring Setup](./setup-guide.md)
- [Grafana Dashboards](../../charts/observability/grafana/dashboards/)
