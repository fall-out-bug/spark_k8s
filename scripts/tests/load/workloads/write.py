#!/usr/bin/env python3
"""
Write Workload for Load Testing
Part of WS-013-08: Load Test Scenario Implementation

Implements Postgres write operation with metrics collection.

Usage:
    python write.py --operation write --data_size 1gb --output results.jsonl
"""

import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, spark_sum, avg, lit
)


# Data paths for different sizes
DATA_PATHS = {
    "1gb": "s3a://raw-data/year=*/month=*/*.parquet",
    "11gb": "s3a://raw-data/year=*/month=*/*.parquet",
}

# Postgres connection
POSTGRES_URL = "jdbc:postgresql://postgres-load-testing.load-testing.svc.cluster.local:5432/spark_db"
POSTGRES_PROPS = {
    "user": "postgres",
    "password": "sparktest",
    "driver": "org.postgresql.Driver",
}


def create_spark_session() -> SparkSession:
    """Create Spark session with S3 and Postgres configuration."""
    return SparkSession.builder \
        .appName("load-test-write") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio.spark-infra.svc.cluster.local:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.sql.shuffle.partitions", "200") \
        .config("spark.eventLog.enabled", "true") \
        .config("spark.eventLog.dir", "s3a://spark-logs/") \
        .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
        .getOrCreate()


def run_write_workload(
    spark: SparkSession,
    data_path: str,
    metadata: Dict[str, str],
) -> Dict[str, Any]:
    """
    Run Postgres write workload and collect metrics.

    Args:
        spark: Spark session
        data_path: Path to input data
        metadata: Test metadata

    Returns:
        Dictionary with metrics
    """
    start_time = time.time()

    # Read data
    df = spark.read.parquet(data_path)

    # Aggregate for summary table
    summary = df.groupBy(
        "PULocationID"
    ).agg(
        count("*").alias("total_trips"),
        spark_sum("passenger_count").alias("total_passengers"),
        avg("trip_distance").alias("avg_distance"),
        spark_sum("fare_amount").alias("total_fare"),
    )

    # Count rows to write
    rows_to_write = summary.count()

    # Write to Postgres with batch optimization
    write_start = time.time()

    summary.write \
        .mode("overwrite") \
        .option("truncate", "true") \
        .option("batchsize", "10000") \
        .option("rewriteBatchedInserts", "true") \
        .jdbc(
            POSTGRES_URL,
            "test_schema.trip_summary",
            properties=POSTGRES_PROPS
        )

    write_duration = time.time() - write_start
    total_duration = time.time() - start_time

    return {
        "operation": "write",
        "start_time": datetime.utcnow().isoformat(),
        "duration_sec": total_duration,
        "write_duration_sec": write_duration,
        "rows_written": rows_to_write,
        "batches_written": (rows_to_write + 9999) // 10000,  # Assuming batchsize=10000
        "throughput_rows_sec": rows_to_write / total_duration if total_duration > 0 else 0,
        "target_table": "test_schema.trip_summary",
        "target_database": POSTGRES_URL,
        "data_path": data_path,
        **metadata,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Write workload for load testing"
    )
    parser.add_argument(
        '--operation', type=str, default='write',
        help='Operation name (for compatibility)'
    )
    parser.add_argument(
        '--data_size', type=str, required=True,
        choices=['1gb', '11gb'],
        help='Data size to write'
    )
    parser.add_argument(
        '--output', type=str, required=True,
        help='Output file for metrics (JSONL)'
    )
    parser.add_argument(
        '--metadata', type=str,
        help='Additional metadata as JSON string'
    )

    args = parser.parse_args()

    # Parse metadata
    metadata = {}
    if args.metadata:
        metadata = json.loads(args.metadata)

    # Get data path
    data_path = DATA_PATHS.get(args.data_size)
    if not data_path:
        print(f"Error: Unknown data size '{args.data_size}'")
        return 1

    # Create Spark session
    spark = create_spark_session()

    try:
        # Run workload
        metrics = run_write_workload(spark, data_path, metadata)

        # Write output
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'a') as f:
            f.write(json.dumps(metrics) + '\n')

        print(f"Write workload complete: {metrics['rows_written']:,} rows in {metrics['duration_sec']:.2f}s")
        print(f"Throughput: {metrics['throughput_rows_sec']:,.0f} rows/sec")

        return 0

    except Exception as e:
        print(f"Error running write workload: {e}")
        return 1

    finally:
        spark.stop()


if __name__ == '__main__':
    sys.exit(main())
