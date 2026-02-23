#!/usr/bin/env python3
"""GPU analysis and benchmarking for Spark."""

import time

from pyspark.sql.functions import avg


def explain_gpu_plan(df) -> None:
    """Show query execution plan with GPU operators."""
    print("\n7. GPU Execution Plan")

    df_explained = df.groupBy("product_id").agg(
        avg("price").alias("avg_price")
    )

    # Explain plan - look for Gpu* operators
    df_explained.explain(extended=True)


def benchmark_comparison(df) -> None:
    """Compare GPU vs CPU performance (if fallback is enabled)."""
    print("\n8. Performance Comparison")
    spark = df.sql_ctx.sparkSession

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
