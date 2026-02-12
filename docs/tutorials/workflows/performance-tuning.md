# Performance Tuning Tutorial

Learn to optimize Spark job performance on Kubernetes.

## Overview

This tutorial covers:
1. Identifying bottlenecks
2. Memory tuning
3. Parallelism optimization
4. Shuffle optimization
5. Caching strategies

## Prerequisites

- Spark UI access
- Prometheus metrics
- Basic understanding of Spark internals

## Tutorial: Optimize a Slow Job

### Step 1: Profile the Job

```bash
# Enable detailed profiling
spark-submit \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/ \
  --conf spark.sql.adaptive.enabled=true \
  your_job.py
```

```python
# Profile and identify bottlenecks
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("performance-profiling") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .getOrCreate()

# Get Spark UI URL
print(f"Spark UI: {spark.conf.get('spark.ui.prometheus.enabled')}")

# Run job and collect metrics
df = spark.read.parquet("s3a://data/large/")

# Add timing
import time
start = time.time()

result = df \
    .groupBy("category") \
    .agg(sum("amount").alias("total")) \
    .collect()

elapsed = time.time() - start
print(f"Job completed in {elapsed:.2f} seconds")
```

### Step 2: Analyze Spark UI

Check the following in Spark UI:

| Stage | What to Look For |
|-------|------------------|
| **Jobs** | Which stages take longest |
| **Stages** | Skew, task duration variance |
| **Storage** | Cache hit rates |
| **Environment** | Executor utilization |
| **SQL** | Query plan details |

### Step 3: Identify Issues

```python
# analyze_performance.py
def analyze_job_metrics(app_id):
    """Analyze job metrics from Prometheus."""
    import requests

    prometheus_url = "http://prometheus.observability.svc.cluster.local:9090"

    # Get task duration stats
    query = f'''
    spark_task_duration_max{{app_id="{app_id}"}} /
    spark_task_duration_min{{app_id="{app_id}"}}
    '''

    response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": query}
    )

    skew_ratio = float(response.json()["data"]["result"][0]["value"][1])

    if skew_ratio > 5:
        print(f"⚠️ Data skew detected: {skew_ratio}x max/min ratio")
        print("   Consider salting keys or increasing partitions")

    # Check shuffle spill
    spill_query = f'''
    sum(spark_task_disk_bytes_spilled{{app_id="{app_id}"}}) /
    sum(spark_task_memory_bytes_spilled{{app_id="{app_id}"}})
    '''

    # Check GC time
    gc_query = f'''
    avg(rate(jvm_gc_time_seconds{{app_id="{app_id}"}}[5m])) * 100
    '''

    gc_response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": gc_query}
    )

    gc_pct = float(gc_response.json()["data"]["result"][0]["value"][1])

    if gc_pct > 20:
        print(f"⚠️ High GC time: {gc_pct:.1f}%")
        print("   Increase executor memory or reduce cache size")
```

### Step 4: Apply Optimizations

#### 4.1 Fix Data Skew

```python
# Before: Skewed join
skewed_result = large_df.join(
    small_df,
    "user_id"
)

# After: Salt the join key
from pyspark.sql.functions import rand, floor, concat, lit

# Add salt to large DataFrame
SALT_COUNT = 10
large_with_salt = large_df \
    .withColumn("salt", (floor(rand() * SALT_COUNT)).cast("string")) \
    .withColumn("user_id_salted", concat(col("user_id"), lit("_"), col("salt")))

# Explode small DataFrame
from pyspark.sql.functions import explode, array

small_exploded = small_df \
    .withColumn("salt", explode(array([lit(i) for i in range(SALT_COUNT)]))) \
    .withColumn("user_id_salted", concat(col("user_id"), lit("_"), col("salt")))

# Join on salted key
result = large_with_salt.join(
    small_exploded,
    "user_id_salted"
).drop("salt", "user_id_salted")
```

#### 4.2 Optimize Memory

```python
# Configure memory properly
memory_config = {
    # Executor memory allocation
    "spark.executor.memory": "8g",
    "spark.executor.memoryOverhead": "1g",
    "spark.memory.fraction": "0.8",
    "spark.memory.storageFraction": "0.3",

    # Off-heap memory
    "spark.memory.offHeap.enabled": "true",
    "spark.memory.offHeap.size": "1g",

    # Memory per task
    "spark.executor.memoryOverhead": "1g",

    # Reduce cache overhead
    "spark.sql.inMemoryColumnarStorage.compressed": "true",
    "spark.sql.inMemoryColumnarStorage.batchSize": "10000",
}
```

#### 4.3 Optimize Shuffle

```python
# Configure shuffle
shuffle_config = {
    # Shuffle service
    "spark.shuffle.service.enabled": "true",
    "spark.shuffle.service.port": "7337",
    "spark.shuffle.compress": "true",
    "spark.shuffle.spill.compress": "true",

    # Shuffle file management
    "spark.shuffle.sort.bypassMergeThreshold": "400",
    "spark.shuffle.accurateBlockThreshold": "100m",

    # Optimize partitions
    "spark.sql.shuffle.partitions": "200",
    "spark.default.parallelism": "200",
}

# Reduce shuffle by filtering early
df = spark.read.parquet("s3a://data/transactions/") \
    .filter(col("status") == "completed") \
    .filter(col("amount") > 0) \
    .select("user_id", "amount", "timestamp")  # Select early

# Coalesce before write
df.coalesce(100).write.parquet("s3a://output/")
```

#### 4.4 Optimize Caching

```python
from pyspark.storagelevel import StorageLevel

# Cache hot data appropriately
# - MEMORY_ONLY: Fast but volatile
# - MEMORY_AND_DISK: Safer but slower
# - MEMORY_ONLY_SER: Compressed, less memory
# - MEMORY_AND_DISK_SER: Compressed + persisted

hot_df = df.filter(col("date") == current_date()) \
    .select("user_id", "profile") \
    .persist(StorageLevel.MEMORY_AND_DISK_SER)

# Use cache() for repeated actions
hot_df.cache().count()  # Materialize cache

# Unpark when done
hot_df.unpersist()
```

### Step 5: Adaptive Query Execution

```python
# Enable AQE for automatic optimization
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")

# AQE will:
# - Coalesce small partitions
# - Handle skew joins automatically
# - Optimize shuffle partitions
# - Convert sort-merge join to broadcast join
```

### Step 6: Advanced Techniques

#### Predicate Pushdown

```python
# Push filters to data source
df = spark.read.parquet("s3a://data/large/") \
    .filter(col("year") == 2024) \
    .filter(col("month") == 1)

# Use partition pruning
df = spark.read.parquet("s3a://data/large/year=2024/month=01/")
```

#### Column Pruning

```python
# Select only needed columns early
df = spark.read.parquet("s3a://data/large/") \
    .select("id", "name", "value") \
    .filter(col("value") > 0)
```

#### Broadcast Hash Join

```python
from pyspark.sql.functions import broadcast

# Broadcast small table (< 200MB)
result = large_df.join(
    broadcast(small_lookup_df),
    "key"
)

# Configure threshold
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "200MB")
```

## Performance Tuning Checklist

| Area | Check | Action |
|------|-------|--------|
| **Executors** | CPU utilization | Increase cores or add executors |
| **Memory** | GC time > 20% | Increase executor memory |
| **Skew** | Max/min > 5x | Salt keys or AQE |
| **Shuffle** | Large spill | Increase partitions |
| **Cache** | Low hit rate | Cache different data |
| **Parallelism** | Tasks < cores * 3 | Reduce partitions |
| **Parallelism** | Tasks > cores * 10 | Increase partitions |

## Optimization Order

1. **First**: Fix obvious issues (skew, memory)
2. **Second**: Tune shuffle and partitions
3. **Third**: Optimize caching and persistence
4. **Last**: Fine-tune Spark configs

## Monitoring Performance

```python
# Track job metrics
class PerformanceTracker:
    def __init__(self, spark):
        self.spark = spark
        self.start_time = None

    def start(self):
        self.start_time = time.time()

    def report(self):
        if not self.start_time:
            return

        elapsed = time.time() - self.start_time

        # Get executor metrics
        executors = self.spark.statusTracker().getExecutorInfos()

        print(f"\n=== Performance Report ===")
        print(f"Total time: {elapsed:.2f}s")
        print(f"Executors: {len(executors)}")

        # Get metrics from Spark UI
        print("\nCheck Spark UI for details:")
        print(f"  http://<driver-pod>:4040")
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job hangs | Skew, dead executors | Check Spark UI, restart |
| Out of memory | Cache too large, too many partitions | Reduce cache, coalesce |
| Slow shuffle | Too many small files | Increase shuffle partitions |
| GC overhead | Large objects, caching | Use SER storage level |
| Stragglers | Skew, slow nodes | Enable speculation, salt keys |

## Best Practices

1. **Start with defaults**: Only tune when needed
2. **Change one thing**: Measure impact before next change
3. **Profile before tuning**: Know the bottleneck
4. **Monitor in production**: Real data differs from test
5. **Document changes**: Keep track of what works

## Next Steps

- [ ] Set up continuous profiling
- [ ] Create performance regression tests
- [ ] Build automated tuning recommendations
- [ ] Document cluster-specific configs

## Related

- [Spark Configuration Guide](../../docs/reference/spark-config.md)
- [Monitoring Guide](../../docs/operations/monitoring/index.md)
- [Performance Runbook](../../docs/operations/runbooks/performance-issues.md)
