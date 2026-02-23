#!/usr/bin/env python3
"""
Kafka → Iceberg Structured Streaming Example

Reads JSON events from Kafka, transforms, writes to Iceberg with exactly-once semantics.
Run: spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.0,org.apache.iceberg:iceberg-spark-runtime-3.5_2.13:1.5.0 kafka_to_iceberg.py

For Spark 3.5: use _2.12:3.5.0 and iceberg-spark-runtime-3.5_2.12:1.5.0
"""

import os
import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, current_timestamp
from pyspark.sql.types import StructType, StructField, StringType, LongType, DoubleType

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "events")
CHECKPOINT = os.getenv("CHECKPOINT_LOCATION", "s3a://checkpoints/kafka-iceberg")
WAREHOUSE = os.getenv("ICEBERG_WAREHOUSE", "s3a://warehouse/iceberg")
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://minio:9000")


def main() -> None:
    spark = (
        SparkSession.builder.appName("kafka-to-iceberg")
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.iceberg.type", "hadoop")
        .config("spark.sql.catalog.iceberg.warehouse", WAREHOUSE)
        .config("spark.hadoop.fs.s3a.endpoint", S3_ENDPOINT)
        .getOrCreate()
    )

    schema = StructType(
        [
            StructField("id", StringType(), False),
            StructField("user_id", StringType(), True),
            StructField("amount", DoubleType(), True),
            StructField("event_ts", LongType(), True),
        ]
    )

    stream = (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP)
        .option("subscribe", KAFKA_TOPIC)
        .option("startingOffsets", "earliest")
        .option("failOnDataLoss", "false")
        .load()
        .select(from_json(col("value").cast("string"), schema).alias("data"))
        .select("data.*")
        .withColumn("processing_time", current_timestamp())
    )

    query = (
        stream.writeStream.outputMode("append")
        .format("iceberg")
        .option("path", "iceberg.db_streaming.events")
        .option("checkpointLocation", CHECKPOINT)
        .trigger(processingTime="10 seconds")
        .start()
    )

    query.awaitTermination(60)
    query.stop()


if __name__ == "__main__":
    main()
