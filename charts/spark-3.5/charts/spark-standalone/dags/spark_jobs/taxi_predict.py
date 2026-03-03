#!/usr/bin/env python3
"""
NYC Taxi Prediction - Generate 7-day forecasts

Loads trained models from MinIO and generates predictions.

Usage (in cluster):
    spark-submit --master spark://scenario2-spark-35-standalone-master:7077 \
        taxi_predict.py
"""

import os
import pickle
import socket
import sys
from datetime import datetime, timedelta

import pandas as pd

# Configuration
MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")
MODEL_VERSION = os.environ.get("MODEL_VERSION", datetime.now().strftime("%Y%m%d"))


def get_pod_ip():
    """Get pod IP address."""
    try:
        return socket.gethostbyname(socket.gethostname())
    except:
        return "127.0.0.1"


def load_model_from_minio(borough):
    """Load trained model from MinIO."""
    import boto3
    from botocore.client import Config

    s3 = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=Config(signature_version="s3v4"),
    )

    model_key = f"taxi-predictor/v{MODEL_VERSION}/{borough.lower().replace(' ', '_')}.pkl"
    print(f"Loading model from s3a://ml-models/{model_key}")

    response = s3.get_object(Bucket="ml-models", Key=model_key)
    models = pickle.loads(response["Body"].read())

    return models


def generate_forecast(models):
    """Generate 7-day forecast using trained models."""
    model_revenue = models["revenue"]
    model_trips = models["trips"]
    feature_cols = models["feature_cols"]
    borough = models["borough"]

    print(f"Generating 7-day forecast for {borough}...")

    # Generate forecast dates (next 7 days)
    forecast_dates = [(datetime.now() + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(1, 8)]

    # Create feature vectors for each day
    # Using average/median values from historical data (simplified)
    predictions = []
    for i, forecast_date in enumerate(forecast_dates):
        # Create synthetic features based on day of week
        day_of_week = (datetime.strptime(forecast_date, "%Y-%m-%d").weekday() + 1) % 7 + 1
        is_weekend = 1 if day_of_week in [1, 7] else 0

        # Build feature vector and adapt to training schema
        full_defaults = {
            "hour_of_day": 12,
            "day_of_week": day_of_week,
            "day_of_month": int(forecast_date.split("-")[2]),
            "month": int(forecast_date.split("-")[1]),
            "quarter": (int(forecast_date.split("-")[1]) - 1) // 3 + 1,
            "is_weekend": is_weekend,
            "is_rush_hour": 0,
            "is_holiday": 0,
            "trip_distance": 3.5,
            "trip_duration": 15.0,
            "avg_speed": 14.0,
            "is_airport": 0,
            "daily_revenue": 5000,
            "daily_trips": 200,
            "revenue_ma_7d": 35000,
            "trips_ma_7d": 1400,
            "PULocationID": 138,
            "avg_distance": 3.5,
        }

        X = pd.DataFrame([{col: full_defaults.get(col, 0) for col in feature_cols}])

        pred_revenue = model_revenue.predict(X)[0]
        pred_trips = model_trips.predict(X)[0]

        # Ensure non-negative predictions
        pred_revenue = max(0, pred_revenue)
        pred_trips = max(0, int(pred_trips))

        predictions.append(
            {
                "forecast_date": forecast_date,
                "borough": borough,
                "predicted_revenue": round(pred_revenue, 2),
                "predicted_trips": pred_trips,
                "model_version": f"v{MODEL_VERSION}",
                "model_type": models.get("model_type", "GradientBoostingRegressor"),
                "mape_revenue": models.get("mape_revenue", "N/A"),
                "mape_trips": models.get("mape_trips", "N/A"),
                "generated_at": datetime.now().isoformat(),
            }
        )

    return predictions


def save_predictions_to_minio(all_predictions):
    """Save predictions to MinIO as CSV."""
    import boto3

    s3 = boto3.client(
        "s3", endpoint_url=MINIO_ENDPOINT, aws_access_key_id=MINIO_ACCESS_KEY, aws_secret_access_key=MINIO_SECRET_KEY
    )

    df = pd.DataFrame(all_predictions)
    csv_buffer = df.to_csv(index=False)

    prediction_key = f"predictions/v{MODEL_VERSION}/7day_forecast.csv"
    s3.put_object(Bucket="nyc-taxi", Key=prediction_key, Body=csv_buffer)

    print(f"\nSaved {len(all_predictions)} predictions to s3a://nyc-taxi/{prediction_key}")
    return prediction_key


def main():
    print("=== NYC Taxi 7-Day Forecast ===")
    print(f"MinIO: {MINIO_ENDPOINT}")
    print(f"Model Version: {MODEL_VERSION}")
    print()

    # Boroughs to predict
    boroughs = ["Queens", "Brooklyn", "Staten Island", "Manhattan", "Bronx"]

    # Generate predictions for each borough
    all_predictions = []

    for borough in boroughs:
        try:
            models = load_model_from_minio(borough)
            predictions = generate_forecast(models)
            all_predictions.extend(predictions)

            # Print sample
            print(f"\n  {borough} - First 3 days:")
            for p in predictions[:3]:
                print(f"    {p['forecast_date']}: Revenue=${p['predicted_revenue']:.2f}, Trips={p['predicted_trips']}")
        except Exception as e:
            print(f"  Error generating forecast for {borough}: {e}")
            continue

    # Save all predictions
    if all_predictions:
        prediction_key = save_predictions_to_minio(all_predictions)

        # Print summary
        print("\n=== Forecast Summary ===")
        df = pd.DataFrame(all_predictions)
        summary = df.groupby("borough").agg({"predicted_revenue": "sum", "predicted_trips": "sum"}).round(2)

        print(summary)
        print(f"\nTotal 7-day revenue forecast: ${df['predicted_revenue'].sum():,.2f}")
        print(f"Total 7-day trips forecast: {int(df['predicted_trips'].sum()):,}")

    print("\nDone!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
