#!/usr/bin/env python3
"""GPU setup and session initialization for Spark RAPIDS."""

from pyspark.sql import SparkSession


def create_gpu_spark_session(app_name: str = "GPU Operations") -> SparkSession:
    """Create Spark session with GPU/RAPIDS configuration."""
    return SparkSession.builder \
        .appName(app_name) \
        .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
        .config("spark.rapids.sql.enabled", "true") \
        .config("spark.rapids.sql.fallback.enabled", "true") \
        .getOrCreate()


def print_gpu_status(spark: SparkSession) -> None:
    """Print GPU availability status."""
    print(f"\nSpark Version: {spark.version}")
    print("RAPIDS Plugin: Enabled")

    try:
        gpu_count = spark._jvm.org.apache.spark.TaskContext.get().getResourceAmount("gpu")
        print(f"GPUs Available: {gpu_count}")
    except Exception:
        print("GPU status: Unable to detect")


def disable_gpu(spark: SparkSession) -> None:
    """Disable GPU acceleration for comparison."""
    spark.conf.set("spark.rapids.sql.enabled", "false")


def enable_gpu(spark: SparkSession) -> None:
    """Re-enable GPU acceleration."""
    spark.conf.set("spark.rapids.sql.enabled", "true")
