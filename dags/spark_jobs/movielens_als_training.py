#!/usr/bin/env python3
"""
MovieLens ALS Training - Spark ML pipeline.
Trains ALS model on ratings, saves to s3a://movielens/models/.
"""
import os
import socket

from pyspark.ml.recommendation import ALS
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
        SparkSession.builder.appName("movielens-als-training")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )

    ratings = spark.read.parquet("s3a://movielens/features/ratings")
    als = ALS(maxIter=5, regParam=0.01, userCol="userId", itemCol="movieId", ratingCol="rating")
    model = als.fit(ratings)
    model.save("s3a://movielens/models/als")
    print("ALS model saved to s3a://movielens/models/als")

    spark.stop()


if __name__ == "__main__":
    main()
