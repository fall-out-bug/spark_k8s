# Streaming Patterns

Advanced streaming patterns for Structured Streaming on Kubernetes.

## Overview

This guide covers production streaming patterns:
- Exactly-once semantics
- Backpressure handling
- State management
- Stream-stream joins
- Advanced aggregations
- Handling late data

## Exactly-Once Semantics

### Understanding Exactly-Once

Exactly-once means each record is processed exactly one time, even with failures.

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Source │────▶│  Offset │────▶│ Process │────▶│  Sink   │
│  (Kafka)│     │ Tracking│     │         │     │ (Idempotent)│
└─────────┘     └─────────┘     └─────────┘     └─────────┘
                      │                              │
                      ▼                              ▼
                Checkpointing                   Idempotent Writes
```

### Implementation

```python
from pyspark.sql import SparkSession
from delta.tables import DeltaTable

spark = SparkSession.builder \
    .appName("exactly-once-streaming") \
    .config("spark.sql.streaming.schemaInference", "true") \
    .config("spark.sql.streaming.checkpointLocation", "s3a://checkpoints/exactly-once") \
    .getOrCreate()

# Read from Kafka with offset tracking
df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "events") \
    .option("startingOffsets", "latest") \
    .option("failOnDataLoss", "false") \
    .load()

# Process
processed = df.selectExpr(
    "CAST(value AS STRING) as event",
    "timestamp as processed_time"
)

# Write with exactly-once (idempotent sink)
query = processed.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "s3a://checkpoints/exactly-once/delta") \
    .option("mergeSchema", "true") \
    .trigger(processingTime='30 seconds') \
    .start("s3a://data/events")

# Delta Lake provides exactly-once through:
# 1. Atomic commits (ACID transactions)
# 2. Idempotent writes (duplicates ignored)
# 3. Checkpoint recovery
```

### Idempotent Sinks

```python
def write_idempotent_microbatch(df, batch_id):
    """Write micro-batch with idempotency."""
    # Add batch metadata
    df = df.withColumn("batch_id", lit(batch_id))
    df = df.withColumn("write_timestamp", current_timestamp())

    # Use merge for upsert (idempotent)
    delta_table = DeltaTable.forPath(spark, "s3a://data/output")

    delta_table.alias("target") \
        .merge(
            df.alias("source"),
            "target.event_id = source.event_id"
        ) \
        .whenMatchedUpdateAll() \
        .whenNotMatchedInsertAll() \
        .execute()

query = processed.writeStream \
    .foreachBatch(write_idempotent_microbatch) \
    .outputMode("update") \
    .option("checkpointLocation", "s3a://checkpoints/idempotent") \
    .trigger(processingTime='30 seconds') \
    .start()
```

## Backpressure Handling

### Detecting Backpressure

```python
def detect_backpressure(spark, app_id):
    """Detect backpressure from metrics."""
    import requests

    prometheus_url = "http://prometheus.observability.svc.cluster.local:9090"

    # Check for lag
    lag_query = f'''
    sum(kafka_consumer_lag{{app_id="{app_id}"}})
    '''

    response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": lag_query}
    )

    lag = int(response.json()["data"]["result"][0]["value"][1])

    if lag > 1_000_000:
        print(f"⚠️ High consumer lag: {lag:,}")
        return True
    return False
```

### Handling Strategies

```python
# Strategy 1: Increase parallelism
spark.conf.set("spark.sql.shuffle.partitions", "400")

# Strategy 2: Adaptive Query Execution
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")

# Strategy 3: Micro-batch size
query = df.writeStream \
    .format("delta") \
    .trigger(processingTime='10 seconds')  # Smaller batches
    .start()

# Strategy 4: Continuous processing (experimental)
query = df.writeStream \
    .format("delta") \
    .trigger(continuous='1 second') \
    .start()
```

## State Management

### Key State Stores

```
┌─────────────────────────────────────────────────────────────┐
│                    State Store Types                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Memory    │  │   RocksDB   │  │   HDFS      │       │
│  │   (Fast)    │  │  (Balanced) │  │ (Scalable)  │       │
│  │  Volatile   │  │  Durable    │  │  Slow       │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Configuration

```python
# State store configuration
state_config = {
    # Provider
    "spark.sql.streaming.stateStore.provider": "rocksdb",  # or "hdfs"

    # State store compression
    "spark.sql.streaming.stateStore.compression.codec": "lz4",

    # State store retention
    "spark.sql.streaming.stateStore.minDeltasForSnapshot": "10",
    "spark.sql.streaming.stateStore.skipFallback": "true",

    # Large state handling
    "spark.sql.streaming.stateStore.stateSchemaTracking": "true",
}
```

### Large State Optimization

```python
# For large state (e.g., deduplication over long windows)
from pyspark.sql.functions import col, window

# 1. Use watermarks to expire state
df = df.withWatermark("timestamp", "7 days")

# 2. Partition state by key
df = df.withColumn("state_key", concat(col("user_id"), col("date")))

# 3. Use incremental state
state_df = df.writeStream \
    .format("memory") \
    .outputMode("complete") \
    .queryName("state") \
    .start()
```

## Stream-Stream Joins

### Inner Join

```python
# Join two streams
stream1 = spark.readStream \
    .format("kafka") \
    .option("subscribe", "stream1") \
    .load()

stream2 = spark.readStream \
    .format("kafka") \
    .option("subscribe", "stream2") \
    .load()

# Both streams must have watermarks for joins
stream1 = stream1.withWatermark("timestamp", "10 minutes")
stream2 = stream2.withWatermark("timestamp", "10 minutes")

# Join with event-time constraints
joined = stream1.alias("a").join(
    stream2.alias("b"),
    expr("""
        a.key = b.key AND
        a.timestamp >= b.timestamp - interval 5 minutes AND
        a.timestamp <= b.timestamp + interval 5 minutes
    "")
)

query = joined.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "s3a://checkpoints/stream-join") \
    .trigger(processingTime='1 minute') \
    .start("s3a://data/joined")
```

### Left Outer Join

```python
# Left outer join with late data handling
left = stream1.withWatermark("timestamp", "10 minutes")
right = stream2.withWatermark("timestamp", "10 minutes")

# Outer join: emits results as soon as watermark passes
joined = left.join(
    right,
    expr("a.key = b.key"),
    "leftOuter"
)

# Note: Updates to the result may occur as late data arrives
```

## Advanced Aggregations

### Sessionization

```python
from pyspark.sql.functions import session_window

# Dynamic session windows (gap = timeout)
sessionized = df \
    .withWatermark("timestamp", "2 hours") \
    .groupBy(
        session_window(col("timestamp"), "30 minutes"),  # 30 min sessions
        col("user_id")
    ) \
    .agg(
        count("*").alias("event_count"),
        sum("amount").alias("total_amount")
    )

query = sessionized.writeStream \
    .format("delta") \
    .outputMode("update") \
    .option("checkpointLocation", "s3a://checkpoints/sessionization") \
    .trigger(processingTime='5 minutes') \
    .start("s3a://data/sessions")
```

### Global Aggregation

```python
# Aggregate across all batches
global_agg = df \
    .withWatermark("timestamp", "1 hour") \
    .groupBy(col("user_id")) \
    .agg(
        count("*").alias("total_events"),
        approx_count_distinct("session_id").alias("unique_sessions")
    )

# Use outputMode = "complete" for global aggregates
query = global_agg.writeStream \
    .format("memory") \
    .outputMode("complete") \
    .queryName("global_stats") \
    .start()

# Query the in-memory table
spark.sql("SELECT * FROM global_stats ORDER BY total_events DESC LIMIT 10").show()
```

## Handling Late Data

### Watermark Strategy

```python
# Watermark defines how late data is handled
# Data older than watermark is dropped
# Data within watermark is processed and may update previous results

df = df \
    .withWatermark("event_time", "2 hours") \
    .groupBy(
        window(col("event_time"), "1 hour"),
        col("category")
    ) \
    .agg(count("*").alias("event_count"))

# With update mode, late data updates previous aggregations
query = df.writeStream \
    .format("delta") \
    .outputMode("update") \
    .option("checkpointLocation", "s3a://checkpoints/late-data") \
    .start()
```

### Allow Duplicates

```python
# If you can handle duplicates, use append mode
query = df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "s3a://checkpoints/append") \
    .start()
```

## Monitoring Streaming Queries

```python
def get_streaming_status(spark, query_name):
    """Get detailed streaming query status."""
    for query in spark.streams.active:
        if query.name == query_name:
            print(f"Query: {query.name}")
            print(f"Status: {query.status}")
            print(f"Is Active: {query.isActive}")
            print(f"Is Trigger Active: {query.lastProgress}")

            if query.lastProgress:
                progress = query.lastProgress
                print(f"Batch ID: {progress.get('batchId')}")
                print(f"Input Rate: {progress.get('numInputRows') / progress.get('batchDuration'):.0f} rows/sec")

            return query

    return None

# Streaming metrics
def get_streaming_metrics(app_id):
    """Get streaming metrics from Prometheus."""
    import requests

    metrics = {
        "lag": f'sum(kafka_consumer_lag{{app_id="{app_id}"}})',
        "processing_rate": f'rate(spark_streaming_total_input_rows{{app_id="{app_id}"}}[1m])',
        "error_rate": f'rate(spark_streaming_total_input_rows{{app_id="{app_id}",status="failed"}}[1m])',
    }

    for name, query in metrics.items():
        response = requests.get(
            f"http://prometheus.observability.svc.cluster.local:9090/api/v1/query",
            params={"query": query}
        )
        print(f"{name}: {response.json()['data']['result']}")
```

## Best Practices

1. **Always use checkpoints** for recovery
2. **Set appropriate watermarks** based on data latency
3. **Monitor lag** and processing time
4. **Use idempotent sinks** for exactly-once
5. **Handle backpressure** with scaling
6. **Test failure recovery** regularly
7. **Document state TTL** and cleanup policies

## Related

- [Streaming Tutorial](../../tutorials/workflows/streaming.md)
- [State Management](./state-management.md)
- [Monitoring Setup](../../guides/monitoring/setup-guide.md)
