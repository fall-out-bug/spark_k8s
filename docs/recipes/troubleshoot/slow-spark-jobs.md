# Slow Spark Jobs Diagnosis

## Problem
Spark jobs are taking too long to complete. Users report job wall time exceeds expected duration.

## Diagnosis Steps

### 1. Identify the Phase

Use **Job Phase Timeline** dashboard to identify which phase is causing the delay:

```
# Which phase takes longest?
grep "Phase 1: Resource Wait" /var/log/spark-events | \
  grep "app_start" | tail -1 | \
  xargs -I{} date +%s
```

### 2. Check Resource Wait Time

Calculate resource wait percentage:

| Metric | Target | Action |
|--------|--------|--------|
| spark_resource_wait_seconds | < 300s | OK: > 300s → **PriorityClass** issue |
| spark_resource_wait_seconds | > 600s | **Critical**: stuck waiting for executors |

**Dashboard Panel**: "Resource Wait (p95)" in Job Phase Timeline

### 3. Check Executor Lifecycle

Are executors dying before completing tasks?

```
# Check executor pod restarts
kubectl get pods -n spark-load-test -l spark-role=executor -o json | \
  jq '.items[] | {restart, .metadata.name} | select(.restart, .metadata.name)}'
```

### 4. Profile the Application

Use Spark UI or **Spark Profiling** dashboard to identify bottlenecks:

```
# Open Spark UI: http://localhost:4040
# Go to Jobs tab, click on your job
# Check Stages: sort/aggregate/shuffle/etc.
# Look for long-running tasks
```

### 5. Review Executor Logs

```bash
# Executor logs from Spark Connect
kubectl logs -n spark-load-test -l spark-role=executor --tail=100 | \
  grep -E "(GC|pause|oom|killed)"
```

## Common Causes & Solutions

| Cause | Solution |
|--------|----------|
| **K8s Resource Starvation** | Increase PriorityClass priority, reduce concurrent workloads |
| **Large Stage Data** | Add shuffle partitions, reduce task sizes |
| **GC Overhead** | Increase executor memory, tune JVM (-XX:+UseG1GC) |
| **S3 I/O Bottleneck** | Increase `multipart.size` (default 128MB → 512MB) |
| **Dynamic Allocation Lag** | Set `spark.dynamicAllocation.maxExecutors` appropriately |

## Related Dashboards

- **Job Phase Timeline**: Resource wait tracking
- **Spark Profiling**: GC Time, Memory, Shuffle Skew

## Recipe Checklist

- [ ] Check Job Phase Timeline dashboard
- [ ] Calculate resource wait percentage
- [ ] Profile application with Spark UI
- [ ] Review executor logs for OOM/GC
- [ ] Check S3 metrics dashboard (when available)
- [ ] Implement primary solution
