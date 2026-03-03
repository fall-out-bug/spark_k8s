#!/usr/bin/env python3
"""
MovieLens Feature Engineering - Collaborative Filtering

Generates user-movie interaction features for recommendation.

Usage (in cluster):
    spark-submit --master spark://spark-infra-spark-standalone-master:7077 \
        movielens_feature_engineering.py

Environment variables:
    MINIO_ENDPOINT: MinIO endpoint (default: http://minio.spark-infra.svc.cluster.local:9000)
    MINIO_ACCESS_KEY: Access key (default: minioadmin)
    MINIO_SECRET_KEY: Secret key (default: minioadmin)
"""

import os
import socket
import sys
from datetime import datetime

from pyspark.ml.evaluation import RegressionEvaluator
from pyspark.ml.recommendation import ALS
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType, IntegerType, LongType, StructField, StructType

RATINGS_SCHEMA = StructType(
    [
        StructField("userId", IntegerType(), True),
        StructField("movieId", IntegerType(), True),
        StructField("rating", DoubleType(), True),
        StructField("timestamp", LongType(), True),
    ]
)

# Configuration
MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")

RAW_PATH = "s3a://movielens/raw/"
FEATURES_PATH = "s3a://movielens/features/"


def get_pod_ip() -> str:
    """Get pod IP address."""
    try:
        return socket.gethostbyname(socket.gethostname())
    except OSError:
        return "127.0.0.1"


def create_spark_session():
    """Create Spark session with MinIO config."""
    pod_ip = get_pod_ip()
    print(f"Pod IP: {pod_ip}")

    spark = (
        SparkSession.builder.appName("movielens-feature-engineering")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
        .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.sql.adaptive.enabled", "true")
        .getOrCreate()
    )

    print(f"Spark session created: {spark.sparkContext.applicationId}")
    return spark


def load_ratings_data(spark: SparkSession):
    """Load MovieLens u.data (tab-separated: userId, movieId, rating, timestamp)."""
    path = RAW_PATH + "u.data"
    print(f"Loading ratings from {path}...")

    df = spark.read.csv(path, sep="\t", schema=RATINGS_SCHEMA)

    print(f"Loaded {df.count():,} ratings")
    print(f"Unique users: {df.select('userId').distinct().count()}")
    print(f"Unique movies: {df.select('movieId').distinct().count()}")

    return df


def create_user_features(df):
    """Create user-level features."""

    user_features = df.groupBy("userId").agg(
        F.count("movieId").alias("num_ratings"),
        F.avg("rating").alias("avg_rating"),
        F.stddev("rating").alias("std_rating"),
        F.min("rating").alias("min_rating"),
        F.max("rating").alias("max_rating"),
    )

    return user_features


def create_movie_features(df):
    """Create movie-level features."""

    movie_features = df.groupBy("movieId").agg(
        F.count("userId").alias("num_ratings"),
        F.avg("rating").alias("avg_rating"),
        F.stddev("rating").alias("std_rating"),
        F.min("rating").alias("min_rating"),
        F.max("rating").alias("max_rating"),
    )

    return movie_features


def train_als_model(df):
    """Train ALS collaborative filtering model."""
    # Split data
    train, test = df.randomSplit([0.8, 0.2], seed=42)

    # Train ALS model
    als = ALS(
        maxIter=10,
        regParam=0.01,
        userCol="userId",
        itemCol="movieId",
        ratingCol="rating",
        coldStartStrategy="drop",
        nonnegative=True,
    )

    model = als.fit(train)

    # Evaluate
    predictions = model.transform(test)
    evaluator = RegressionEvaluator(metricName="rmse", labelCol="rating", predictionCol="prediction")
    rmse = evaluator.evaluate(predictions)
    print(f"Test RMSE: {rmse:.4f}")

    return model, rmse


def save_features(user_features, movie_features, model_rmse):
    """Save features and metrics to MinIO."""
    # Save user features
    user_features.write.mode("overwrite").parquet(FEATURES_PATH + "user_features/")
    print("Saved user features")

    # Save movie features
    movie_features.write.mode("overwrite").parquet(FEATURES_PATH + "movie_features/")
    print("Saved movie features")

    # Save metrics
    metrics = {
        "model_rmse": model_rmse,
        "timestamp": datetime.now().isoformat(),
        "num_users": user_features.count(),
        "num_movies": movie_features.count(),
    }

    spark = SparkSession.getActiveSession()
    spark.sparkContext.parallelize([str(metrics)]).saveAsTextFile(FEATURES_PATH + "metrics.txt")


def main():
    print("=== MovieLens Feature Engineering ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Input: {RAW_PATH}")
    print(f"Output: {FEATURES_PATH}")
    print()

    # Create Spark session
    spark = create_spark_session()

    # Load data
    df = load_ratings_data(spark)
    df.cache()

    # Create features
    user_features = create_user_features(df)
    movie_features = create_movie_features(df)

    # Train model for validation
    model, rmse = train_als_model(df)

    # Save features
    save_features(user_features, movie_features, rmse)

    spark.stop()
    print("\nDone!")

    return 0


if __name__ == "__main__":
    sys.exit(main())
