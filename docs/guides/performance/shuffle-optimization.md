# Shuffle Optimization Guide

Shuffle is often the most expensive operation in Spark jobs. This guide explains how to optimize it.

## Understanding Shuffle

Shuffle occurs when:
- Data needs to be redistributed across partitions
- Join operations on non-collocated data
- Aggregations with non-local keys
- Sorting operations

```
Stage 1          Shuffle          Stage 2
┌─────┐                          ┌─────┐
│ P1  │────┐              ┌─────▶│ P1' │
├─────┤    │              │      ├─────┤
│ P2  │────┼─────────────┼─────▶│ P2' │
├─────┤    │              │      ├─────┤
│ P3  │────┘              └─────▶│ P3' │
└─────┘                          └─────┘
```

## Key Metrics

Monitor these shuffle metrics:

| Metric | Good | Bad |
|--------|------|-----|
| Shuffle read/write | Low | High |
| Shuffle spill | None | > 1GB |
| Shuffle disk I/O | None | High |
| Remote fetches | Low | > 50% |

## Optimization Techniques

### 1. Reduce Shuffle Data

```python
# Before: Shuffles all columns
df = df.groupBy("category").agg(sum("amount"))

# After: Select columns before shuffle
df = df.select("category", "amount") \
    .groupBy("category") \
    .agg(sum("amount"))
```

### 2. Broadcast Small Tables

```python
from pyspark.sql.functions import broadcast

# Small table < 200MB? Broadcast it
result = large_df.join(
    broadcast(small_df),
    "key"
)

# Configure threshold
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "200MB")
```

### 3. Optimize Partition Count

```python
# Too few partitions -> slow, OOM
# Too many partitions -> overhead, small files

# Calculate optimal partition count
def calculate_partitions(data_size_gb, target_partition_mb=128):
    """Calculate optimal number of partitions."""
    return max(200, int(data_size_gb * 1024 / target_partition_mb))

# Apply
spark.conf.set("spark.sql.shuffle.partitions", calculate_partitions(500))
```

### 4. Repartition Early

```python
# Repartition before expensive operations
df = df.repartition(100, "category") \
    .filter(col("amount") > 0) \
    .groupBy("category") \
    .agg(sum("amount"))
```

### 5. Use Appropriate Join Types

```python
# SortMergeJoin (default for large tables)
# BroadcastHashJoin (one table small)
# ShuffleHashJoin (one table fits in memory)

# Force broadcast join
from pyspark.sql.functions import broadcast
result = broadcast(small_df).join(large_df, "key")

# Force shuffle hash join
result = small_df.join(
    large_df,
    "key",
    hint="SHUFFLE_HASH"
)
```

## Configuration Tuning

### Shuffle Service

```python
config = {
    # Enable shuffle service (required for dynamic allocation)
    "spark.shuffle.service.enabled": "true",
    "spark.shuffle.service.port": "7337",

    # Compression
    "spark.shuffle.compress": "true",
    "spark.shuffle.spill.compress": "true",
    "spark.io.compression.codec": "lz4",
    "spark.io.compression.lz4 blockSize": "128k",

    # File consolidation
    "spark.shuffle.consolidateFiles": "true",
}
```

### Shuffle Buffer

```python
config = {
    # Memory for shuffle
    "spark.shuffle.file.buffer": "32k",
    "spark.shuffle.memoryFraction": "0.2",

    # Reduce buffer for shuffle hash join
    "spark.shuffle.hash.initialFileBufferSize": "1m",
}
```

## Advanced Techniques

### 1. Map-Side Aggregation

```python
# Pre-aggregate before shuffle
df = df.groupBy("category", "sub_category") \
    .agg(sum("amount").alias("partial_sum")) \
    .groupBy("category") \
    .agg(sum("partial_sum").alias("total_sum"))
```

### 2. Salting for Skew

```python
from pyspark.sql.functions import rand, floor, concat, lit

# Add salt to skewed key
salt_factor = 10

df_with_salt = df.withColumn(
    "salt",
    (floor(rand() * salt_factor)).cast("int")
).withColumn(
    "salted_key",
    concat(col("skewed_key"), lit("_"), col("salt"))
)

# Explode lookup table
from pyspark.sql.functions import explode, array

lookup_exploded = lookup_df.withColumn(
    "salt",
    explode(array([lit(i) for i in range(salt_factor)]))
).withColumn(
    "salted_key",
    concat(col("key"), lit("_"), col("salt"))
)

# Join on salted key
result = df_with_salt.join(
    lookup_exploded,
    "salted_key"
).drop("salt", "salted_key")
```

### 3. Bucketed Tables

```python
# Bucket tables for join optimization
df.write \
    .bucketBy(100, "join_key") \
    .sortBy("join_key") \
    .mode("overwrite") \
    .saveAsTable("bucketed_table")

# Joins on bucketed tables avoid shuffle
result = df1.join(df2, "join_key")
```

### 4. Partition Pruning

```python
# Store partitioned by date
df.write \
    .partitionBy("year", "month", "day") \
    .mode("overwrite") \
    .parquet("s3a://data/partitioned/")

# Read only needed partitions
df_filtered = spark.read.parquet(
    "s3a://data/partitioned/year=2024/month=01/"
)
```

## Monitoring Shuffle

```python
def analyze_shuffle_metrics(spark, app_id):
    """Analyze shuffle metrics."""
    import requests

    prometheus_url = "http://prometheus.observability.svc.cluster.local:9090"

    queries = {
        "shuffle_read": f'sum(spark_shuffle_read_bytes{{app_id="{app_id}"}})',
        "shuffle_write": f'sum(spark_shuffle_write_bytes{{app_id="{app_id}"}})',
        "shuffle_spill": f'sum(spark_task_disk_bytes_spilled{{app_id="{app_id}"}})',
    }

    for name, query in queries.items():
        response = requests.get(
            f"{prometheus_url}/api/v1/query",
            params={"query": query}
        )
        result = response.json()
        if result["data"]["result"]:
            value = float(result["data"]["result"][0]["value"][1])
            print(f"{name}: {value / 1e9:.2f} GB")

    # Check for skew
    skew_query = f'''
    max(spark_task_shuffle_read_bytes{{app_id="{app_id}"}}) /
    avg(spark_task_shuffle_read_bytes{{app_id="{app_id}"}})
    '''

    response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": skew_query}
    )
    skew = float(response.json()["data"]["result"][0]["value"][1])

    if skew > 5:
        print(f"⚠️ Shuffle skew detected: {skew:.1f}x")
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Slow shuffle | Too many small files | Coalesce before write |
| OOM during shuffle | Partition too large | Increase partitions |
| High disk I/O | Memory too small | Increase executor memory |
| High remote fetches | Data locality poor | Increase replication |
| Straggler tasks | Data skew | Apply salting |

## Best Practices Summary

1. **Filter early**: Reduce data before shuffle
2. **Select columns**: Don't shuffle unused data
3. **Broadcast small tables**: Avoid shuffle entirely
4. **Right partition count**: Balance parallelism vs overhead
5. **Monitor spill**: Spill indicates memory pressure
6. **Fix skew**: Address uneven data distribution

## Related

- [Data Skew Guide](./data-skew.md)
- [Executor Sizing](./executor-sizing.md)
