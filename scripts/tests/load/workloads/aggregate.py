#!/usr/bin/env python3
"""
Aggregate Workload for Load Testing
Part of WS-013-08: Load Test Scenario Implementation

Implements aggregation workload with metrics collection.

Usage:
    python aggregate.py --operation aggregate --data_size 1gb --output results.jsonl
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
    col, count, sum as spark_sum, avg, max as spark_max, min as spark_min,
    year, month, dayofmonth, hour
)


# Data paths for different sizes
DATA_PATHS = {
    "1gb": "s3a://raw-data/year=*/month=*/*.parquet",
    "11gb": "s3a://raw-data/year=*/month=*/*.parquet",
}


def create_spark_session() -> SparkSession:
    """Create Spark session with S3 configuration."""
    return SparkSession.builder \
        .appName("load-test-aggregate") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio.spark-infra.svc.cluster.local:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.sql.shuffle.partitions", "200") \
        .config("spark.eventLog.enabled", "true") \
        .config("spark.eventLog.dir", "s3a://spark-logs/") \
        .getOrCreate()


def run_aggregate_workload(
    spark: SparkSession,
    data_path: str,
    metadata: Dict[str, str],
) -> Dict[str, Any]:
    """
    Run aggregation workload and collect metrics.

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

    # Perform multi-level aggregation
    result = df.groupBy(
        year("tpep_pickup_datetime").alias("year"),
        month("tpep_pickup_datetime").alias("month"),
        dayofmonth("tpep_pickup_datetime").alias("day"),
        hour("tpep_pickup_datetime").alias("hour"),
        "PULocationID"
    ).agg(
        count("*").alias("trip_count"),
        spark_sum("trip_distance").alias("total_distance"),
        spark_sum("fare_amount").alias("total_fare"),
        avg("passenger_count").alias("avg_passengers"),
        spark_max("fare_amount").alias("max_fare"),
        spark_min("fare_amount").alias("min_fare"),
    )

    # Force execution
    row_count = result.count()

    # Collect shuffle metrics
    sc = spark.sparkContext
    shuffle_bytes = sc._jsc.sc().statusTracker().getExecutorInfos()  # type: ignore

    duration_sec = time.time() - start_time

    # Estimate spill (not directly available via API)
    spill_bytes = 0  # Placeholder

    return {
        "operation": "aggregate",
        "start_time": datetime.utcnow().isoformat(),
        "duration_sec": duration_sec,
        "rows_aggregated": row_count,
        "shuffle_bytes": shuffle_bytes,
        "spill_bytes": spill_bytes,
        "aggregation_levels": 5,  # year, month, day, hour, location
        "data_path": data_path,
        **metadata,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate workload for load testing"
    )
    parser.add_argument(
        '--operation', type=str, default='aggregate',
        help='Operation name (for compatibility)'
    )
    parser.add_argument(
        '--data_size', type=str, required=True,
        choices=['1gb', '11gb'],
        help='Data size to aggregate'
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
        metrics = run_aggregate_workload(spark, data_path, metadata)

        # Write output
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'a') as f:
            f.write(json.dumps(metrics) + '\n')

        print(f"Aggregate workload complete: {metrics['rows_aggregated']:,} groups in {metrics['duration_sec']:.2f}s")

        return 0

    except Exception as e:
        print(f"Error running aggregate workload: {e}")
        return 1

    finally:
        spark.stop()


if __name__ == '__main__':
    sys.exit(main())
