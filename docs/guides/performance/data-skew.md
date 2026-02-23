# Data Skew Guide

Data skew is a common performance issue where some partitions have significantly more data than others.

## What is Data Skew?

```
Normal Distribution          Skewed Distribution
┌─────────────────┐          ┌─────────────────┐
│ P1: █████       │          │ P1: ████████████│
│ P2: █████       │          │ P2: █           │
│ P3: █████       │          │ P3: ██          │
│ P4: █████       │          │ P4: █           │
└─────────────────┘          └─────────────────┘
   Balanced (good)              Skewed (bad)
```

## Detecting Skew

### 1. Task Duration Analysis

```python
def detect_skew(spark, app_id):
    """Detect data skew from task metrics."""
    import requests

    prometheus_url = "http://prometheus.observability.svc.cluster.local:9090"

    query = f'''
    spark_task_duration_max{{app_id="{app_id}"}} /
    spark_task_duration_avg{{app_id="{app_id}"}}
    '''

    response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": query}
    )

    skew_ratio = float(response.json()["data"]["result"][0]["value"][1])

    if skew_ratio > 5:
        print(f"⚠️ SEVERE SKEW: {skew_ratio:.1f}x max/avg ratio")
    elif skew_ratio > 3:
        print(f"⚠️ Moderate skew: {skew_ratio:.1f}x max/avg ratio")
    else:
        print(f"✓ Low skew: {skew_ratio:.1f}x max/avg ratio")

    return skew_ratio
```

### 2. Partition Size Analysis

```python
def analyze_partition_sizes(df):
    """Analyze partition sizes."""
    # Get partition sizes
    sizes = df.rdd.mapPartitions(lambda x: [sum(1 for _ in x)]).collect()

    import statistics

    print(f"Partitions: {len(sizes)}")
    print(f"Min size: {min(sizes)}")
    print(f"Max size: {max(sizes)}")
    print(f"Avg size: {statistics.mean(sizes):.0f}")
    print(f"Median: {statistics.median(sizes)}")

    skew_ratio = max(sizes) / statistics.mean(sizes)
    print(f"Skew ratio: {skew_ratio:.1f}x")

    return sizes
```

## Causes of Skew

| Cause | Example | Solution |
|-------|---------|----------|
| **Key distribution** | Few keys have most data | Salting |
| **Join keys** | Null or default values | Filter or distribute |
| **Data type** | Enum/string keys | Numeric encoding |
| **Time-series** | Recent data has more | Temporal partitioning |

## Solutions

### 1. Salting for Aggregation

```python
from pyspark.sql.functions import rand, floor, concat, lit, when

def salted_aggregation(df, key_col, agg_col, salt_factor=10):
    """Perform aggregation with salting for skewed data."""

    # Add random salt
    df_salted = df.withColumn(
        "salt",
        (floor(rand() * salt_factor)).cast("int")
    ).withColumn(
        "salted_key",
        concat(col(key_col), lit("_"), col("salt"))
    )

    # Pre-aggregate with salt
    pre_agg = df_salted.groupBy("salted_key").agg(
        sum(agg_col).alias("partial_sum")
    )

    # Remove salt and final aggregate
    result = pre_agg.withColumn(
        key_col,
        split(col("salted_key"), "_")[0]
    ).groupBy(key_col).agg(
        sum("partial_sum").alias("total_sum")
    )

    return result

# Usage
result = salted_aggregation(
    df,
    "user_id",
    "amount",
    salt_factor=10
)
```

### 2. Salting for Joins

```python
from pyspark.sql.functions import explode, array

def salted_join(large_df, small_df, key_col, salt_factor=10):
    """Perform join with salting for skewed keys."""

    # Add salt to large DataFrame
    large_salted = large_df.withColumn(
        "salt",
        (floor(rand() * salt_factor)).cast("int")
    ).withColumn(
        "salted_key",
        concat(col(key_col), lit("_"), col("salt"))
    )

    # Explode small DataFrame
    small_exploded = small_df.withColumn(
        "salt",
        explode(array([lit(i) for i in range(salt_factor)]))
    ).withColumn(
        "salted_key",
        concat(col(key_col), lit("_"), col("salt"))
    )

    # Join on salted key
    result = large_salted.join(
        small_exploded,
        "salted_key"
    ).drop("salt", "salted_key")

    return result

# Usage
result = salted_join(transactions_df, users_df, "user_id")
```

### 3. Handle Null Keys

```python
# Distribute nulls across partitions
df = df.withColumn(
    "distributed_key",
    when(col("key").isNull(),
         concat(lit("NULL_"), (floor(rand() * 100)).cast("string"))
    ).otherwise(col("key"))
)

# Or filter if nulls not needed
df = df.filter(col("key").isNotNull())
```

### 4. Separate Skewed Keys

```python
# Identify and handle hot keys separately
hot_keys = ["user_1", "user_2", "user_3"]

# Process hot keys with different logic
hot_data = df.filter(col("user_id").isin(hot_keys))
normal_data = df.filter(~col("user_id").isin(hot_keys))

# Use broadcast for hot keys
from pyspark.sql.functions import broadcast

hot_result = broadcast(hot_data).join(lookup_df, "user_id")
normal_result = normal_data.join(lookup_df, "user_id")

# Combine results
result = hot_result.union(normal_result)
```

### 5. AQE Skew Join Optimization

```python
# Enable Adaptive Query Execution
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")

# Spark will automatically detect and handle skew
```

## Configuration for Skew

```python
# Optimize for skewed data
skew_config = {
    # AQE settings
    "spark.sql.adaptive.enabled": "true",
    "spark.sql.adaptive.skewJoin.enabled": "true",
    "spark.sql.adaptive.skewJoin.skewedPartitionFactor": "5",
    "spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB",

    # Shuffle optimization
    "spark.sql.shuffle.partitions": "200",  # More partitions for skew

    # Broadcast threshold
    "spark.sql.autoBroadcastJoinThreshold": "50MB",  # Lower for skew
}
```

## Best Practices

1. **Detect early**: Check task durations in Spark UI
2. **Know your data**: Understand key distribution
3. **Use AQE**: Enable adaptive optimization
4. **Handle special cases**: Nulls, hot keys separately
5. **Monitor continuously**: Skew can appear over time

## Monitoring Skew

Create alert for skew:

```yaml
- alert: SparkDataSkewDetected
  expr: |
    spark_task_duration_max / spark_task_duration_avg > 5
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Data skew in {{ $labels.app_id }}"
    description: "Max/Min task ratio is {{ $value }}x"
```

## Related

- [Shuffle Optimization](./shuffle-optimization.md)
- [Performance Tuning](../../tutorials/workflows/performance-tuning.md)
