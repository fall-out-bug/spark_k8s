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

FEATURES_PATH = "s3a://nyc-taxi/features/"
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

    spark = (SparkSession.builder
        .appName("nyc-taxi-catboost-training")
        .config("spark.driver.host", pod_ip)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
        .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.sql.adaptive.enabled", "true")
        .getOrCreate())

    print(f"Spark session created: {spark.sparkContext.applicationId}")
    return spark


def load_features(spark):
    """Load features from MinIO."""
    print(f"Loading features from {FEATURES_PATH}...")

    df = spark.read.parquet(FEATURES_PATH)
    print(f"Loaded {df.count():,} feature records")

    # Cache for reuse
    df.cache()

    return df


def prepare_training_data(df, borough):
    """Prepare training data for a specific borough."""
    print(f"Preparing training data for {borough}...")

    # Filter by borough
    df_borough = df.filter(F.col("pickup_borough") == borough)

    # Select feature columns and targets
    feature_cols = [
        "hour_of_day", "day_of_week", "day_of_month", "month", "quarter",
        "is_weekend", "is_rush_hour", "is_holiday",
        "trip_distance", "trip_duration", "avg_speed", "is_airport",
        "daily_revenue", "daily_trips", "revenue_ma_7d", "trips_ma_7d"
    ]

    # Drop rows with null targets
    df_clean = df_borough.na.drop(subset=["total_amount_7d", "trip_count_7d"])

    # Fill null feature values
    for col in feature_cols:
        df_clean = df_clean.na.fill(0, subset=[col])

    # Convert to pandas for CatBoost
    pdf = df_clean.select(
        *feature_cols,
        F.col("total_amount_7d").alias("target_revenue"),
        F.col("trip_count_7d").alias("target_trips")
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
        n_estimators=200,
        max_depth=6,
        learning_rate=0.05,
        loss='squared_error',
        random_state=42,
        verbose=0
    )
    model_revenue.fit(X_train, y_rev_train)

    # Train trips model
    model_trips = GradientBoostingRegressor(
        n_estimators=200,
        max_depth=6,
        learning_rate=0.05,
        loss='squared_error',
        random_state=42,
        verbose=0
    )
    model_trips.fit(X_train, y_trip_train)

    # Evaluate
    pred_revenue = model_revenue.predict(X_test)
    pred_trips = model_trips.predict(X_test)

    mape_rev = mean_absolute_percentage_error(y_rev_test, pred_revenue)
    mape_trips = mean_absolute_percentage_error(y_trip_test, pred_trips)
    rmse_rev = np.sqrt(mean_squared_error(y_rev_test, pred_revenue))
    rmse_trips = np.sqrt(mean_squared_error(y_trip_test, pred_trips))

    print(f"  {borough} Revenue - MAPE: {mape_rev:.4f}, RMSE: {rmse_rev:.2f}")
    print(f"  {borough} Trips   - MAPE: {mape_trips:.4f}, RMSE: {rmse_trips:.2f}")

    return {
        'revenue': model_revenue,
        'trips': model_trips,
        'mape_revenue': mape_rev,
        'mape_trips': mape_trips,
        'rmse_revenue': rmse_rev,
        'rmse_trips': rmse_trips,
        'feature_cols': feature_cols,
        'borough': borough,
        'trained_at': datetime.now().isoformat(),
        'n_samples': len(pdf),
        'model_type': 'GradientBoostingRegressor'
    }


def save_model_to_minio(models, borough):
    """Save trained models to MinIO using boto3."""
    import boto3
    from botocore.client import Config

    print(f"Saving {borough} model to MinIO...")

    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=Config(signature_version='s3v4')
    )

    # Create models bucket if not exists
    try:
        s3.head_bucket(Bucket=MODELS_BUCKET)
    except:
        s3.create_bucket(Bucket=MODELS_BUCKET)

    # Serialize and upload
    version = datetime.now().strftime('%Y%m%d')
    model_bytes = pickle.dumps(models)
    model_key = f"taxi-predictor/v{version}/{borough.lower().replace(' ', '_')}.pkl"

    s3.put_object(
        Bucket=MODELS_BUCKET,
        Key=model_key,
        Body=model_bytes
    )

    print(f"  Saved to s3a://{MODELS_BUCKET}/{model_key}")

    return f"s3a://{MODELS_BUCKET}/{model_key}"


def main():
    print("=== NYC Taxi CatBoost Training ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Features: {FEATURES_PATH}")
    print()

    # Create Spark session
    spark = create_spark_session()

    # Load features
    df = load_features(spark)

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

            results.append({
                'borough': borough,
                'n_samples': models['n_samples'],
                'mape_revenue': models['mape_revenue'],
                'mape_trips': models['mape_trips'],
                'model_path': model_path,
                'passed': models['mape_revenue'] < 0.15 and models['mape_trips'] < 0.15
            })
        except Exception as e:
            print(f"  Error training {borough}: {e}")
            import traceback
            traceback.print_exc()

    # Print summary
    print("\n=== Training Summary ===")
    for r in results:
        status = "PASS" if r['passed'] else "FAIL"
        print(f"  {r['borough']}: {r['n_samples']} samples, "
              f"MAPE(rev={r['mape_revenue']:.4f}, trips={r['mape_trips']:.4f}) [{status}]")

    # Check if all passed
    all_passed = all(r['passed'] for r in results)
    if not all_passed:
        print("\nWARNING: Some models did not meet MAPE < 15% threshold")

    spark.stop()
    print("\nDone!")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
