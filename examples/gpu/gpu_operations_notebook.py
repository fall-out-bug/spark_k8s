#!/usr/bin/env python3
"""
GPU Operations Example for Spark with RAPIDS

This notebook demonstrates GPU-accelerated operations using Spark RAPIDS plugin.
Run this in Jupyter with GPU-enabled Spark cluster.

Prerequisites:
- GPU-enabled Spark cluster (use presets/gpu-values.yaml)
- RAPIDS plugin installed
"""

from gpu_setup import create_gpu_spark_session, print_gpu_status
from gpu_data import create_sample_data
from gpu_io import gpu_parquet_operations
from gpu_transforms import (
    gpu_aggregations,
    gpu_joins,
    gpu_filter_operations,
    gpu_sort_operations,
)
from gpu_analysis import explain_gpu_plan, benchmark_comparison


def main():
    """Main execution flow."""
    print("=" * 80)
    print("Spark GPU Operations Example")
    print("=" * 80)

    spark = create_gpu_spark_session()
    print_gpu_status(spark)

    print("\n" + "=" * 80)
    print("Starting GPU Operations Demo")
    print("=" * 80)

    df = create_sample_data(spark, size_million=10)
    df = gpu_parquet_operations(df)
    gpu_aggregations(df)
    gpu_joins(df)
    gpu_filter_operations(df)
    gpu_sort_operations(df)
    explain_gpu_plan(df)
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

    spark.stop()


if __name__ == "__main__":
    main()
