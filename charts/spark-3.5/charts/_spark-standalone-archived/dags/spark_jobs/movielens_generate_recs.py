#!/usr/bin/env python3
"""
MovieLens Generate Recommendations - Top-N per User

Loads ALS model and generates top-N movie recommendations per user.

Usage (in cluster):
    spark-submit --master spark://spark-infra-spark-standalone-master:7077 \
        movielens_generate_recs.py

Environment variables:
    MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY
"""

import os
import socket
import sys

from pyspark.ml.recommendation import ALSModel
from pyspark.sql import SparkSession

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")

MODEL_PATH = "s3a://movielens/models/als/"
RECS_PATH = "s3a://movielens/recommendations/"
TOP_N = 10


def get_pod_ip() -> str:
    """Get pod IP address."""
    try:
        return socket.gethostbyname(socket.gethostname())
    except OSError:
        return "127.0.0.1"


def create_spark_session() -> SparkSession:
    """Create Spark session with MinIO and event log config."""
    pod_ip = get_pod_ip()
    print(f"Pod IP: {pod_ip}")

    builder = (
        SparkSession.builder.appName("movielens-generate-recs")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
        .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.eventLog.enabled", "true")
        .config("spark.eventLog.dir", "s3a://spark-logs/events/")
    )
    spark = builder.getOrCreate()
    print(f"Spark session created: {spark.sparkContext.applicationId}")
    return spark


def generate_and_save(spark: SparkSession) -> None:
    """Load ALS model, generate top-N recs per user, save to MinIO."""
    print(f"Loading model from {MODEL_PATH}...")
    model = ALSModel.load(MODEL_PATH)

    print(f"Generating top-{TOP_N} recommendations per user...")
    recs = model.recommendForAllUsers(TOP_N)

    print(f"Saving recommendations to {RECS_PATH}...")
    recs.write.mode("overwrite").parquet(RECS_PATH)
    print("Recommendations saved.")


def main() -> int:
    print("=== MovieLens Generate Recommendations ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Model: {MODEL_PATH}")
    print(f"Output: {RECS_PATH}")
    print()

    spark = create_spark_session()
    generate_and_save(spark)
    spark.stop()
    print("\nDone!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
