#!/usr/bin/env python3
"""
Citibike Feature Engineering - Spark pipeline.
Reads real trip data from citibike/raw/ (parquet from upload-citibike-sample.sh).
Falls back to synthetic data if raw/ is empty.
"""
import os
import socket

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")


def get_pod_ip() -> str:
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "127.0.0.1"


def main() -> None:
    pod_ip = get_pod_ip()
    spark = (
        SparkSession.builder.appName("citibike-feature-engineering")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )

    raw_path = "s3a://citibike/raw/"
    features_path = "s3a://citibike/features/trips"

    try:
        # Try to read real data (parquet from upload-citibike-sample.sh)
        df = spark.read.parquet(raw_path)
        if df.count() == 0:
            raise ValueError("Empty raw data")
        # Real Citibike schema: ride_id, started_at, ended_at, start_station_id, end_station_id, ...
        # Compute duration from timestamps
        df = df.withColumn(
            "duration_sec",
            (F.unix_timestamp(F.col("ended_at")) - F.unix_timestamp(F.col("started_at"))).cast("int"),
        )
        df = df.withColumn("duration_min", F.col("duration_sec") / 60)
        # Select columns expected by statistics; coalesce null station ids
        df = df.filter(F.col("duration_sec") > 0).select(
            F.col("ride_id").alias("trip_id"),
            F.coalesce(F.col("start_station_id").cast("int"), F.lit(0)).alias("start_station_id"),
            F.coalesce(F.col("end_station_id").cast("int"), F.lit(0)).alias("end_station_id"),
            "duration_sec",
            "duration_min",
        )
        print(f"Read {df.count()} real trips from {raw_path}")
    except Exception as e:
        print(f"Raw data not available ({e}), using synthetic fallback")
        from pyspark.sql.types import IntegerType, StructField, StructType

        schema = StructType([
            StructField("trip_id", IntegerType()),
            StructField("start_station_id", IntegerType()),
            StructField("end_station_id", IntegerType()),
            StructField("duration_sec", IntegerType()),
        ])
        df = spark.createDataFrame(
            [(i, (i % 10) + 1, (i % 10) + 2, 300 + i) for i in range(100)],
            schema=schema,
        )
        df = df.withColumn("duration_min", F.col("duration_sec") / 60)

    df.write.mode("overwrite").parquet(features_path)
    print(f"Wrote {df.count()} features to {features_path}")

    spark.stop()


if __name__ == "__main__":
    main()
