#!/usr/bin/env python3
"""
NYC Taxi Data Generator for Load Testing
Part of WS-013-06: Minikube Auto-Setup Infrastructure

Generates synthetic NYC taxi trip data for load testing.
Supports generating 1GB and 11GB datasets with proper partitioning.

Usage:
    python generate-nyc-taxi.py --size 1gb [--upload]
    python generate-nyc-taxi.py --size 11gb [--upload]
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, rand, when, lit, floor, date_format, substring, concat,
    year, month, dayofmonth, hour, monotonically_increasing_id
)
from pyspark.sql.types import (
    StructType, StructField, IntegerType, LongType, FloatType,
    DoubleType, TimestampType, StringType
)


# NYC taxi zone locations (approximate coordinates)
MANHATTAN_ZONES = [
    (-73.9712, 40.7831),  # Upper West Side
    (-73.9851, 40.7484),  # Garment District
    (-73.9965, 40.7289),  # Tribeca
    (-73.9654, 40.7829),  # Upper East Side
    (-74.0060, 40.7128),  # Financial District
]

BRONX_ZONES = [
    (-73.8648, 40.8448),  # Fordham
    (-73.8845, 40.8270),  # Belmont
]

BROOKLYN_ZONES = [
    (-73.9442, 40.6782),  # Park Slope
    (-73.9534, 40.7010),  # Williamsburg
    (-73.9498, 40.6230),  # Coney Island
]

QUEENS_ZONES = [
    (-73.8205, 40.7591),  # Astoria
    (-73.7949, 40.7174),  # Sunnyside
]

ALL_ZONES = MANHATTAN_ZONES + BRONX_ZONES + BROOKLYN_ZONES + QUEENS_ZONES

# Schema matching NYC taxi data structure
TAXI_SCHEMA = StructType([
    StructField("VendorID", IntegerType(), nullable=True),
    StructField("tpep_pickup_datetime", TimestampType(), nullable=False),
    StructField("tpep_dropoff_datetime", TimestampType(), nullable=False),
    StructField("passenger_count", IntegerType(), nullable=True),
    StructField("trip_distance", DoubleType(), nullable=False),
    StructField("RatecodeID", IntegerType(), nullable=True),
    StructField("store_and_fwd_flag", StringType(), nullable=True),
    StructField("PULocationID", IntegerType(), nullable=False),
    StructField("DOLocationID", IntegerType(), nullable=False),
    StructField("payment_type", IntegerType(), nullable=True),
    StructField("fare_amount", DoubleType(), nullable=False),
    StructField("extra", DoubleType(), nullable=True),
    StructField("mta_tax", DoubleType(), nullable=True),
    StructField("tip_amount", DoubleType(), nullable=True),
    StructField("tolls_amount", DoubleType(), nullable=True),
    StructField("improvement_surcharge", DoubleType(), nullable=True),
    StructField("total_amount", DoubleType(), nullable=False),
    StructField("congestion_surcharge", DoubleType(), nullable=True),
])


def create_spark_session() -> SparkSession:
    """Create Spark session with S3 configuration."""
    return SparkSession.builder \
        .appName("nyc-taxi-data-generator") \
        .config("spark.sql.shuffle.partitions", "200") \
        .getOrCreate()


def generate_trip_data(spark: SparkSession, num_rows: int, year: int, month: int) -> None:
    """
    Generate synthetic taxi trip data.

    Args:
        spark: Spark session
        num_rows: Number of rows to generate
        year: Year for the data
        month: Month for the data
    """
    # Start with a range to create unique IDs
    df = spark.range(num_rows)

    # Add pickup datetime (distributed throughout the month)
    start_date = datetime(year, month, 1)
    if month == 12:
        end_date = datetime(year + 1, 1, 1) - timedelta(seconds=1)
    else:
        end_date = datetime(year, month + 1, 1) - timedelta(seconds=1)

    df = df.withColumn("pickup_seconds",
                      floor(rand() * (end_date - start_date).total_seconds())) \
           .withColumn("tpep_pickup_datetime",
                      (lit(start_date.timestamp()).cast("long") + col("pickup_seconds"))
                      .cast("timestamp")) \
           .drop("pickup_seconds")

    # Add dropoff datetime (5-30 minutes after pickup)
    df = df.withColumn("trip_duration_seconds",
                      (floor(rand() * 1500) + 300)) \
           .withColumn("tpep_dropoff_datetime",
                      (col("tpep_pickup_datetime").cast("long") + col("trip_duration_seconds"))
                      .cast("timestamp")) \
           .drop("trip_duration_seconds")

    # Add passenger count (1-6, weighted towards 1-2)
    df = df.withColumn("passenger_count",
                      when(rand() < 0.6, 1)
                      .when(rand() < 0.8, 2)
                      .when(rand() < 0.9, 3)
                      .when(rand() < 0.95, 4)
                      .when(rand() < 0.98, 5)
                      .otherwise(6))

    # Add trip distance (0.5 - 20 miles, weighted towards shorter trips)
    df = df.withColumn("trip_distance",
                      (rand() * 19.5 + 0.5))

    # Add pickup/dropoff location IDs (1-263, NYC taxi zones)
    df = df.withColumn("PULocationID",
                      floor(rand() * 263) + 1) \
           .withColumn("DOLocationID",
                      floor(rand() * 263) + 1)

    # Add vendor ID (1 or 2)
    df = df.withColumn("VendorID",
                      when(rand() < 0.5, 1).otherwise(2))

    # Add rate code (1-6)
    df = df.withColumn("RatecodeID",
                      when(rand() < 0.9, 1)  # Standard rate
                      .when(rand() < 0.95, 2)  # JFK
                      .otherwise(4))  # Nassau or Westchester

    # Add store and forward flag
    df = df.withColumn("store_and_fwd_flag",
                      when(rand() < 0.1, "Y").otherwise("N"))

    # Calculate fare based on distance and duration
    df = df.withColumn("base_fare",
                      (col("trip_distance") * 2.5 + 3.0))  # $2.50/mile + $3.00 base

    # Add fare amount with some variance
    df = df.withColumn("fare_amount",
                      col("base_fare") * (1.0 + (rand() - 0.5) * 0.2)) \
           .drop("base_fare")

    # Add tip amount (0-30% of fare, weighted towards lower tips)
    df = df.withColumn("tip_amount",
                      col("fare_amount") * (rand() * 0.3))

    # Add other charges
    df = df.withColumn("extra",
                      when(hour(col("tpep_pickup_datetime")) >= 16, 1.0)  # Evening surcharge
                      .when(hour(col("tpep_pickup_datetime")) < 6, 0.5)  # Overnight
                      .otherwise(0.0)) \
           .withColumn("mta_tax", lit(0.5)) \
           .withColumn("tolls_amount", when(rand() < 0.2, rand() * 10).otherwise(0.0)) \
           .withColumn("improvement_surcharge", lit(0.3)) \
           .withColumn("congestion_surcharge", when(rand() < 0.3, 2.75).otherwise(0.0))

    # Calculate total amount
    df = df.withColumn("total_amount",
                      col("fare_amount") + col("tip_amount") +
                      col("extra") + col("mta_tax") +
                      col("tolls_amount") + col("improvement_surcharge") +
                      col("congestion_surcharge"))

    # Add payment type (1-6)
    df = df.withColumn("payment_type",
                      when(rand() < 0.6, 1)  # Credit card
                      .when(rand() < 0.95, 2)  # Cash
                      .otherwise(3))  # No charge

    # Select and order columns
    df = df.select([
        "VendorID", "tpep_pickup_datetime", "tpep_dropoff_datetime",
        "passenger_count", "trip_distance", "RatecodeID", "store_and_fwd_flag",
        "PULocationID", "DOLocationID", "payment_type", "fare_amount",
        "extra", "mta_tax", "tip_amount", "tolls_amount",
        "improvement_surcharge", "total_amount", "congestion_surcharge"
    ])

    return df


def calculate_checksum(file_path: str) -> str:
    """Calculate MD5 checksum of a file."""
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def upload_to_minio(local_path: str, bucket: str, prefix: str) -> dict:
    """
    Upload data to Minio using mc (Minio client).

    Args:
        local_path: Local path to upload
        bucket: Minio bucket name
        prefix: S3 prefix

    Returns:
        Dictionary with upload results
    """
    try:
        # Check if mc is available
        subprocess.run(["mc", "--version"], check=True, capture_output=True)

        # Configure Minio alias
        subprocess.run([
            "mc", "alias", "set", "local",
            "http://minio.load-testing.svc.cluster.local:9000",
            "minioadmin", "minioadmin"
        ], check=True, capture_output=True)

        # Copy data
        subprocess.run([
            "mc", "cp", "--recursive",
            local_path, f"local/{bucket}/{prefix}/"
        ], check=True, capture_output=True)

        return {"success": True, "path": f"s3a://{bucket}/{prefix}/"}

    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        return {"success": False, "error": str(e)}


def main():
    parser = argparse.ArgumentParser(
        description="Generate NYC taxi data for load testing"
    )
    parser.add_argument(
        "--size", type=str, required=True,
        choices=["1gb", "11gb"],
        help="Dataset size to generate"
    )
    parser.add_argument(
        "--upload", action="store_true",
        help="Upload to Minio after generation"
    )
    parser.add_argument(
        "--output", type=str,
        default="/tmp/nyc-taxi-generated",
        help="Output directory"
    )
    parser.add_argument(
        "--year", type=int, default=2025,
        help="Year for generated data"
    )
    parser.add_argument(
        "--month", type=int, default=1,
        help="Month for generated data"
    )

    args = parser.parse_args()

    # Calculate row counts based on size
    # Approximate row size: 500 bytes
    # 1GB ~ 2.1M rows, 11GB ~ 23M rows
    if args.size == "1gb":
        num_rows = 2_100_000
        num_months = 1
    else:  # 11gb
        num_rows = 2_100_000
        num_months = 11

    print(f"Generating {args.size} NYC taxi dataset ({num_months} month(s), ~{num_rows * num_months:,} rows)")
    print(f"Output: {args.output}")
    print(f"Upload: {args.upload}")

    spark = create_spark_session()

    try:
        generated_files = []

        for month_idx in range(num_months):
            month = (args.month + month_idx - 1) % 12 + 1
            year = args.year + (args.month + month_idx - 1) // 12

            print(f"\nGenerating data for {year}-{month:02d}...")

            df = generate_trip_data(spark, num_rows, year, month)

            # Partition by year/month and write
            output_path = f"{args.output}/year={year}/month={month:02d}"
            df.write \
              .mode("overwrite") \
              .partitionBy("year", "month") \
              .parquet(output_path)

            print(f"  Written to: {output_path}")
            generated_files.append(output_path)

        # Calculate checksums
        print("\nCalculating checksums...")
        checksums = {}
        for path in generated_files:
            # For parquet files, checksum the directory
            checksum = calculate_checksum_directory(path)
            checksums[path] = checksum
            print(f"  {path}: {checksum}")

        # Save checksums
        checksum_file = f"{args.output}/checksums.json"
        with open(checksum_file, "w") as f:
            json.dump(checksums, f, indent=2)
        print(f"\nChecksums saved to: {checksum_file}")

        # Upload to Minio if requested
        if args.upload:
            print("\nUploading to Minio...")
            result = upload_to_minio(f"{args.output}/", "test-data", "nyc-taxi")
            if result["success"]:
                print(f"  Uploaded to: {result['path']}")
            else:
                print(f"  Upload failed: {result['error']}")
                return 1

        print("\nGeneration complete!")
        return 0

    finally:
        spark.stop()


def calculate_checksum_directory(directory: str) -> str:
    """Calculate checksum for all files in a directory."""
    hash_md5 = hashlib.md5()
    for root, _, files in os.walk(directory):
        for file in sorted(files):
            file_path = os.path.join(root, file)
            if os.path.isfile(file_path):
                with open(file_path, "rb") as f:
                    for chunk in iter(lambda: f.read(4096), b""):
                        hash_md5.update(chunk)
    return hash_md5.hexdigest()


if __name__ == "__main__":
    sys.exit(main())
