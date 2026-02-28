"""
File-Based Structured Streaming Example
========================================

This example demonstrates basic streaming concepts without requiring Kafka.
Uses file-based source which is perfect for testing and development.

Features:
- Rate source (built-in, no external dependencies)
- File sink for output
- Checkpointing for fault tolerance
- Basic aggregations
- Memory sink for immediate queries

Use case: Development, testing, CI/CD pipelines

Run:
    spark-submit --master spark://master:7077 file_stream_basic.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, window, count, avg, approx_count_distinct
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, DoubleType
import time
import os


def create_spark_session():
    """Create SparkSession with streaming configuration."""
    return (
        SparkSession.builder.appName("FileStreamBasic")
        .master("spark://airflow-sc-standalone-master:7077")
        # Checkpointing for exactly-once semantics
        .config("spark.sql.streaming.checkpointLocation", "/tmp/spark-checkpoints/file-stream")
        # Streaming optimizations
        .config("spark.sql.shuffle.partitions", "10")
        .config("spark.sql.streaming.forceDeleteTempCheckpointLocation", "true")
        # Memory management
        .config("spark.memory.fraction", "0.4")
        .config("spark.memory.storageFraction", "0.3")
        .getOrCreate()
    )


def rate_source_example(spark):
    """
    Example 1: Rate source (built-in)

    The rate source generates data at a specified rate.
    Perfect for testing without external dependencies.
    """
    print("=" * 60)
    print("Example 1: Rate Source Streaming")
    print("=" * 60)

    # Create rate source - generates rows with timestamp and value
    rate_df = (
        spark.readStream.format("rate")
        .option("rowsPerSecond", 10)
        .option("rampUpTime", "5s")
        .option("numPartitions", 2)
        .load()
    )

    # Add computed columns
    enriched_df = rate_df.select(
        col("timestamp"), col("value"), (col("value") % 100).alias("group_id"), (col("value") * 1.5).alias("metric")
    )

    # Write to console for visualization
    query = (
        enriched_df.writeStream.outputMode("append")
        .format("console")
        .option("truncate", False)
        .option("numRows", 10)
        .trigger(processingTime="5 seconds")
        .start()
    )

    return query


def file_source_example(spark, input_path="/tmp/stream-input"):
    """
    Example 2: File-based source

    Monitors a directory for new JSON files.
    Useful for log processing, data ingestion.
    """
    print("=" * 60)
    print("Example 2: File Source Streaming")
    print("=" * 60)

    # Create input directory
    os.makedirs(input_path, exist_ok=True)

    # Define schema for JSON files
    schema = StructType(
        [
            StructField("event_time", TimestampType(), True),
            StructField("event_type", StringType(), True),
            StructField("user_id", StringType(), True),
            StructField("value", DoubleType(), True),
        ]
    )

    # Read from JSON files in directory
    file_df = (
        spark.readStream.format("json")
        .schema(schema)
        .option("maxFilesPerTrigger", 1)
        .option("includeExistingFiles", False)
        .load(input_path)
    )

    # Simple transformation
    transformed_df = file_df.select(
        col("event_time"), col("event_type"), col("user_id"), col("value"), col("event_type").alias("category")
    ).filter(col("value") > 0)

    # Write to memory sink for SQL queries
    query = transformed_df.writeStream.outputMode("append").format("memory").queryName("events_stream").start()

    print(f"Monitoring directory: {input_path}")
    print("Add JSON files to see them processed:")
    print(
        f'  echo \'{{"event_time": "2024-01-01T00:00:00", "event_type": "click", "user_id": "user1", "value": 100.0}}\' > {input_path}/event1.json'
    )

    return query


def windowed_aggregation_example(spark):
    """
    Example 3: Windowed aggregations with watermark

    Demonstrates event-time processing with watermarks.
    Critical for handling late-arriving data.
    """
    print("=" * 60)
    print("Example 3: Windowed Aggregation with Watermark")
    print("=" * 60)

    # Create rate source
    rate_df = spark.readStream.format("rate").option("rowsPerSecond", 100).load()

    # Simulate event data
    events_df = rate_df.select(
        col("timestamp").alias("event_time"), (col("value") % 10).alias("category"), col("value").alias("amount")
    )

    # Add watermark (handle late data up to 10 seconds)
    windowed_counts = (
        events_df.withWatermark("event_time", "10 seconds")
        .groupBy(window(col("event_time"), "5 seconds"), col("category"))
        .agg(
            count("*").alias("event_count"),
            avg("amount").alias("avg_amount"),
            approx_count_distinct("category").alias("unique_categories"),
        )
    )

    # Write to console
    query = (
        windowed_counts.writeStream.outputMode("update")
        .format("console")
        .option("truncate", False)
        .trigger(processingTime="5 seconds")
        .start()
    )

    return query


def memory_sink_query_example(spark):
    """
    Example 4: Memory sink for interactive queries

    Allows SQL queries on streaming data.
    Useful for dashboards and ad-hoc analysis.
    """
    print("=" * 60)
    print("Example 4: Memory Sink for Interactive Queries")
    print("=" * 60)

    # Create rate source
    rate_df = spark.readStream.format("rate").option("rowsPerSecond", 50).load()

    # Enrich data
    enriched_df = rate_df.select(col("timestamp"), col("value"), (col("value") % 5).alias("group"))

    # Write to memory sink
    query = enriched_df.writeStream.outputMode("append").format("memory").queryName("rate_data").start()

    # Wait for some data
    time.sleep(5)

    # Now you can run SQL queries
    print("\nRunning interactive queries:")

    # Count by group
    print("\nGroup counts:")
    spark.sql("""
        SELECT group, COUNT(*) as count 
        FROM rate_data 
        GROUP BY group 
        ORDER BY group
    """).show()

    # Recent data
    print("\nRecent 10 rows:")
    spark.sql("SELECT * FROM rate_data ORDER BY timestamp DESC LIMIT 10").show()

    return query


def main():
    """Run all streaming examples."""
    print("\n" + "=" * 60)
    print("FILE-BASED STREAMING EXAMPLES")
    print("=" * 60 + "\n")

    # Create Spark session
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    print(f"Spark version: {spark.version}")
    print(f"Application: {spark.sparkContext.appName}")

    try:
        # Run examples (comment out to run specific ones)
        queries = []

        # Example 1: Rate source
        # queries.append(rate_source_example(spark))

        # Example 2: File source
        # queries.append(file_source_example(spark))

        # Example 3: Windowed aggregation
        queries.append(windowed_aggregation_example(spark))

        # Example 4: Memory sink (uncomment to try)
        # queries.append(memory_sink_query_example(spark))

        print("\nStreaming queries started. Press Ctrl+C to stop...")
        print(f"Active queries: {len(queries)}")

        # Wait for termination
        for query in queries:
            query.awaitTermination()

    except KeyboardInterrupt:
        print("\n\nStopping streaming queries...")
        for query in spark.streams.active:
            query.stop()
            print(f"Stopped: {query.name}")
    finally:
        spark.stop()
        print("Spark session stopped.")


if __name__ == "__main__":
    main()
