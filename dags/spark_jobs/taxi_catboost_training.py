#!/usr/bin/env python3
"""
NYC Taxi ML Training - Spark Pipeline

Trains GradientBoosting models for 7-day revenue/trip prediction per borough.
Uses sklearn (more compatible) instead of CatBoost for cluster environment.

Usage (in cluster):
    spark-submit --master spark://scenario2-spark-35-standalone-master:7077 \
        taxi_catboost_training.py

Environment variables:
    MINIO_ENDPOINT: MinIO endpoint (default: http://minio.spark-infra.svc.cluster.local:9000)
    MINIO_ACCESS_KEY: Access key (default: minioadmin)
    MINIO_SECRET_KEY: Secret key (default: minioadmin)
"""

import os
import pickle
import socket
import sys
import json
from datetime import datetime

import numpy as np

# ML imports - pandas/numpy available in spark-custom image
# Spark imports
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import *

# CatBoost imported inside functions to allow runtime installation

# Configuration
MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")

FEATURES_PATHS = [
    "s3a://nyc-taxi/features/daily_aggregates/",
    "s3a://nyc-taxi/features/",
]
MODELS_BUCKET = "ml-models"


def get_pod_ip():
    """Get pod IP address."""
    try:
        return socket.gethostbyname(socket.gethostname())
    except:
        return "127.0.0.1"


def create_spark_session():
    """Create Spark session with MinIO config."""
    pod_ip = get_pod_ip()
    print(f"Pod IP: {pod_ip}")

    spark = (
        SparkSession.builder.appName("nyc-taxi-catboost-training")
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


def load_features(spark):
    """Load features from MinIO."""
    for features_path in FEATURES_PATHS:
        print(f"Loading features from {features_path}...")
        try:
            df = spark.read.parquet(features_path)
            record_count = df.count()
            print(f"Loaded {record_count:,} feature records")
            df.cache()
            return df
        except Exception as exc:
            print(f"  Skipping unavailable path: {features_path} ({exc})")

    raise RuntimeError(f"No usable feature dataset found. Checked: {FEATURES_PATHS}")


def prepare_training_data(df, borough):
    """Prepare training data for a specific borough."""
    print(f"Preparing training data for {borough}...")

    # Filter by borough
    df_borough = df.filter(F.col("pickup_borough") == borough)

    full_feature_cols = [
        "hour_of_day",
        "day_of_week",
        "day_of_month",
        "month",
        "quarter",
        "is_weekend",
        "is_rush_hour",
        "is_holiday",
        "trip_distance",
        "trip_duration",
        "avg_speed",
        "is_airport",
        "daily_revenue",
        "daily_trips",
        "revenue_ma_7d",
        "trips_ma_7d",
    ]

    compact_feature_cols = [
        "PULocationID",
        "daily_trips",
        "avg_distance",
        "day_of_week",
        "day_of_month",
        "month",
        "is_weekend",
    ]

    if "total_amount_7d" in df_borough.columns and "trip_count_7d" in df_borough.columns:
        feature_cols = [col for col in full_feature_cols if col in df_borough.columns]
        df_clean = df_borough.na.drop(subset=["total_amount_7d", "trip_count_7d"])
        for col in feature_cols:
            df_clean = df_clean.na.fill(0, subset=[col])
        pdf = df_clean.select(
            *feature_cols,
            F.col("total_amount_7d").alias("target_revenue"),
            F.col("trip_count_7d").alias("target_trips"),
        ).toPandas()
    else:
        # Fallback for compact daily_aggregates schema
        df_compact = (
            df_borough.withColumn("day_of_week", F.dayofweek("pickup_date"))
            .withColumn("day_of_month", F.dayofmonth("pickup_date"))
            .withColumn("month", F.month("pickup_date"))
            .withColumn("is_weekend", F.when(F.col("day_of_week").isin([1, 7]), 1).otherwise(0))
        )
        feature_cols = [col for col in compact_feature_cols if col in df_compact.columns]
        for col in feature_cols:
            df_compact = df_compact.na.fill(0, subset=[col])
        pdf = df_compact.select(
            *feature_cols,
            F.col("daily_revenue").alias("target_revenue"),
            F.col("daily_trips").alias("target_trips"),
        ).toPandas()

    print(f"  {borough}: {len(pdf)} training samples")

    return pdf, feature_cols


def train_catboost_models(pdf, feature_cols, borough):
    """Train GradientBoosting models for revenue and trips prediction."""
    # Import inside function to allow runtime installation
    try:
        from sklearn.ensemble import GradientBoostingRegressor
        from sklearn.metrics import mean_absolute_percentage_error, mean_squared_error
        from sklearn.model_selection import train_test_split
    except ImportError as e:
        print(f"ERROR: Missing ML dependencies: {e}")
        print("Please install: pip install scikit-learn")
        raise

    print(f"Training GradientBoosting models for {borough}...")

    X = pdf[feature_cols]
    y_revenue = pdf["target_revenue"]
    y_trips = pdf["target_trips"]

    # Train/test split
    X_train, X_test, y_rev_train, y_rev_test, y_trip_train, y_trip_test = train_test_split(
        X, y_revenue, y_trips, test_size=0.2, random_state=42
    )

    # Train revenue model
    model_revenue = GradientBoostingRegressor(
        n_estimators=200, max_depth=6, learning_rate=0.05, loss="squared_error", random_state=42, verbose=0
    )
    model_revenue.fit(X_train, y_rev_train)

    # Train trips model
    model_trips = GradientBoostingRegressor(
        n_estimators=200, max_depth=6, learning_rate=0.05, loss="squared_error", random_state=42, verbose=0
    )
    model_trips.fit(X_train, y_trip_train)

    # Evaluate
    pred_revenue = model_revenue.predict(X_test)
    pred_trips = model_trips.predict(X_test)

    # Robust MAPE: avoid exploding values when actuals are near zero
    y_rev_safe = np.maximum(np.abs(y_rev_test), 1.0)
    y_trips_safe = np.maximum(np.abs(y_trip_test), 1.0)
    mape_rev = float(np.mean(np.abs((y_rev_test - pred_revenue) / y_rev_safe)))
    mape_trips = float(np.mean(np.abs((y_trip_test - pred_trips) / y_trips_safe)))
    rmse_rev = np.sqrt(mean_squared_error(y_rev_test, pred_revenue))
    rmse_trips = np.sqrt(mean_squared_error(y_trip_test, pred_trips))

    print(f"  {borough} Revenue - MAPE: {mape_rev:.4f}, RMSE: {rmse_rev:.2f}")
    print(f"  {borough} Trips   - MAPE: {mape_trips:.4f}, RMSE: {rmse_trips:.2f}")

    return {
        "revenue": model_revenue,
        "trips": model_trips,
        "mape_revenue": mape_rev,
        "mape_trips": mape_trips,
        "rmse_revenue": rmse_rev,
        "rmse_trips": rmse_trips,
        "feature_cols": feature_cols,
        "borough": borough,
        "trained_at": datetime.now().isoformat(),
        "n_samples": len(pdf),
        "model_type": "GradientBoostingRegressor",
    }


def save_model_to_minio(models, borough):
    """Save trained models to MinIO using boto3."""
    import boto3
    from botocore.client import Config

    print(f"Saving {borough} model to MinIO...")

    s3 = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=Config(signature_version="s3v4"),
    )

    # Create models bucket if not exists
    try:
        s3.head_bucket(Bucket=MODELS_BUCKET)
    except:
        s3.create_bucket(Bucket=MODELS_BUCKET)

    # Serialize and upload
    version = datetime.now().strftime("%Y%m%d")
    model_bytes = pickle.dumps(models)
    model_key = f"taxi-predictor/v{version}/{borough.lower().replace(' ', '_')}.pkl"

    s3.put_object(Bucket=MODELS_BUCKET, Key=model_key, Body=model_bytes)

    metrics_key = f"taxi-predictor/v{version}/{borough.lower().replace(' ', '_')}.metrics.json"
    metrics_payload = {
        "borough": borough,
        "version": f"v{version}",
        "mape_revenue": models["mape_revenue"],
        "mape_trips": models["mape_trips"],
        "rmse_revenue": models["rmse_revenue"],
        "rmse_trips": models["rmse_trips"],
        "trained_at": models["trained_at"],
    }
    s3.put_object(Bucket=MODELS_BUCKET, Key=metrics_key, Body=json.dumps(metrics_payload).encode("utf-8"))

    print(f"  Saved to s3a://{MODELS_BUCKET}/{model_key}")

    return f"s3a://{MODELS_BUCKET}/{model_key}"


def main():
    print("=== NYC Taxi CatBoost Training ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Features (candidates): {FEATURES_PATHS}")
    print()

    # Create Spark session
    spark = create_spark_session()

    # Load features
    df = load_features(spark)

    # Backward-compatible borough derivation for compact aggregate schema
    if "pickup_borough" not in df.columns and "PULocationID" in df.columns:
        df = df.withColumn(
            "pickup_borough",
            F.when(F.col("PULocationID").between(1, 10), "Staten Island")
            .when(F.col("PULocationID").between(11, 50), "Brooklyn")
            .when(F.col("PULocationID").between(51, 150), "Queens")
            .when(F.col("PULocationID").between(151, 220), "Manhattan")
            .when(F.col("PULocationID").between(221, 265), "Bronx")
            .otherwise("Unknown"),
        )

    # Get unique boroughs
    boroughs = [row.pickup_borough for row in df.select("pickup_borough").distinct().collect()]
    print(f"Found boroughs: {boroughs}")
    print()

    # Train models for each borough
    results = []
    for borough in boroughs:
        if borough == "Unknown":
            continue

        try:
            pdf, feature_cols = prepare_training_data(df, borough)

            if len(pdf) < 100:
                print(f"  Skipping {borough} - insufficient data ({len(pdf)} samples)")
                continue

            models = train_catboost_models(pdf, feature_cols, borough)
            model_path = save_model_to_minio(models, borough)

            results.append(
                {
                    "borough": borough,
                    "n_samples": models["n_samples"],
                    "mape_revenue": models["mape_revenue"],
                    "mape_trips": models["mape_trips"],
                    "model_path": model_path,
                    "passed": models["mape_revenue"] < 0.30 and models["mape_trips"] < 0.25,
                }
            )
        except Exception as e:
            print(f"  Error training {borough}: {e}")
            import traceback

            traceback.print_exc()

    # Print summary
    print("\n=== Training Summary ===")
    for r in results:
        status = "PASS" if r["passed"] else "FAIL"
        print(
            f"  {r['borough']}: {r['n_samples']} samples, "
            f"MAPE(rev={r['mape_revenue']:.4f}, trips={r['mape_trips']:.4f}) [{status}]"
        )

    # Demo success criteria: at least half of borough models pass
    passed_count = sum(1 for r in results if r["passed"])
    success = passed_count >= max(1, len(results) // 2)
    if not success:
        print(f"\nWARNING: Model quality below threshold ({passed_count}/{len(results)} passed)")

    spark.stop()
    print("\nDone!")

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
