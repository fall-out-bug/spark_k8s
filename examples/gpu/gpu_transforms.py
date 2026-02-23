#!/usr/bin/env python3
"""GPU-accelerated transformations for Spark."""

import time

from pyspark.sql.functions import col, count, avg, sum as spark_sum


def gpu_aggregations(df) -> None:
    """
    Demonstrate GPU-accelerated aggregations.

    Aggregations are significantly faster on GPU.
    """
    print("\n3. GPU-Accelerated Aggregations")

    start = time.time()
    result = df.groupBy("product_id").agg(
        count("*").alias("transaction_count"),
        avg("price").alias("avg_price"),
        spark_sum("price").alias("total_revenue")
    ).orderBy("total_revenue", ascending=False)

    result.show(10, truncate=False)
    agg_time = time.time() - start
    print(f"   Aggregation time: {agg_time:.2f}s")


def gpu_joins(df) -> None:
    """
    Demonstrate GPU-accelerated joins.

    Joins are heavily optimized on GPU.
    """
    print("\n4. GPU-Accelerated Joins")

    spark = df.sql_ctx.sparkSession
    product_data = spark.range(1000).selectExpr(
        "id as product_id",
        "concat('Product ', id) as product_name",
        "cast(id % 10 as int) as category_id"
    )

    start = time.time()
    joined = df.join(product_data, "product_id", "inner")

    result = joined.groupBy("category_id").agg(
        count("*").alias("sales_count"),
        spark_sum("price").alias("category_revenue")
    )

    result.show(10, truncate=False)
    join_time = time.time() - start
    print(f"   Join time: {join_time:.2f}s")


def gpu_filter_operations(df) -> None:
    """Demonstrate GPU-accelerated filter operations."""
    print("\n5. GPU-Accelerated Filter Operations")

    start = time.time()
    filtered = df.filter(
        (col("price") > 50) &
        (col("quantity") >= 2) &
        (col("price") * col("quantity") > 100)
    )

    count = filtered.count()
    filter_time = time.time() - start
    print(f"   Filtered {count:,} rows in {filter_time:.2f}s")


def gpu_sort_operations(df) -> None:
    """Demonstrate GPU-accelerated sort operations."""
    print("\n6. GPU-Accelerated Sort Operations")

    start = time.time()
    sorted_df = df.orderBy(col("price").desc(), col("event_time").asc())
    sorted_df.show(10, truncate=False)
    sort_time = time.time() - start
    print(f"   Sort time: {sort_time:.2f}s")
