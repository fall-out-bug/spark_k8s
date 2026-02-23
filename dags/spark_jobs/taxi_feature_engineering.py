#!/usr/bin/env python3
"""
NYC Taxi Feature Engineering - Spark Pipeline

Generates features for 7-day revenue/trip prediction.

Usage (in cluster):
    spark-submit --master spark://scenario2-spark-35-standalone-master:7077 \
        taxi_feature_engineering.py

Environment variables:
    MINIO_ENDPOINT: MinIO endpoint (default: http://minio.spark-infra.svc.cluster.local:9000)
    MINIO_ACCESS_KEY: Access key (default: minioadmin)
    MINIO_SECRET_KEY: Secret key (default: minioadmin)
"""

import os
import socket
import sys
import time
from datetime import datetime

import requests
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import *
from pyspark.sql.window import Window

# Configuration
MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")
PUSHGATEWAY_URL = os.environ.get("PUSHGATEWAY_URL", "http://prometheus-pushgateway.spark-operations:9091")

# Metrics
METRICS = {}


def push_metric(name, value, labels=None):
    """Push metric to Prometheus Pushgateway."""
    if labels is None:
        labels = {}
    labels['job'] = 'spark_feature_engineering'

    label_str = ','.join([f'{k}="{v}"' for k, v in labels.items()])
    metric_data = f'# TYPE {name} gauge\n{name}{{{label_str}}} {value}\n'

    try:
        requests.post(
            f"{PUSHGATEWAY_URL}/metrics/job/spark_feature_engineering",
            data=metric_data,
            timeout=5
        )
        print(f"  Pushed metric: {name}={value}")
    except Exception as e:
        print(f"  Warning: Could not push metric: {e}")


def get_pod_ip():
    """Get pod IP address."""
    try:
        return socket.gethostbyname(socket.gethostname())
    except:
        return "127.0.0.1"

RAW_PATH = "s3a://nyc-taxi/raw/"
FEATURES_PATH = "s3a://nyc-taxi/features/"


def create_spark_session():
    """Create Spark session with MinIO and Iceberg config."""
    # Get pod IP for driver host (required for K8s networking)
    pod_ip = get_pod_ip()
    print(f"Pod IP: {pod_ip}")

    spark = (SparkSession.builder
        .appName("nyc-taxi-feature-engineering")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
        .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .getOrCreate())

    print(f"Spark session created: {spark.sparkContext.applicationId}")
    return spark


def load_raw_data(spark):
    """Load raw TLC parquet files."""
    print(f"Loading raw data from {RAW_PATH}...")

    # Read all parquet files from 2023-2024 (24 months)
    # Generate file list dynamically
    file_list = []
    for year in [2023, 2024]:
        for month in range(1, 13):
            file_list.append(f"s3a://nyc-taxi/raw/yellow_tripdata_{year}-{month:02d}.parquet")

    print(f"  Found {len(file_list)} files to process")

    dfs = []
    for file_path in file_list:
        print(f"  Reading {file_path.split('/')[-1]}...")
        try:
            df_file = spark.read.parquet(file_path)

            # Cast columns to consistent types
            df_file = df_file.withColumn("PULocationID", F.col("PULocationID").cast("int"))
            df_file = df_file.withColumn("DOLocationID", F.col("DOLocationID").cast("int"))
            df_file = df_file.withColumn("passenger_count", F.col("passenger_count").cast("int"))
            df_file = df_file.withColumn("RatecodeID", F.col("RatecodeID").cast("int"))
            df_file = df_file.withColumn("VendorID", F.col("VendorID").cast("int"))
            df_file = df_file.withColumn("payment_type", F.col("payment_type").cast("int"))

            dfs.append(df_file)
            print(f"    Loaded {df_file.count():,} rows")
        except Exception as e:
            print(f"    Error: {e}")
            continue

    if not dfs:
        raise ValueError("No files could be read!")

    # Union all dataframes
    df = dfs[0]
    for df_file in dfs[1:]:
        df = df.unionByName(df_file, allowMissingColumns=True)

    # Basic filtering - remove invalid records
    df = df.filter(
        (F.col("trip_distance") > 0) &
        (F.col("fare_amount") > 0) &
        (F.col("total_amount") > 0) &
        (F.col("tpep_pickup_datetime") >= "2023-01-01") &
        (F.col("tpep_pickup_datetime") < "2025-01-01")
    )

    print(f"Total loaded: {df.count():,} records")
    return df


def add_temporal_features(df):
    """Add temporal features."""
    print("Adding temporal features...")

    # US Holidays 2023-2024
    holidays = [
        "2023-01-01", "2023-01-16", "2023-02-20", "2023-05-29", "2023-06-19",
        "2023-07-04", "2023-09-04", "2023-10-09", "2023-11-11", "2023-11-23",
        "2023-12-25", "2024-01-01", "2024-01-15", "2024-02-19", "2024-05-27",
        "2024-06-19", "2024-07-04", "2024-09-02", "2024-10-14", "2024-11-11",
        "2024-11-28", "2024-12-25"
    ]
    holidays_list = [datetime.strptime(d, "%Y-%m-%d").date() for d in holidays]

    df = (df
        # Basic temporal
        .withColumn("pickup_date", F.to_date("tpep_pickup_datetime"))
        .withColumn("hour_of_day", F.hour("tpep_pickup_datetime"))
        .withColumn("day_of_week", F.dayofweek("tpep_pickup_datetime"))
        .withColumn("day_of_month", F.dayofmonth("tpep_pickup_datetime"))
        .withColumn("month", F.month("tpep_pickup_datetime"))
        .withColumn("quarter", F.quarter("tpep_pickup_datetime"))
        .withColumn("year", F.year("tpep_pickup_datetime"))
        .withColumn("week_of_year", F.weekofyear("tpep_pickup_datetime"))

        # Derived temporal
        .withColumn("is_weekend", F.when(F.col("day_of_week").isin([1, 7]), 1).otherwise(0))
        .withColumn("is_rush_hour",
            F.when(
                (F.col("hour_of_day").between(7, 9)) |
                (F.col("hour_of_day").between(17, 19)),
                1
            ).otherwise(0))
        .withColumn("is_holiday",
            F.when(F.col("pickup_date").isin(holidays_list), 1).otherwise(0))
        .withColumn("time_of_day",
            F.when(F.col("hour_of_day") < 6, "night")
             .when(F.col("hour_of_day") < 12, "morning")
             .when(F.col("hour_of_day") < 18, "afternoon")
             .otherwise("evening"))
    )

    return df


def add_geospatial_features(df):
    """Add geospatial features."""
    print("Adding geospatial features...")

    # Zone to Borough mapping (simplified)
    # Manhattan: 4, 12, 13, 24, 41, 42, 43, 45, 48, 50, 68, 74, 75, 79, 87, 88, 90, 100, 103, 104, 105, 107, 113, 114, 116, 120, 125, 127, 128, 137, 140, 141, 142, 143, 144, 148, 151, 152, 153, 158, 161, 162, 163, 164, 166, 170, 186, 194, 202, 209, 211, 229, 230, 231, 232, 233, 234, 236, 237, 238, 239, 243, 244, 246, 249, 261, 262, 263
    # Brooklyn: 11, 14, 17, 21, 22, 25, 26, 29, 33, 34, 35, 36, 37, 39, 40, 49, 52, 54, 55, 58, 59, 61, 63, 65, 66, 67, 69, 70, 71, 72, 76, 77, 80, 81, 83, 84, 85, 86, 91, 94, 97, 106, 108, 111, 112, 123, 129, 133, 134, 135, 136, 138, 139, 145, 146, 147, 149, 150, 154, 155, 156, 157, 159, 160, 165, 167, 168, 169, 171, 172, 173, 174, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 187, 188, 189, 190, 191, 192, 193, 195, 196, 197, 198, 199, 200, 201, 203, 204, 205, 206, 207, 208, 210, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 235, 240, 241, 242, 245, 247, 248, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 264, 265
    # Queens: 2, 7, 8, 9, 10, 15, 16, 18, 19, 20, 27, 28, 30, 31, 32, 38, 44, 46, 47, 51, 53, 56, 57, 60, 62, 64, 73, 78, 82, 89, 92, 93, 95, 96, 98, 99, 101, 102, 109, 110, 115, 117, 118, 119, 121, 122, 124, 126, 130, 131, 132, 137, 140, 141, 142, 143, 144, 148, 151, 152, 153, 158, 161, 162, 163, 164, 166, 170, 186, 194, 202, 209, 211, 229, 230, 231, 232, 233, 234, 236, 237, 238, 239, 243, 244, 246, 249, 261, 262, 263
    # Bronx: 3, 5, 6, 41, 42, 43, 45, 48, 50, 68, 74, 75, 79, 87, 88, 90, 100, 103, 104, 105, 107, 113, 114, 116, 120, 125, 127, 128, 137, 140, 141, 142, 143, 144, 148, 151, 152, 153, 158, 161, 162, 163, 164, 166, 170, 186, 194, 202, 209, 211, 229, 230, 231, 232, 233, 234, 236, 237, 238, 239, 243, 244, 246, 249, 261, 262, 263
    # Staten Island: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22

    # Simplified borough mapping by zone ID ranges
    df = df.withColumn("pickup_borough",
        F.when(F.col("PULocationID").between(1, 10), "Staten Island")
         .when(F.col("PULocationID").between(11, 50), "Brooklyn")
         .when(F.col("PULocationID").between(51, 150), "Queens")
         .when(F.col("PULocationID").between(151, 220), "Manhattan")
         .when(F.col("PULocationID").between(221, 265), "Bronx")
         .otherwise("Unknown"))

    # Trip duration in minutes
    df = df.withColumn("trip_duration",
        (F.unix_timestamp("tpep_dropoff_datetime") - F.unix_timestamp("tpep_pickup_datetime")) / 60)

    # Average speed (mph)
    df = df.withColumn("avg_speed",
        F.when(F.col("trip_duration") > 0,
               F.col("trip_distance") / (F.col("trip_duration") / 60))
         .otherwise(0))

    # Airport pickups (JFK=132, LGA=138, EWR=1)
    df = df.withColumn("is_airport",
        F.when(F.col("PULocationID").isin([1, 132, 138]), 1).otherwise(0))

    return df


def add_historical_features(df):
    """Add historical aggregate features using window functions."""
    print("Adding historical features...")

    # Daily aggregates by zone
    daily_zone = df.groupBy("pickup_date", "PULocationID", "pickup_borough").agg(
        F.sum("total_amount").alias("daily_revenue"),
        F.count("*").alias("daily_trips"),
        F.avg("trip_distance").alias("avg_distance"),
        F.avg("trip_duration").alias("avg_duration")
    )

    # 7-day moving averages
    window_7d = (Window.partitionBy("PULocationID")
        .orderBy("pickup_date")
        .rowsBetween(-7, -1))

    daily_zone = (daily_zone
        .withColumn("revenue_ma_7d", F.avg("daily_revenue").over(window_7d))
        .withColumn("trips_ma_7d", F.avg("daily_trips").over(window_7d))
        .withColumn("revenue_same_day_lw",
            F.lag("daily_revenue", 7).over(Window.partitionBy("PULocationID").orderBy("pickup_date")))
        .withColumn("trips_same_day_lw",
            F.lag("daily_trips", 7).over(Window.partitionBy("PULocationID").orderBy("pickup_date")))
    )

    # Join back to original
    df = df.join(
        daily_zone,
        on=["pickup_date", "PULocationID", "pickup_borough"],
        how="left"
    )

    return df


def create_target_variables(df):
    """Create 7-day ahead target variables."""
    print("Creating target variables...")

    # For training, we need to create targets: sum of revenue/trips for next 7 days
    # This requires looking ahead, which we do with window functions

    # First aggregate to daily by zone
    daily_zone = df.groupBy("pickup_date", "PULocationID", "pickup_borough").agg(
        F.sum("total_amount").alias("daily_revenue"),
        F.count("*").alias("daily_trips")
    )

    # Create 7-day forward sums
    window_7d_forward = (Window.partitionBy("PULocationID")
        .orderBy("pickup_date")
        .rowsBetween(1, 7))

    daily_zone = (daily_zone
        .withColumn("total_amount_7d", F.sum("daily_revenue").over(window_7d_forward))
        .withColumn("trip_count_7d", F.sum("daily_trips").over(window_7d_forward))
    )

    # Join back
    df = df.join(
        daily_zone.select("pickup_date", "PULocationID", "total_amount_7d", "trip_count_7d"),
        on=["pickup_date", "PULocationID"],
        how="left"
    )

    return df


def save_features(df, output_path):
    """Save features to parquet."""
    print(f"Saving features to {output_path}...")

    # Select final columns
    feature_cols = [
        # Keys
        "pickup_date", "PULocationID", "DOLocationID", "pickup_borough",
        # Temporal
        "hour_of_day", "day_of_week", "day_of_month", "month", "quarter", "year",
        "is_weekend", "is_rush_hour", "is_holiday", "time_of_day",
        # Geospatial
        "trip_distance", "trip_duration", "avg_speed", "is_airport",
        # Historical
        "daily_revenue", "daily_trips", "revenue_ma_7d", "trips_ma_7d",
        "revenue_same_day_lw", "trips_same_day_lw",
        # Targets
        "total_amount_7d", "trip_count_7d"
    ]

    df_features = df.select(*feature_cols).dropDuplicates(["pickup_date", "PULocationID", "hour_of_day"])

    # Save as parquet
    df_features.write.mode("overwrite").parquet(output_path)

    print(f"Saved {df_features.count():,} feature records")
    return df_features


def main():
    global METRICS
    start_time = time.time()

    print("=== NYC Taxi Feature Engineering ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Input: {RAW_PATH}")
    print(f"Output: {FEATURES_PATH}")
    print(f"Pushgateway: {PUSHGATEWAY_URL}")
    print()

    # Create Spark session
    spark = create_spark_session()

    # Pipeline with timing
    t0 = time.time()
    df = load_raw_data(spark)
    raw_count = df.count()
    push_metric('spark_feature_raw_records', raw_count)
    print(f"  Raw data load: {time.time() - t0:.2f}s")

    t0 = time.time()
    df = add_temporal_features(df)
    print(f"  Temporal features: {time.time() - t0:.2f}s")

    t0 = time.time()
    df = add_geospatial_features(df)
    print(f"  Geospatial features: {time.time() - t0:.2f}s")

    t0 = time.time()
    df = add_historical_features(df)
    print(f"  Historical features: {time.time() - t0:.2f}s")

    t0 = time.time()
    df = create_target_variables(df)
    print(f"  Target variables: {time.time() - t0:.2f}s")

    # Save
    t0 = time.time()
    df_features = save_features(df, FEATURES_PATH)
    feature_count = df_features.count()
    print(f"  Save features: {time.time() - t0:.2f}s")

    # Show sample
    print("\nSample features:")
    df_features.show(5, truncate=False)

    # Calculate total duration
    duration = time.time() - start_time

    # Push final metrics
    push_metric('spark_feature_engineering_duration_seconds', duration)
    push_metric('spark_feature_engineering_raw_records', raw_count)
    push_metric('spark_feature_engineering_feature_records', feature_count)
    push_metric('spark_feature_engineering_success', 1)

    print(f"\nTotal duration: {duration:.2f}s")
    print(f"Raw records: {raw_count:,}")
    print(f"Feature records: {feature_count:,}")

    spark.stop()
    print("\nDone!")

    return 0


if __name__ == "__main__":
    sys.exit(main())
