#!/usr/bin/env python3
"""
MovieLens Generate Recommendations - Spark pipeline.
Loads ALS model, generates top-N per user, writes to s3a://movielens/recommendations/.
"""
import os
import socket

from pyspark.ml.recommendation import ALSModel
from pyspark.sql import SparkSession

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")


def get_pod_ip() -> str:
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "127.0.0.1"


def main() -> None:
    pod_ip = get_pod_ip()
    spark = (
        SparkSession.builder.appName("movielens-generate-recs")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", os.environ.get("MINIO_ACCESS_KEY", ""))
        .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("MINIO_SECRET_KEY", ""))
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )

    model = ALSModel.load("s3a://movielens/models/als")
    recs = model.recommendForAllUsers(10)
    recs.write.mode("overwrite").parquet("s3a://movielens/recommendations/recs")
    print(f"Wrote recommendations for {recs.count()} users")

    spark.stop()


if __name__ == "__main__":
    main()
