#!/usr/bin/env python3
"""GPU data generation for Spark examples."""

from pyspark.sql import SparkSession


def create_sample_data(spark: SparkSession, size_million: int = 100):
    """
    Create sample data for GPU operations.

    Args:
        spark: SparkSession to use
        size_million: Number of rows in millions

    Returns:
        DataFrame with sample data
    """
    print(f"\n1. Creating sample dataset ({size_million}M rows)...")

    data = spark.range(size_million * 1000000) \
        .selectExpr(
            "id as user_id",
            "cast(id % 1000 as int) as product_id",
            "cast(rand() * 100 as double) as price",
            "cast(rand() * 10 as int) as quantity",
            "cast(from_unixtime(cast(rand() * 1000000000 as bigint)) as timestamp) as event_time"
        )

    count = data.count()
    print(f"   Created {count:,} rows")

    return data


def create_product_catalog(spark: SparkSession):
    """Create product catalog for join examples."""
    return spark.range(1000).selectExpr(
        "id as product_id",
        "concat('Product ', id) as product_name",
        "cast(id % 10 as int) as category_id"
    )
