#!/usr/bin/env python3
"""Spark Connect load test. Run inside cluster with CONNECT_URL and LOAD_* env."""
import os
import sys
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum

def main() -> None:
    connect_url = os.environ.get("CONNECT_URL", "sc://localhost:15002")
    load_mode = os.environ.get("LOAD_MODE", "range")
    load_rows = int(os.environ.get("LOAD_ROWS", "1000000"))
    load_partitions = int(os.environ.get("LOAD_PARTITIONS", "50"))
    load_iterations = int(os.environ.get("LOAD_ITERATIONS", "3"))
    load_dataset = os.environ.get("LOAD_DATASET", "nyc")
    load_s3_endpoint = os.environ.get("LOAD_S3_ENDPOINT", "http://minio:9000")
    # Use S3 for event log so History Server (infra) can show this job
    event_log_dir = os.environ.get("LOAD_EVENT_LOG_DIR", "")
    builder = (
        SparkSession.builder.appName("ConnectStandaloneLoadTest").remote(connect_url)
    )
    if event_log_dir:
        builder = (
            builder.config("spark.eventLog.enabled", "true")
            .config("spark.eventLog.dir", event_log_dir)
            .config("spark.history.fs.logDirectory", event_log_dir)
        )
        builder = (
            builder.config("spark.hadoop.fs.s3a.endpoint", load_s3_endpoint)
            .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
            .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
            .config("spark.hadoop.fs.s3a.path.style.access", "true")
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        )
    if load_mode == "parquet":
        builder = (
            builder.config("spark.hadoop.fs.s3a.endpoint", load_s3_endpoint)
            .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
            .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
            .config("spark.hadoop.fs.s3a.path.style.access", "true")
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        )

    spark = builder.getOrCreate()
    print("✓ Spark Connect session created (Standalone backend)")

    if load_mode == "parquet":
        path = f"s3a://test-data/{load_dataset}/"
        print(f"Loading parquet from: {path}")
        start = time.time()
        df = spark.read.parquet(path)
        count = df.count()
        print(f"  Loaded {count:,} records in {time.time() - start:.2f}s")
        df.cache()
        df.count()
        for i in range(load_iterations):
            print(f"\nIteration {i+1}/{load_iterations}...")
            start = time.time()
            if "passenger_count" in df.columns:
                df.agg({"passenger_count": "avg"}).collect()
            else:
                df.count()
            print(f"  Aggregation: {time.time() - start:.2f}s")
            start = time.time()
            if "passenger_count" in df.columns:
                df.filter(col("passenger_count") > 1).count()
            else:
                df.filter(col(df.columns[0]).isNotNull()).count()
            print(f"  Filter: {time.time() - start:.2f}s")
    else:
        for i in range(load_iterations):
            print(f"\nIteration {i+1}/{load_iterations}...")
            start = time.time()
            df = spark.range(load_rows).repartition(load_partitions)
            print(f"  Created DataFrame: {time.time() - start:.2f}s")
            start = time.time()
            result = df.agg(spark_sum(col("id"))).collect()[0][0]
            expected = load_rows * (load_rows - 1) // 2
            assert result == expected, f"Sum mismatch: {result} != {expected}"
            print(f"  Aggregation: {time.time() - start:.2f}s (sum={result})")
            start = time.time()
            filtered = df.filter(col("id") % 2 == 0).count()
            assert filtered == load_rows // 2
            print(f"  Filter+Count: {time.time() - start:.2f}s")

    print("\n✓ All load test iterations passed")
    spark.stop()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"FAILED: {e}", file=sys.stderr)
        sys.exit(1)
