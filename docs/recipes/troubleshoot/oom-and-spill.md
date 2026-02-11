# OOM and Spill Diagnosis

## Problem
Executor running out of memory (OOM) or spilling data to disk, degrading performance.

## Diagnosis Steps

### 1. Check Memory Metrics

**Dashboard**: Spark Profiling → "Memory Used" panel

| Metric | Threshold | Action |
|--------|-----------|--------|
| Memory Used > 85% | Critical | Immediate action required |
| GC Time % > 20% | Warning | Tune JVM |
| Spill bytes > 0 | Warning | Increase memory, reduce data size |

### 2. Identify Spill Source

```python
# Parse event logs for spill operations
grep "spill" /var/log/spark-events/* | tail -10
```

### 3. Check Memory Fraction

**Dashboard**: Spark Profiling → "Executor Utilization" panel

Are all executors near 100% memory usage? Or only a few hot executors?

### 4. Review Task Logic

Is the task doing:
- Large `collect()` without `limit()`?
- `cache()` on huge dataset?
- `join` of large DataFrames?
- Cross join instead of broadcast join?

## Solutions

| Solution | When to Use |
|---------|--------------|
| Increase executor memory | Memory Used > 80% |
| Reduce `spark.executor.memory` | Current settings too high |
| Increase `spark.memory.fraction` | For off-heap storage |
| Use `limit()` on collect | Avoid collecting all data at once |
| Broadcast small tables | For join operations |
| Enable off-heap | `spark.memory.offHeap.enabled=true` |
| Tune `spark.sql.shuffle.partitions` | Match data volume |

## Related Dashboards

- **Spark Profiling**: Memory Used, GC Time, Executor Utilization
- **Job Phase Timeline**: Resource Wait (p95) shows allocation lag

## Recipe Checklist

- [ ] Check Memory Metrics in Spark Profiling dashboard
- [ ] Identify spilling stages in task Duration Heatmap
- [ ] Verify memory fraction settings
- [ ] Implement primary solution
- [ ] Document findings in job report
