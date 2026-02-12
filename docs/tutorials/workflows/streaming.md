# Streaming Workflow Tutorial

Learn to build real-time streaming pipelines with Structured Streaming on Kubernetes.

## Overview

You will learn:
1. Setting up streaming sources and sinks
2. Handling late data and watermarks
3. State management and checkpoints
4. Monitoring streaming queries

## Prerequisites

- Kafka cluster configured
- Understanding of Structured Streaming concepts

## Tutorial: Real-time Analytics Pipeline

### Step 1: Create Streaming Application

```python
# streaming_jobs/realtime_analytics.py
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from delta.tables import DeltaTable
import os

def create_spark_session():
    """Create Spark session for streaming."""
    return SparkSession.builder \
        .appName("realtime-analytics") \
        .config("spark.sql.streaming.schemaInference", "true") \
        .config("spark.sql.streaming.checkpointLocation", "s3a://checkpoints/analytics") \
        .config("spark.sql.shuffle.partitions", "200") \
        .getOrCreate()

def define_schema():
    """Define schema for incoming events."""
    return StructType([
        StructField("event_id", StringType(), False),
        StructField("user_id", StringType(), False),
        StructField("event_type", StringType(), False),
        StructField("page_url", StringType(), True),
        StructField("timestamp", TimestampType(), False),
        StructField("properties", MapType(StringType(), StringType()), True)
    ])

def read_from_kafka(spark):
    """Read events from Kafka."""
    return spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", os.getenv("KAFKA_BROKERS")) \
        .option("subscribe", "web-events") \
        .option("startingOffsets", "latest") \
        .option("failOnDataLoss", "false") \
        .load() \
        .select(
            from_json(col("value").cast("string"), define_schema()).alias("data")
        ) \
        .select("data.*")

def process_events(events_df):
    """Apply transformations to events."""
    return events_df \
        .withWatermark("timestamp", "10 minutes") \
        .groupBy(
            window(col("timestamp"), "5 minutes"),
            col("event_type")
        ) \
        .agg(
            count("*").alias("event_count"),
            countDistinct("user_id").alias("unique_users"),
            approx_count_distinct("event_id").alias("approx_unique")
        ) \
        .withColumn("processing_time", current_timestamp())

def write_to_s3(stream_df, output_path):
    """Write streaming results to S3."""
    query = stream_df.writeStream \
        .format("delta") \
        .outputMode("append") \
        .partitionBy("event_type") \
        .option("checkpointLocation", "s3a://checkpoints/analytics/s3-sink") \
        .option("mergeSchema", "true") \
        .option("compact", "true") \
        .trigger(processingTime='30 seconds') \
        .start(output_path)

    return query

def write_to_prometheus(stream_df):
    """Write metrics to Prometheus for monitoring."""
    def foreach_batch(df, batch_id):
        # Calculate aggregate metrics
        metrics = df.agg(
            sum("event_count").alias("total_events"),
            sum("unique_users").alias("total_users")
        ).collect()[0]

        # Push to Prometheus Pushgateway
        import requests

        prometheus_url = os.getenv("PROMETHEUS_PUSHGATEWAY")
        job_name = "spark-streaming"

        requests.post(
            f"{prometheus_url}/metrics/job/{job_name}",
            data=f"""
# HELP spark_streaming_total_events Total events processed
# TYPE spark_streaming_total_events counter
spark_streaming_total_events {metrics['total_events']}

# HELP spark_streaming_unique_users Unique users in window
# TYPE spark_streaming_unique_users gauge
spark_streaming_unique_users {metrics['total_users']}
            """.strip()
        )

    query = stream_df.writeStream \
        .foreachBatch(foreach_batch) \
        .trigger(processingTime='30 seconds') \
        .start()

    return query

def setup_monitoring(spark, query):
    """Setup query monitoring and alerting."""
    def send_alert(message):
        """Send alert on failure."""
        import requests
        webhook_url = os.getenv("SLACK_WEBHOOK_URL")
        if webhook_url:
            requests.post(webhook_url, json={"text": message})

    # Add listener for query progress
    class StreamingListener:
        def onQueryProgress(self, queryProgress):
            print(f"Batch: {queryProgress.batchId()}, "
                  f"Input: {queryProgress.numInputRows}, "
                  f"Rows: {queryProgress.progress.rows}")

        def onQueryTerminated(self, queryTerminated):
            if queryTerminated.exception:
                send_alert(f"❌ Streaming query failed: {queryTerminated.exception}")

    spark.sparkContext.addSparkListener(StreamingListener())

def main():
    """Main streaming pipeline."""
    import signal
    import sys

    spark = create_spark_session()

    # Graceful shutdown
    def signal_handler(sig, frame):
        print("Shutting down gracefully...")
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        # Read from Kafka
        events_df = read_from_kafka(spark)
        print("Reading from Kafka...")

        # Process events
        processed_df = process_events(events_df)
        print("Processing events...")

        # Write to S3
        output_path = "s3a://analytics/events/aggregated"
        s3_query = write_to_s3(processed_df, output_path)
        print(f"Writing to {output_path}")

        # Write metrics to Prometheus
        prom_query = write_to_prometheus(processed_df)
        print("Writing metrics to Prometheus")

        # Setup monitoring
        setup_monitoring(spark, s3_query)

        # Await termination
        s3_query.awaitTermination()
        prom_query.awaitTermination()

    except Exception as e:
        print(f"Streaming failed: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

### Step 2: Deploy Streaming Job

```yaml
# manifests/streaming-job.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: realtime-analytics
  namespace: spark-streaming
spec:
  type: Python
  mode: cluster
  image: your-registry/spark-streaming:latest
  mainApplicationFile: local:///app/streaming_jobs/realtime_analytics.py
  sparkVersion: "3.5.0"
  restartPolicy:
    type: Always
    onSubmissionFailureRetries: 10
    onSubmissionFailureRetryInterval: 60

  driver:
    cores: 2
    memory: "4g"
    memoryOverhead: "1g"
    serviceAccount: spark
    env:
      - name: KAFKA_BROKERS
        value: "kafka.kafka.svc.cluster.local:9092"
      - name: PROMETHEUS_PUSHGATEWAY
        value: "http://pushgateway.observability.svc.cluster.local:9091"
      - name: SLACK_WEBHOOK_URL
        valueFrom:
          secretKeyRef:
            name: slack-webhook
            key: url

  executor:
    cores: 2
    instances: 5
    memory: "4g"
    memoryOverhead: "1g"

  deps:
    pyPackages:
      - requests
      - delta-spark==2.4.0
```

### Step 3: Handle Late Data

```python
def handle_late_data(stream_df):
    """Handle late-arriving data with watermarks."""
    return stream_df \
        .withWatermark("timestamp", "10 minutes") \
        .groupBy(
            window(col("timestamp"), "5 minutes", "5 minutes", "5 minutes"),
            col("event_type")
        ) \
        .agg(count("*").alias("event_count"))

# Late data will be placed in the appropriate window
# Windows older than watermark are dropped
```

### Step 4: State Management

```python
def write_with_state_store(stream_df, output_path):
    """Use state store for deduplication."""
    from pyspark.sql.streaming import StreamingQuery

    def foreach_batch(df, batch_id):
        # Use DeltaTable for upserts
        delta_table = DeltaTable.forPath(spark, output_path)

        delta_table.alias("target") \
            .merge(
                df.alias("source"),
                "target.event_id = source.event_id"
            ) \
            .whenMatchedUpdateAll() \
            .whenNotMatchedInsertAll() \
            .execute()

    query = stream_df.writeStream \
        .foreachBatch(foreach_batch) \
        .option("checkpointLocation", "s3a://checkpoints/analytics/state") \
        .trigger(processingTime='30 seconds') \
        .start()

    return query
```

## Streaming Query Management

### Monitoring Queries

```python
# Get all active queries
for query in spark.streams.active:
    print(f"Query: {query.name}")
    print(f"Status: {query.status}")
    print(f"Progress: {query.lastProgress}")
    print(f"Recent progress: {query.recentProgress}")
```

### Recovering from Checkpoints

```python
# Restart from checkpoint
stream_df.writeStream \
    .format("delta") \
    .option("checkpointLocation", "s3a://checkpoints/analytics/s3-sink") \
    .start("s3a://analytics/events/aggregated")

# Spark will automatically recover from checkpoint
```

## Best Practices

### 1. Checkpoint Sizing

- Keep checkpoint size < 1GB
- Partition state by key
- Compact periodically

### 2. Backpressure Handling

```python
# Configure for backpressure
config = {
    "spark.streaming.backpressure.enabled": "true",
    "spark.streaming.backpressure.initialRate": "100",
    "spark.streaming.backpressure.rateController": "pid"
}
```

### 3. Exactly-Once Semantics

```python
# Use idempotent sinks
stream_df.writeStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", brokers) \
    .option("topic", "output") \
    .option("checkpointLocation", checkpoint) \
    .outputMode("update") \
    .trigger(processingTime='1 minute') \
    .start()
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Checkpoint too large | Reduce state, increase micro-batches |
| High latency | Check skew, add partitions |
| Out of memory | Increase executor memory, reduce batch size |
| Lost data | Verify checkpoint storage, check watermark |

## Next Steps

- [ ] Add streaming SQL queries
- [ ] Implement auto-scaling based on lag
- [ ] Set up multi-region streaming
- [ ] Create stream testing framework

## Related

- [ETL Pipeline](./etl-pipeline.md)
- [Kafka Integration Guide](../../docs/guides/kafka-setup.md)
