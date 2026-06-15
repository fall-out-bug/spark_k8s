#!/usr/bin/env python3
"""
MovieLens Feature Engineering - Spark pipeline.
Reads raw u.data, creates user/movie features for ALS.
"""
import os
import socket

from pyspark.sql import SparkSession

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")


def get_pod_ip():
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "127.0.0.1"


def main():
    pod_ip = get_pod_ip()
    spark = (
        SparkSession.builder.appName("movielens-feature-engineering")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )

    # Read u.data (userId, movieId, rating, timestamp)
    ratings = spark.read.csv(
        "s3a://movielens/raw/u.data",
        sep="\t",
        schema="userId INT, movieId INT, rating INT, timestamp LONG",
    )
    ratings = ratings.drop("timestamp")
    ratings.write.mode("overwrite").parquet("s3a://movielens/features/ratings")
    print(f"Wrote {ratings.count()} ratings to features/ratings")

    spark.stop()


if __name__ == "__main__":
    main()
