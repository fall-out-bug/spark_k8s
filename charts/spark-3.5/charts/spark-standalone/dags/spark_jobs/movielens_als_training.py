#!/usr/bin/env python3
"""
MovieLens ALS Training - Collaborative Filtering Model

Trains ALS model on MovieLens u.data and saves to MinIO.

Usage (in cluster):
    spark-submit --master spark://spark-infra-spark-standalone-master:7077 \
        movielens_als_training.py

Environment variables:
    MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY
"""

import os
import socket
import sys

from pyspark.ml.recommendation import ALS
from pyspark.sql import SparkSession
from pyspark.sql.types import DoubleType, IntegerType, LongType, StructField, StructType

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")

RAW_PATH = "s3a://movielens/raw/"
MODEL_PATH = "s3a://movielens/models/als/"

RATINGS_SCHEMA = StructType(
    [
        StructField("userId", IntegerType(), True),
        StructField("movieId", IntegerType(), True),
        StructField("rating", DoubleType(), True),
        StructField("timestamp", LongType(), True),
    ]
)


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
        SparkSession.builder.appName("movielens-als-training")
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


def load_ratings(spark: SparkSession):
    """Load u.data (tab-separated: userId, movieId, rating, timestamp)."""
    path = RAW_PATH + "u.data"
    print(f"Loading ratings from {path}...")
    df = spark.read.csv(path, sep="\t", schema=RATINGS_SCHEMA)
    print(f"Loaded {df.count():,} ratings")
    return df


def train_and_save(spark: SparkSession) -> None:
    """Train ALS model and save to MinIO."""
    df = load_ratings(spark)
    df.cache()

    als = ALS(
        maxIter=10,
        regParam=0.01,
        userCol="userId",
        itemCol="movieId",
        ratingCol="rating",
        coldStartStrategy="drop",
        nonnegative=True,
    )
    model = als.fit(df)

    print(f"Saving model to {MODEL_PATH}...")
    model.write().overwrite().save(MODEL_PATH)
    print("Model saved.")

    df.unpersist()


def main() -> int:
    print("=== MovieLens ALS Training ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Input: {RAW_PATH}u.data")
    print(f"Output: {MODEL_PATH}")
    print()

    spark = create_spark_session()
    train_and_save(spark)
    spark.stop()
    print("\nDone!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
