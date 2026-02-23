#!/usr/bin/env python3
"""GPU-accelerated I/O operations for Spark."""

import time


def gpu_parquet_operations(df):
    """
    Demonstrate GPU-accelerated Parquet operations.

    Parquet read/write is heavily optimized in RAPIDS.
    """
    print("\n2. GPU-Accelerated Parquet Operations")

    start = time.time()
    df.write.mode("overwrite").parquet("/tmp/gpu_example.parquet")
    write_time = time.time() - start
    print(f"   Write time: {write_time:.2f}s")

    start = time.time()
    df_read = df.sql_ctx.sparkSession.read.parquet("/tmp/gpu_example.parquet")
    read_time = time.time() - start
    print(f"   Read time: {read_time:.2f}s")

    return df_read
