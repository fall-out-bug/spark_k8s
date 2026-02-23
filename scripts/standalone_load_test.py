#!/usr/bin/env python3
"""
Load test for Spark Standalone (direct spark-submit, no Connect).

Environment variables:
    SPARK_MASTER: spark://master:7077
    LOAD_MODE: range, skew, nulls (default: range)
    LOAD_ROWS: number of rows (default: 1000000)
    LOAD_PARTITIONS: number of partitions (default: 50)
    LOAD_ITERATIONS: number of test iterations (default: 3)
    S3_ENDPOINT: S3 endpoint URL (default: http://minio:9000)
"""

import os
import socket
import time
import sys
from pyspark.sql import SparkSession


def get_pod_fqdn() -> str:
    """Get the FQDN of the current pod for K8s networking."""
    # POD_IP is set by Kubernetes, POD_NAME and NAMESPACE from script
    pod_ip = os.environ.get("POD_IP", socket.gethostbyname(socket.gethostname()))
    return pod_ip


def create_spark_session() -> SparkSession:
    """Create SparkSession connected to Standalone master."""
    spark_master = os.environ.get("SPARK_MASTER", "spark://localhost:7077")
    s3_endpoint = os.environ.get("S3_ENDPOINT", "http://minio:9000")
    event_log_dir = os.environ.get("LOAD_EVENT_LOG_DIR", "s3a://spark-logs/events")

    # For K8s networking: driver must be reachable by workers
    driver_host = get_pod_fqdn()
    print(f"Driver host: {driver_host}")

    builder = (
        SparkSession.builder
        .appName("standalone-load-test")
        .master(spark_master)
        # K8s networking - driver must be reachable by workers
        .config("spark.driver.host", driver_host)
        .config("spark.driver.bindAddress", "0.0.0.0")
        # S3 configuration
        .config("spark.hadoop.fs.s3a.endpoint", s3_endpoint)
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        # Event log for History Server
        .config("spark.eventLog.enabled", "true")
        .config("spark.eventLog.dir", event_log_dir)
        # Resource settings
        .config("spark.executor.memory", "512m")
        .config("spark.executor.cores", "1")
        .config("spark.driver.memory", "512m")
        .config("spark.sql.shuffle.partitions", "4")
    )

    spark = builder.getOrCreate()
    print(f"✓ Spark session created (master={spark_master})")
    return spark


def run_load_test(spark: SparkSession, mode: str, rows: int, partitions: int) -> bool:
    """Run load test with specified parameters."""
    print(f"\nLoad test: mode={mode}, rows={rows}, partitions={partitions}")

    # Create test DataFrame based on mode
    if mode == "range":
        df = spark.range(0, rows, numPartitions=partitions)
    elif mode == "skew":
        # Create skewed data (some partitions have more data)
        df = spark.range(0, rows, numPartitions=partitions)
        df = df.withColumn("skew_key", (df.id % 10))
    elif mode == "nulls":
        df = spark.range(0, rows, numPartitions=partitions)
        # Add some null values
        from pyspark.sql.functions import when, col
        df = df.withColumn("value", when(col("id") % 100 == 0, None).otherwise(col("id")))
    else:
        print(f"Unknown mode: {mode}, using range")
        df = spark.range(0, rows, numPartitions=partitions)

    # Cache for multiple operations
    df.cache()

    # Operation 1: Aggregation
    start = time.time()
    result = df.agg({"id": "sum"}).collect()[0][0]
    agg_time = time.time() - start
    print(f"  Aggregation: {agg_time:.2f}s (sum={result})")

    # Operation 2: Filter + Count
    start = time.time()
    count = df.filter(df.id < rows // 2).count()
    filter_time = time.time() - start
    print(f"  Filter+Count: {filter_time:.2f}s")

    # Uncache
    df.unpersist()

    # Validate results
    expected_sum = (rows - 1) * rows // 2
    if result != expected_sum:
        print(f"  ERROR: Expected sum={expected_sum}, got {result}")
        return False

    return True


def main():
    mode = os.environ.get("LOAD_MODE", "range")
    rows = int(os.environ.get("LOAD_ROWS", "1000000"))
    partitions = int(os.environ.get("LOAD_PARTITIONS", "50"))
    iterations = int(os.environ.get("LOAD_ITERATIONS", "3"))

    print(f"Load test parameters: mode={mode}, rows={rows}, partitions={partitions}, iterations={iterations}")

    spark = create_spark_session()

    all_passed = True
    for i in range(1, iterations + 1):
        print(f"\nIteration {i}/{iterations}...")
        try:
            passed = run_load_test(spark, mode, rows, partitions)
            if not passed:
                all_passed = False
        except Exception as e:
            print(f"  ERROR: {e}")
            all_passed = False

    spark.stop()

    if all_passed:
        print("\n✓ All load test iterations passed")
        return 0
    else:
        print("\n✗ Some iterations failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
