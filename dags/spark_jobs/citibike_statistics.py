#!/usr/bin/env python3
"""
Citibike Statistics - Spark pipeline.
Generates aggregated stats from trip features.
"""
import os
import socket

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")


def get_pod_ip():
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "127.0.0.1"


def main():
    pod_ip = get_pod_ip()
    spark = (
        SparkSession.builder.appName("citibike-statistics")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )

    trips = spark.read.parquet("s3a://citibike/features/trips")
    stats = trips.agg(
        F.count("*").alias("total_trips"),
        F.avg("duration_min").alias("avg_duration_min"),
        F.sum("duration_sec").alias("total_duration_sec"),
    )
    stats.write.mode("overwrite").parquet("s3a://citibike/statistics/summary")
    print(f"Wrote statistics: {stats.collect()}")

    spark.stop()


if __name__ == "__main__":
    main()
