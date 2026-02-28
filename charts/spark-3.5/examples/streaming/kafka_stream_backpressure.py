"""
Kafka Streaming with Backpressure Example
=========================================

Demonstrates robust Kafka streaming with:
- Backpressure (prevent consumer overload)
- Rate limiting
- Error handling
- Graceful shutdown
- Monitoring-friendly metrics

Configuration:
    Set KAFKA_BOOTSTRAP_SERVERS environment variable or use default.

Run:
    spark-submit --master spark://master:7077 kafka_stream_backpressure.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_json, struct, window, count
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, DoubleType, LongType
import os
import signal
import sys

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
INPUT_TOPIC = os.getenv("KAFKA_INPUT_TOPIC", "spark-input")
OUTPUT_TOPIC = os.getenv("KAFKA_OUTPUT_TOPIC", "spark-output")
CONSUMER_GROUP = os.getenv("KAFKA_CONSUMER_GROUP", "spark-streaming-consumer")

# Backpressure configuration
MAX_OFFSETS_PER_TRIGGER = int(os.getenv("MAX_OFFSETS_PER_TRIGGER", "1000"))
MAX_RATE_PER_PARTITION = int(os.getenv("MAX_RATE_PER_PARTITION", "2000"))


def create_spark_session():
    """Create SparkSession with backpressure and streaming optimization."""
    return (
        SparkSession.builder.appName("KafkaBackpressureStreaming")
        .master("spark://airflow-sc-standalone-master:7077")
        # === BACKPRESSURE CONFIGURATION ===
        # Enable backpressure - automatically adjusts ingestion rate
        .config("spark.streaming.backpressure.enabled", "true")
        # Initial rate when backpressure starts (per partition)
        .config("spark.streaming.backpressure.initialRate", "500")
        # Maximum rate per partition (hard limit)
        .config("spark.streaming.kafka.maxRatePerPartition", str(MAX_RATE_PER_PARTITION))
        # For Structured Streaming - max offsets per trigger
        # This is the key setting for batch-style processing
        .config("spark.sql.streaming.maxOffsetsPerTrigger", str(MAX_OFFSETS_PER_TRIGGER))
        # === CHECKPOINTING ===
        .config("spark.sql.streaming.checkpointLocation", "/tmp/spark-checkpoints/kafka-backpressure")
        .config("spark.sql.streaming.forceDeleteTempCheckpointLocation", "true")
        # === FAULT TOLERANCE ===
        .config("spark.streaming.stopGracefullyOnShutdown", "true")
        # === PERFORMANCE ===
        .config("spark.sql.shuffle.partitions", "20")
        .config(
            "spark.sql.streaming.stateStore.providerClass",
            "org.apache.spark.sql.execution.streaming.state.RocksDBStateStoreProvider",
        )
        # === MEMORY ===
        .config("spark.memory.fraction", "0.4")
        .config("spark.memory.storageFraction", "0.3")
        # === KAFKA SPECIFIC ===
        .config("spark.kafka.pollTimeoutMs", "512")
        .config("spark.kafka.maxPartitionBytes", "134217728")  # 128MB
        .config("spark.kafka.fetchMaxBytes", "52428800")  # 50MB
        .getOrCreate()
    )


def define_event_schema():
    """Define schema for Kafka message parsing."""
    return StructType(
        [
            StructField("event_id", StringType(), True),
            StructField("event_time", TimestampType(), True),
            StructField("event_type", StringType(), True),
            StructField("user_id", StringType(), True),
            StructField("session_id", StringType(), True),
            StructField("value", DoubleType(), True),
            StructField(
                "metadata",
                StructType([StructField("source", StringType(), True), StructField("version", StringType(), True)]),
                True,
            ),
        ]
    )


def read_from_kafka(spark, schema):
    """
    Read from Kafka with backpressure protection.

    Key settings:
    - maxOffsetsPerTrigger: Limits batch size
    - startingOffsets: "latest" for production, "earliest" for testing
    - failOnDataLoss: False to handle missing data gracefully
    """
    return (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS)
        .option("subscribe", INPUT_TOPIC)
        # Backpressure: limit data per batch
        .option("maxOffsetsPerTrigger", str(MAX_OFFSETS_PER_TRIGGER))
        # Start from latest (change to "earliest" for testing)
        .option("startingOffsets", "latest")
        # Don't fail if data is lost (Kafka retention < checkpoint age)
        .option("failOnDataLoss", "false")
        # Consumer configuration
        .option("kafka.group.id", CONSUMER_GROUP)
        .option("kafka.auto.offset.reset", "latest")
        .option("kafka.enable.auto.commit", "false")  # Spark manages commits
        # Performance
        .option("kafka.fetch.min.bytes", "1024")
        .option("kafka.fetch.max.wait.ms", "500")
        .load()
    )


def process_stream(raw_df, schema):
    """
    Process Kafka stream with transformations.

    Demonstrates:
    - JSON parsing
    - Filtering
    - Aggregations
    - Error handling
    """
    # Parse JSON from Kafka value
    parsed_df = raw_df.select(
        col("key").cast("string").alias("kafka_key"),
        col("offset").alias("kafka_offset"),
        col("partition").alias("kafka_partition"),
        col("timestamp").alias("kafka_timestamp"),
        from_json(col("value").cast("string"), schema).alias("data"),
    )

    # Flatten and filter
    processed_df = parsed_df.select(
        col("kafka_key"),
        col("kafka_offset"),
        col("kafka_partition"),
        col("kafka_timestamp"),
        col("data.event_id"),
        col("data.event_time"),
        col("data.event_type"),
        col("data.user_id"),
        col("data.session_id"),
        col("data.value"),
        col("data.metadata.source").alias("source"),
        col("data.metadata.version").alias("version"),
    ).filter(
        # Filter out null events
        col("event_id").isNotNull() & col("event_time").isNotNull() & col("value").isNotNull()
    )

    return processed_df


def aggregate_stream(df):
    """
    Perform windowed aggregations on the stream.

    Uses watermark to handle late-arriving data.
    """
    return (
        df.withWatermark("event_time", "30 seconds")
        .groupBy(window(col("event_time"), "1 minute"), col("event_type"), col("source"))
        .agg(
            count("*").alias("event_count"),
            # Add more aggregations as needed
        )
    )


def write_to_kafka(df):
    """Write processed data back to Kafka."""
    # Prepare output format
    output_df = df.select(
        # Use event_type as key for partitioning
        col("event_type").cast("string").alias("key"),
        # Serialize value as JSON
        to_json(struct(col("window"), col("event_type"), col("source"), col("event_count"))).alias("value"),
    )

    return (
        output_df.writeStream.format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS)
        .option("topic", OUTPUT_TOPIC)
        .option("checkpointLocation", "/tmp/spark-checkpoints/kafka-backpressure-output")
        .outputMode("update")
        .trigger(processingTime="10 seconds")
        .start()
    )


def write_to_console(df):
    """Write to console for debugging."""
    return (
        df.writeStream.outputMode("update")
        .format("console")
        .option("truncate", False)
        .option("numRows", 20)
        .trigger(processingTime="10 seconds")
        .start()
    )


def setup_graceful_shutdown(spark):
    """Setup signal handler for graceful shutdown."""

    def signal_handler(sig, frame):
        print("\n\nReceived shutdown signal. Stopping gracefully...")
        for query in spark.streams.active:
            print(f"Stopping: {query.name}")
            query.stop()
        spark.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)


def main():
    """Run Kafka streaming with backpressure."""
    print("\n" + "=" * 60)
    print("KAFKA STREAMING WITH BACKPRESSURE")
    print("=" * 60)

    print(f"Kafka servers: {KAFKA_BOOTSTRAP_SERVERS}")
    print(f"Input topic: {INPUT_TOPIC}")
    print(f"Output topic: {OUTPUT_TOPIC}")
    print(f"Consumer group: {CONSUMER_GROUP}")
    print(f"Max offsets per trigger: {MAX_OFFSETS_PER_TRIGGER}")
    print(f"Max rate per partition: {MAX_RATE_PER_PARTITION}")

    # Create Spark session
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    # Setup graceful shutdown
    setup_graceful_shutdown(spark)

    print(f"\nSpark version: {spark.version}")

    try:
        # Define schema
        schema = define_event_schema()

        # Read from Kafka
        print("\nStarting Kafka consumer with backpressure...")
        raw_df = read_from_kafka(spark, schema)

        # Process stream
        processed_df = process_stream(raw_df, schema)

        # Aggregate (optional)
        # aggregated_df = aggregate_stream(processed_df)

        # Write to console (for debugging)
        print("Starting console output...")
        query = write_to_console(processed_df)

        # Alternatively, write to Kafka:
        # query = write_to_kafka(aggregated_df)

        print("\nStreaming started. Press Ctrl+C to stop...")
        print(f"Active queries: {len(spark.streams.active)}")

        # Wait for termination
        query.awaitTermination()

    except Exception as e:
        print(f"\nError: {e}")
        raise
    finally:
        print("\nStopping Spark session...")
        spark.stop()


if __name__ == "__main__":
    main()
