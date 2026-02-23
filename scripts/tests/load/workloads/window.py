#!/usr/bin/env python3
"""
Window Workload for Load Testing
Part of WS-013-08: Load Test Scenario Implementation

Implements window function workload with metrics collection.

Usage:
    python window.py --operation window --data_size 1gb --output results.jsonl
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
    col, row_number, rank, dense_rank, lead, lag,
    count, sum as spark_sum, avg,
    window as spark_window
)
from pyspark.sql.window import Window


# Data paths for different sizes
DATA_PATHS = {
    "1gb": "s3a://raw-data/year=*/month=*/*.parquet",
    "11gb": "s3a://raw-data/year=*/month=*/*.parquet",
}


def create_spark_session() -> SparkSession:
    """Create Spark session with S3 configuration."""
    return SparkSession.builder \
        .appName("load-test-window") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio.spark-infra.svc.cluster.local:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.sql.shuffle.partitions", "200") \
        .config("spark.eventLog.enabled", "true") \
        .config("spark.eventLog.dir", "s3a://spark-logs/") \
        .config("spark.sql.windowExec.buffer.spill.threshold", "100000") \
        .getOrCreate()


def run_window_workload(
    spark: SparkSession,
    data_path: str,
    metadata: Dict[str, str],
) -> Dict[str, Any]:
    """
    Run window function workload and collect metrics.

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

    # Define window spec
    window_spec = Window.partitionBy("PULocationID").orderBy("tpep_pickup_datetime")

    # Apply multiple window functions
    result = df.select(
        "PULocationID",
        "tpep_pickup_datetime",
        "fare_amount",
        "passenger_count",
        # Row number within partition
        row_number().over(window_spec).alias("row_num"),
        # Rank within partition
        rank().over(window_spec).alias("rank"),
        # Dense rank
        dense_rank().over(window_spec).alias("dense_rank"),
        # Lead/lag values
        lead("fare_amount", 1).over(window_spec).alias("next_fare"),
        lag("fare_amount", 1).over(window_spec).alias("prev_fare"),
    )

    # Additional aggregation window
    agg_window = Window.partitionBy("PULocationID") \
        .rowsBetween(Window.unboundedPreceding, Window.currentRow)

    result = result.withColumn(
        "running_avg_fare",
        avg("fare_amount").over(agg_window)
    ).withColumn(
        "running_sum_fare",
        spark_sum("fare_amount").over(agg_window)
    )

    # Force execution
    result_count = result.count()

    # Estimate spill (not directly available)
    spill_bytes = 0  # Placeholder
    spill_rate_pct = 0.0  # Placeholder

    duration_sec = time.time() - start_time

    # Count partitions
    partition_count = df.select("PULocationID").distinct().count()

    return {
        "operation": "window",
        "start_time": datetime.utcnow().isoformat(),
        "duration_sec": duration_sec,
        "rows_processed": result_count,
        "partition_count": partition_count,
        "spill_bytes": spill_bytes,
        "spill_rate_pct": spill_rate_pct,
        "window_functions": ["row_number", "rank", "dense_rank", "lead", "lag", "running_avg", "running_sum"],
        "partition_by": ["PULocationID"],
        "order_by": ["tpep_pickup_datetime"],
        "data_path": data_path,
        **metadata,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Window workload for load testing"
    )
    parser.add_argument(
        '--operation', type=str, default='window',
        help='Operation name (for compatibility)'
    )
    parser.add_argument(
        '--data_size', type=str, required=True,
        choices=['1gb', '11gb'],
        help='Data size to process'
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
        metrics = run_window_workload(spark, data_path, metadata)

        # Write output
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'a') as f:
            f.write(json.dumps(metrics) + '\n')

        print(f"Window workload complete: {metrics['rows_processed']:,} rows in {metrics['duration_sec']:.2f}s")
        print(f"Partitions: {metrics['partition_count']}")

        return 0

    except Exception as e:
        print(f"Error running window workload: {e}")
        return 1

    finally:
        spark.stop()


if __name__ == '__main__':
    sys.exit(main())
