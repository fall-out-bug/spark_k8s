#!/usr/bin/env python3
"""
GPU Operations Example for Spark with RAPIDS

This notebook demonstrates GPU-accelerated operations using Spark RAPIDS plugin.
Run this in Jupyter with GPU-enabled Spark cluster.

Prerequisites:
- GPU-enabled Spark cluster (use presets/gpu-values.yaml)
- RAPIDS plugin installed
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, sum as spark_sum
import time

# Initialize Spark Session with GPU support
spark = SparkSession.builder \
    .appName("GPU Operations Example") \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .config("spark.rapids.sql.fallback.enabled", "true") \
    .getOrCreate()

print("=" * 80)
print("Spark GPU Operations Example")
print("=" * 80)
print(f"\nSpark Version: {spark.version}")
print(f"RAPIDS Plugin: Enabled")

# Check GPU availability
try:
    gpu_count = spark._jvm.org.apache.spark.TaskContext.get().getResourceAmount("gpu")
    print(f"GPUs Available: {gpu_count}")
except:
    print("GPU status: Unable to detect")

print("\n" + "=" * 80)


def create_sample_data(size_million=100):
    """
    Create sample data for GPU operations.

    Args:
        size_million: Number of rows in millions

    Returns:
        DataFrame with sample data
    """
    print(f"\n1. Creating sample dataset ({size_million}M rows)...")

    # Create large DataFrame
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


def gpu_parquet_operations(df):
    """
    Demonstrate GPU-accelerated Parquet operations.

    Parquet read/write is heavily optimized in RAPIDS.
    """
    print("\n2. GPU-Accelerated Parquet Operations")

    # Write to Parquet (GPU-accelerated)
    start = time.time()
    df.write.mode("overwrite").parquet("/tmp/gpu_example.parquet")
    write_time = time.time() - start
    print(f"   Write time: {write_time:.2f}s")

    # Read from Parquet (GPU-accelerated)
    start = time.time()
    df_read = spark.read.parquet("/tmp/gpu_example.parquet")
    read_time = time.time() - start
    print(f"   Read time: {read_time:.2f}s")

    return df_read


def gpu_aggregations(df):
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


def gpu_joins(df):
    """
    Demonstrate GPU-accelerated joins.

    Joins are heavily optimized on GPU.
    """
    print("\n4. GPU-Accelerated Joins")

    # Create product catalog
    product_data = spark.range(1000).selectExpr(
        "id as product_id",
        "concat('Product ', id) as product_name",
        "cast(id % 10 as int) as category_id"
    )

    # Join with transaction data
    start = time.time()
    joined = df.join(product_data, "product_id", "inner")

    result = joined.groupBy("category_id").agg(
        count("*").alias("sales_count"),
        spark_sum("price").alias("category_revenue")
    )

    result.show(10, truncate=False)
    join_time = time.time() - start
    print(f"   Join time: {join_time:.2f}s")


def gpu_filter_operations(df):
    """
    Demonstrate GPU-accelerated filter operations.
    """
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


def gpu_sort_operations(df):
    """
    Demonstrate GPU-accelerated sort operations.
    """
    print("\n6. GPU-Accelerated Sort Operations")

    start = time.time()
    sorted_df = df.orderBy(col("price").desc(), col("event_time").asc())
    sorted_df.show(10, truncate=False)
    sort_time = time.time() - start
    print(f"   Sort time: {sort_time:.2f}s")


def explain_gpu_plan(df):
    """
    Show query execution plan with GPU operators.
    """
    print("\n7. GPU Execution Plan")

    df_explained = df.groupBy("product_id").agg(
        avg("price").alias("avg_price")
    )

    # Explain plan - look for Gpu* operators
    df_explained.explain(extended=True)


def benchmark_comparison(df):
    """
    Compare GPU vs CPU performance (if fallback is enabled).
    """
    print("\n8. Performance Comparison")

    # GPU execution
    spark.conf.set("spark.rapids.sql.enabled", "true")
    start = time.time()
    df.groupBy("product_id").agg(avg("price")).collect()
    gpu_time = time.time() - start
    print(f"   GPU time: {gpu_time:.2f}s")

    # CPU execution (fallback)
    spark.conf.set("spark.rapids.sql.enabled", "false")
    start = time.time()
    df.groupBy("product_id").agg(avg("price")).collect()
    cpu_time = time.time() - start
    print(f"   CPU time: {cpu_time:.2f}s")

    if cpu_time > 0:
        speedup = cpu_time / gpu_time
        print(f"   Speedup: {speedup:.2f}x")

    # Re-enable GPU
    spark.conf.set("spark.rapids.sql.enabled", "true")


def main():
    """Main execution flow."""
    print("\n" + "=" * 80)
    print("Starting GPU Operations Demo")
    print("=" * 80)

    # Create sample data
    df = create_sample_data(size_million=10)

    # Run GPU-accelerated operations
    df = gpu_parquet_operations(df)
    gpu_aggregations(df)
    gpu_joins(df)
    gpu_filter_operations(df)
    gpu_sort_operations(df)

    # Show execution plan
    explain_gpu_plan(df)

    # Performance benchmark
    benchmark_comparison(df)

    print("\n" + "=" * 80)
    print("GPU Operations Demo Complete!")
    print("=" * 80)
    print("\nKey Takeaways:")
    print("- Parquet I/O is GPU-accelerated")
    print("- Aggregations run faster on GPU")
    print("- Joins benefit from GPU acceleration")
    print("- Sort operations are optimized on GPU")
    print("- Look for 'Gpu*' operators in execution plan")
    print("=" * 80)


if __name__ == "__main__":
    main()
