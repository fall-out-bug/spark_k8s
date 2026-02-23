# GC Pressure Diagnosis

## Problem
Excessive Garbage Collection causing CPU overhead and slowing down application.

## Diagnosis Steps

### 1. Check GC Metrics

**Dashboard**: Spark Profiling → "GC Time %" panel

| Generation | Young GC | Old Gen | Mixed | Action |
|-----------|----------|--------|--------|
| G1 (Serial) | Frequent | Normal | None needed |
| G2 (Parallel) | Occasional | Normal | None needed |
| Concurrent | - | - | High | Immediate tuning required |

### 2. Identify GC Cause

From **Spark Profiling** dashboard:
- Is "GC Time" > 20%? → High GC pressure
- Which generation has highest ratio? → Likely culprit
- Is "Memory Used" high but not near 100%? → Memory leak or over-provisioning

### 3. Check Executor Config

```bash
# Check spark.executor.extraJavaOptions
kubectl get configmap spark-3.5-connect-config -o json | \
  jq -r '.data["spark-properties.conf.template"]' | grep -E "(-Xmx|-Xms|-XX:)"
```

### 4. Common GC Tuning Parameters

| JVM Setting | Purpose | Value |
|------------|---------|-------|
| `-XX:+UseG1GC` | Use G1 for small heaps (< 4GB) | 2-4GB |
| `-XX:+UseParallelGC` | Use parallel GC for multi-core machines | default |
| `-XX:MaxGCPauseMillis=200` | Maximum GC pause target | 200ms |
| `-XX:InitiatingHeapOccupancyPercent=30` | Start GC at 30% heap occupancy | 30% |
| `-XX:+PrintGCDetails` | Log GC details for debugging | - |
| `-XX:+PrintGCTimeStamps` | Add timestamps to GC logs | - |
| `-XX:+PrintGCApplicationStoppedTime` | Log when GC pauses application | - |
| `-XX:+PrintFLSStatistics` | Print failure/success stats | - |
| `-XX:+PrintGCTimeStamps` | Add timestamps to GC logs | - |

## Solutions

| Solution | When to Use |
|---------|--------------|
| Reduce object allocation | Use fewer temporary objects in code |
| Increase heap size | `-Xmx4g` instead of `-Xmx2g` |
| Tune GC settings | Based on generation (G1/G2/Z) |
| Off-heap storage | `spark.memory.offHeap.enabled=true` |
| Data serialization | Use Kryo instead of Java serialization |
| Batch size | Increase `spark.sql.shuffle.partitions` to reduce per-task data |

## Related Dashboards

- **Spark Profiling**: GC Time %, Memory Used
- **Job Phase Timeline**: Compute GC overhead vs task time

## Recipe Checklist

- [ ] Check GC Time % in Spark Profiling dashboard
- [ ] Identify GC generation type (G1/G2/CMS/Z)
- [ ] Verify executor `-Xmx` settings
- [ ] Check for memory leaks in code
- [ ] Implement GC tuning based on generation type
- [ ] Re-test with monitoring enabled
