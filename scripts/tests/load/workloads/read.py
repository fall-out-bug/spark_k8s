#!/usr/bin/env python3
"""
Read Workload for Load Testing
Part of WS-013-08: Load Test Scenario Implementation

Implements S3 read operation with metrics collection.

Usage:
    python read.py --operation read --data_size 1gb --output results.jsonl
"""

import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

from pyspark.sql import SparkSession


# Data paths for different sizes
DATA_PATHS = {
    "1gb": "s3a://test-data/nyc-taxi/year=*/month=*/*.parquet",
    "11gb": "s3a://test-data/nyc-taxi/year=*/month=*/*.parquet",
}


def create_spark_session() -> SparkSession:
    """Create Spark session with S3 configuration."""
    return SparkSession.builder \
        .appName("load-test-read") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio.load-testing.svc.cluster.local:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.sql.shuffle.partitions", "200") \
        .getOrCreate()


def run_read_workload(
    spark: SparkSession,
    data_path: str,
    metadata: Dict[str, str],
) -> Dict[str, Any]:
    """
    Run read workload and collect metrics.

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

    # Force materialization
    count = df.count()

    # Collect additional metrics
    read_bytes = df._jdf.sparkContext().statusTracker().getExecutorInfos()  # type: ignore

    # Calculate derived metrics
    duration_sec = time.time() - start_time
    throughput_rows_sec = count / duration_sec if duration_sec > 0 else 0

    return {
        "operation": "read",
        "start_time": datetime.utcnow().isoformat(),
        "duration_sec": duration_sec,
        "rows_read": count,
        "throughput_rows_sec": throughput_rows_sec,
        "data_path": data_path,
        **metadata,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Read workload for load testing"
    )
    parser.add_argument(
        '--operation', type=str, default='read',
        help='Operation name (for compatibility)'
    )
    parser.add_argument(
        '--data_size', type=str, required=True,
        choices=['1gb', '11gb'],
        help='Data size to read'
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
        metrics = run_read_workload(spark, data_path, metadata)

        # Write output
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'a') as f:
            f.write(json.dumps(metrics) + '\n')

        print(f"Read workload complete: {metrics['rows_read']:,} rows in {metrics['duration_sec']:.2f}s")
        print(f"Throughput: {metrics['throughput_rows_sec']:,.0f} rows/sec")

        return 0

    except Exception as e:
        print(f"Error running read workload: {e}")
        return 1

    finally:
        spark.stop()


if __name__ == '__main__':
    sys.exit(main())
