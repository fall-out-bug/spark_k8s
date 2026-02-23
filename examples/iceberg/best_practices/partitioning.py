#!/usr/bin/env python3
"""Iceberg partitioning examples demonstrating different strategies."""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_timestamp


def create_spark_session():
    """Create Spark session with Iceberg config."""
    return SparkSession.builder \
        .appName("Iceberg Partitioning Examples") \
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.iceberg",
                "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.iceberg.type", "hadoop") \
        .config("spark.sql.catalog.iceberg.warehouse", "s3a://warehouse/iceberg") \
        .getOrCreate()


def identity_partitioning(spark):
    """
    Identity partitioning: Direct mapping of column values to partitions.

    Best for: Low cardinality columns with exact match filters.
    """
    print("\n=== Identity Partitioning ===")

    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.examples.events_identity (
            event_id BIGINT,
            event_type STRING,
            event_time TIMESTAMP,
            payload STRING
        ) USING iceberg
        PARTITIONED BY (identity(event_type))
    """)

    # Insert sample data
    data = [(i, f"type_{i % 3}") for i in range(100)]
    df = spark.createDataFrame(data, ["event_id", "event_type"]) \
        .withColumn("event_time", current_timestamp()) \
        .withColumn("payload", lit("sample data"))

    df.writeTo("iceberg.examples.events_identity").append()

    # Show partitions
    spark.sql("SELECT * FROM iceberg.examples.events_identity.partitions").show()


def bucket_partitioning(spark):
    """
    Bucket partitioning: Hash-based distribution into N buckets.

    Best for: High cardinality columns with even distribution needed.
    """
    print("\n=== Bucket Partitioning ===")

    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.examples.user_events_bucket (
            user_id BIGINT,
            event_time TIMESTAMP,
            action STRING
        ) USING iceberg
        PARTITIONED BY (bucket(16, user_id))
    """)

    # Insert sample data
    data = [(i, f"action_{i % 10}") for i in range(1000)]
    df = spark.createDataFrame(data, ["user_id", "action"]) \
        .withColumn("event_time", current_timestamp())

    df.writeTo("iceberg.examples.user_events_bucket").append()

    # Show partition distribution
    spark.sql("""
        SELECT partition, record_count, file_count
        FROM iceberg.examples.user_events_bucket.partitions
        ORDER BY partition
    """).show()


def day_partitioning(spark):
    """
    Day partitioning: Partition by date from timestamp.

    Best for: Time-series data with date-based queries.
    """
    print("\n=== Day Partitioning ===")

    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.examples.logs_daily (
            log_id BIGINT,
            log_time TIMESTAMP,
            level STRING,
            message STRING
        ) USING iceberg
        PARTITIONED BY (days(log_time))
    """)

    # Insert sample data
    data = [(i, f"level_{i % 5}", f"message {i}") for i in range(100)]
    df = spark.createDataFrame(data, ["log_id", "level", "message"]) \
        .withColumn("log_time", current_timestamp())

    df.writeTo("iceberg.examples.logs_daily").append()

    # Show partitions
    spark.sql("SELECT * FROM iceberg.examples.logs_daily.partitions").show()


def truncate_partitioning(spark):
    """
    Truncate partitioning: Partition by truncated string value.

    Best for: Hierarchical data (e.g., URLs, paths).
    """
    print("\n=== Truncate Partitioning ===")

    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.examples.urls_truncate (
            url STRING,
            visit_time TIMESTAMP,
            visitor_id STRING
        ) USING iceberg
        PARTITIONED BY (truncate(1, url))
    """)

    # Insert sample data
    data = [
        ("/api/users", "user1"),
        ("/api/orders", "user2"),
        ("/api/products", "user3"),
        ("/web/page", "user4"),
    ]
    df = spark.createDataFrame(data, ["url", "visitor_id"]) \
        .withColumn("visit_time", current_timestamp())

    df.writeTo("iceberg.examples.urls_truncate").append()

    # Show partitions
    spark.sql("SELECT * FROM iceberg.examples.urls_truncate.partitions").show()


def combined_partitioning(spark):
    """
    Combined partitioning: Multiple partition columns.

    Best for: Complex query patterns with multiple filter dimensions.
    """
    print("\n=== Combined Partitioning ===")

    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.examples.events_combined (
            event_id BIGINT,
            event_time TIMESTAMP,
            event_type STRING,
            region STRING,
            payload STRING
        ) USING iceberg
        PARTITIONED BY (days(event_time), bucket(8, event_type), identity(region))
    """)

    # Insert sample data
    data = [(i, f"type_{i % 4}", f"region_{i % 3}") for i in range(200)]
    df = spark.createDataFrame(data, ["event_id", "event_type", "region"]) \
        .withColumn("event_time", current_timestamp()) \
        .withColumn("payload", lit("data"))

    df.writeTo("iceberg.examples.events_combined").append()

    # Show partition structure
    spark.sql("SELECT * FROM iceberg.examples.events_combined.partitions LIMIT 10").show()


def main():
    """Run all partitioning examples."""
    spark = create_spark_session()
    print(f"Spark Version: {spark.version}")

    spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.examples")

    identity_partitioning(spark)
    bucket_partitioning(spark)
    day_partitioning(spark)
    truncate_partitioning(spark)
    combined_partitioning(spark)

    print("\n=== Partitioning Summary ===")
    spark.sql("""
        SELECT
            'events_identity' as table,
            count(*) as partitions
        FROM iceberg.examples.events_identity.partitions
        UNION ALL
        SELECT 'user_events_bucket', count(*) FROM iceberg.examples.user_events_bucket.partitions
        UNION ALL
        SELECT 'logs_daily', count(*) FROM iceberg.examples.logs_daily.partitions
    """).show()

    spark.stop()


if __name__ == "__main__":
    main()
