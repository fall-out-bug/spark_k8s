# Performance Tuning Runbook

Optimize Spark job performance.

## Diagnosis

### Step 1: Identify Bottleneck

```bash
# Run health check
./scripts/diagnostics/spark-health-check.sh

# Access Spark UI
kubectl port-forward svc/spark-history 18080:18080
open http://localhost:18080
```

Check the following:
- **Stage duration** → Slow stages
- **Task duration** → Stragglers
- **GC time** → Memory pressure
- **Shuffle read/write** → Data skew

### Step 2: Analyze Metrics

```python
# Get Spark metrics
metrics = spark.sparkContext.statusTracker()

# Check executor distribution
executors = spark.sparkContext.statusTracker().getExecutorInfos()
for e in executors:
    print(f"{e.id}: {e.numTasks()} tasks, {e.activeTasks} active")
```

## Optimization Strategies

### Strategy 1: Increase Parallelism

**When:** Tasks take too long, low CPU usage

```python
# Increase shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", "400")  # Default: 200

# Increase executor count
spark.conf.set("spark.executor.instances", "20")
```

### Strategy 2: Reduce Skew

**When:** Some tasks much slower than others

```python
# Detect skew
df.groupBy("key").count().orderBy("count", ascending=False).show(10)

# Fix: Salting
import random
df = df.withColumn("salted_key", F.concat(F.col("key"), F.lit("_"), F.floor(F.rand() * 10)))

# Fix: Adaptive Query Execution
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
```

### Strategy 3: Cache Intermediate Results

**When:** Repeated operations on same dataset

```python
# Cache frequently used data
df_cached = df.cache()
df_cached.count()  # Action to materialize cache

# Check storage level
spark.sparkContext.getRDDStorageInfo()
```

### Strategy 4: Optimize Joins

**When:** Join operations are slow

```python
# Broadcast small tables
from pyspark.sql.functions import broadcast
result = large_df.join(broadcast(small_df), "key")

# Use appropriate join type
result = df1.join(df2, "key", "inner")  # Faster than left/outer
```

### Strategy 5: Tune Memory

**When:** High GC time, OOM

```python
# Increase memory
spark.conf.set("spark.executor.memory", "16g")
spark.conf.set("spark.executor.memoryOverhead", "2g")

# Adjust memory fraction
spark.conf.set("spark.memory.fraction", "0.8")
spark.conf.set("spark.memory.storageFraction", "0.3")
```

## Performance Benchmarks

### Expected Performance

| Operation | Target | Acceptable |
|-----------|--------|------------|
| Simple select | <1s | <5s |
| Aggregation (1M rows) | <5s | <15s |
| Join (1M x 100k) | <10s | <30s |
| ML training (10M rows) | <5min | <15min |

### When to Escalate

If performance is 10x slower than benchmarks:
1. Verify data volume
2. Check cluster capacity
3. Review code for anti-patterns
4. Contact platform team
