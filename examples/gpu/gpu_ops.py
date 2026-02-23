"""GPU-accelerated operations for Spark RAPIDS."""

import time

from pyspark.sql import DataFrame
from pyspark.sql.functions import col, count, avg, sum as spark_sum


def gpu_parquet_operations(spark_session, df: DataFrame) -> DataFrame:
    """Demonstrate GPU-accelerated Parquet operations."""
    print("\n2. GPU-Accelerated Parquet Operations")
    start = time.time()
    df.write.mode("overwrite").parquet("/tmp/gpu_example.parquet")
    print(f"   Write time: {time.time() - start:.2f}s")
    start = time.time()
    df_read = spark_session.read.parquet("/tmp/gpu_example.parquet")
    print(f"   Read time: {time.time() - start:.2f}s")
    return df_read


def gpu_aggregations(df: DataFrame) -> None:
    """Demonstrate GPU-accelerated aggregations."""
    print("\n3. GPU-Accelerated Aggregations")
    start = time.time()
    result = df.groupBy("product_id").agg(
        count("*").alias("transaction_count"),
        avg("price").alias("avg_price"),
        spark_sum("price").alias("total_revenue"),
    ).orderBy("total_revenue", ascending=False)
    result.show(10, truncate=False)
    print(f"   Aggregation time: {time.time() - start:.2f}s")


def gpu_joins(spark_session, df: DataFrame) -> None:
    """Demonstrate GPU-accelerated joins."""
    print("\n4. GPU-Accelerated Joins")
    product_data = spark_session.range(1000).selectExpr(
        "id as product_id",
        "concat('Product ', id) as product_name",
        "cast(id % 10 as int) as category_id",
    )
    start = time.time()
    joined = df.join(product_data, "product_id", "inner")
    result = joined.groupBy("category_id").agg(
        count("*").alias("sales_count"),
        spark_sum("price").alias("category_revenue"),
    )
    result.show(10, truncate=False)
    print(f"   Join time: {time.time() - start:.2f}s")


def gpu_filter_operations(df: DataFrame) -> None:
    """Demonstrate GPU-accelerated filter operations."""
    print("\n5. GPU-Accelerated Filter Operations")
    start = time.time()
    filtered = df.filter(
        (col("price") > 50)
        & (col("quantity") >= 2)
        & (col("price") * col("quantity") > 100),
    )
    cnt = filtered.count()
    print(f"   Filtered {cnt:,} rows in {time.time() - start:.2f}s")


def gpu_sort_operations(df: DataFrame) -> None:
    """Demonstrate GPU-accelerated sort operations."""
    print("\n6. GPU-Accelerated Sort Operations")
    start = time.time()
    sorted_df = df.orderBy(col("price").desc(), col("event_time").asc())
    sorted_df.show(10, truncate=False)
    print(f"   Sort time: {time.time() - start:.2f}s")


def explain_gpu_plan(df: DataFrame) -> None:
    """Show query execution plan with GPU operators."""
    print("\n7. GPU Execution Plan")
    df_explained = df.groupBy("product_id").agg(avg("price").alias("avg_price"))
    df_explained.explain(extended=True)


def benchmark_comparison(spark_session, df: DataFrame) -> None:
    """Compare GPU vs CPU performance."""
    print("\n8. Performance Comparison")
    spark_session.conf.set("spark.rapids.sql.enabled", "true")
    start = time.time()
    df.groupBy("product_id").agg(avg("price")).collect()
    gpu_time = time.time() - start
    print(f"   GPU time: {gpu_time:.2f}s")
    spark_session.conf.set("spark.rapids.sql.enabled", "false")
    start = time.time()
    df.groupBy("product_id").agg(avg("price")).collect()
    cpu_time = time.time() - start
    print(f"   CPU time: {cpu_time:.2f}s")
    if cpu_time > 0:
        print(f"   Speedup: {cpu_time / gpu_time:.2f}x")
    spark_session.conf.set("spark.rapids.sql.enabled", "true")
