#!/usr/bin/env python3
"""Iceberg setup and basic operations."""

from pyspark.sql import SparkSession


def create_spark_session():
    """Create Spark session with Iceberg configuration."""
    return SparkSession.builder \
        .appName("Iceberg Examples") \
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.spark_catalog",
                "org.apache.iceberg.spark.SparkSessionCatalog") \
        .config("spark.sql.catalog.spark_catalog.type", "hadoop") \
        .config("spark.sql.catalog.iceberg",
                "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.iceberg.type", "hadoop") \
        .config("spark.sql.catalog.iceberg.warehouse",
                "s3a://warehouse/iceberg") \
        .getOrCreate()


def setup_database(spark):
    """Create database and setup environment."""
    spark.sql("CREATE DATABASE IF NOT EXISTS iceberg.db_examples")
    spark.sql("USE iceberg.db_examples")


def create_iceberg_table(spark):
    """Create an Iceberg table with initial schema."""
    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.db_examples.users (
            id BIGINT,
            name STRING,
            email STRING,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        ) USING iceberg
        PARTITIONED BY (days(created_at))
    """)


def insert_initial_data(spark):
    """Insert initial data into the table."""
    from pyspark.sql.functions import current_timestamp, lit

    data = [
        (1, "Alice", "alice@example.com"),
        (2, "Bob", "bob@example.com"),
        (3, "Charlie", "charlie@example.com"),
    ]

    df = spark.createDataFrame(data, ["id", "name", "email"])
    df = df.withColumn("created_at", current_timestamp())
    df = df.withColumn("updated_at", current_timestamp())

    df.writeTo("iceberg.db_examples.users").append()
