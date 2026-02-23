# Shuffle Bottleneck Diagnosis

## Problem
Shuffle read/write operations are slow, causing long task completion times.

## Diagnosis Steps

### 1. Check Shuffle Metrics

**Dashboard**: Spark Profiling → "Shuffle Read/Write Ratio" panel

| Metric | Good | Bad | Action |
|--------|-------|------|--------|
| Read/Write Ratio < 0.5 | Excellent | No action needed |
| Read/Write Ratio 0.5-1.5 | Good | Monitor |
| Read/Write Ratio 1.5-3.0 | Warning | Consider optimization |
| Read/Write Ratio > 3.0 | Bad | Immediate action required |

### 2. Identify Shuffle Type

```bash
# Check shuffle manager
grep "Celeborn" /var/log/spark-events/* | head -1
```

- Celeborn (RSS): Uses local disk → may be slow
- SortShuffleManager: May have high merge overhead

### 3. Check Network I/O

```bash
# Check shuffle service times (from event logs)
# Use Spark UI: Environment tab → Spark Properties
# Look for: spark.shuffle.service.rpc.enabled, spark.shuffle.file.buffer
```

## Solutions

| Solution | When to Use |
|---------|--------------|
| Enable Celeborn | For cross-pod shuffling |
| Optimize `spark.shuffle.file.buffer` | Default 32KB → 256KB |
| Use `sort` instead of `groupBy` + `join` | Reduces shuffle |
| Broadcast hash joins | For small tables |
| Increase `spark.sql.shuffle.partitions` | More partitions = less data per task |
| Tune `spark.reducer.maxSizeInFlight` | For large shuffles |

## Related Dashboards

- **Spark Profiling**: Shuffle Read/Write Ratio, Shuffle Skew
- **Job Phase Timeline**: Compute vs I/O breakdown

## Recipe Checklist

- [ ] Check Shuffle Read/Write Ratio in Spark Profiling dashboard
- [ ] Identify shuffle manager type (Celeborn vs SortShuffleManager)
- [ ] Verify spark.shuffle.file.buffer configuration
- [ ] Implement primary solution
- [ ] Document shuffle performance baseline
