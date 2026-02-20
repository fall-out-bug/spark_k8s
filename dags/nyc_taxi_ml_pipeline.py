"""
NYC Taxi ML Pipeline - Airflow DAG

5-stage pipeline with branching for parallel CatBoost training per borough.

Stages:
1. check_data - Verify data availability in MinIO
2. feature_prep - Run Spark feature engineering
3. train_models - Parallel training per borough (Manhattan, Brooklyn, Queens, Bronx+SI)
4. validate - Validate model performance (MAPE < 15%)
5. predict_save - Generate 7-day forecast and save models

Schedule: Daily at 6am
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.utils.task_group import TaskGroup
from airflow.hooks.base import BaseHook
import os

# Default arguments
default_args = {
    'owner': 'ml-team',
    'depends_on_past': False,
    'start_date': datetime(2026, 2, 20),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Configuration
SPARK_MASTER = "spark://scenario2-spark-35-standalone-master:7077"
MINIO_ENDPOINT = "http://minio.spark-infra.svc.cluster.local:9000"
ML_MODELS_PATH = "s3a://ml-models/taxi-predictor"
PREDICTIONS_PATH = "s3a://nyc-taxi/predictions"


def check_minio_data(**context):
    """Check if required data exists in MinIO."""
    import boto3
    from botocore.client import Config

    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id='minioadmin',
        aws_secret_access_key='minioadmin',
        config=Config(signature_version='s3v4')
    )

    # Check for raw data
    try:
        response = s3.list_objects_v2(Bucket='nyc-taxi', Prefix='raw/')
        file_count = response.get('KeyCount', 0)
        if file_count < 1:
            raise ValueError(f"No data files found in nyc-taxi/raw/")
        print(f"Found {file_count} data files in MinIO")
        return True
    except Exception as e:
        raise ValueError(f"MinIO check failed: {e}")


def train_catboost_borough(borough: str, **context):
    """Train CatBoost model for a specific borough."""
    import pandas as pd
    import pickle
    from io import BytesIO
    import boto3
    from catboost import CatBoostRegressor
    from sklearn.metrics import mean_absolute_percentage_error

    execution_date = context['execution_date'].strftime('%Y%m%d')

    # Load features from MinIO
    print(f"Loading features for {borough}...")

    # Read parquet using pandas + pyarrow
    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id='minioadmin',
        aws_secret_access_key='minioadmin',
    )

    # For now, simulate training with sample data
    # In production, would use Spark to read features

    # Feature columns
    feature_cols = [
        'hour_of_day', 'day_of_week', 'is_weekend', 'is_holiday',
        'month', 'is_rush_hour', 'trip_distance', 'avg_speed',
        'revenue_ma_7d', 'trips_ma_7d', 'revenue_same_day_lw', 'trips_same_day_lw'
    ]

    # Simulated training (in production, load real data)
    # This would be replaced with actual data loading from MinIO

    print(f"Training CatBoost models for {borough}...")

    # Create sample data for demonstration
    import numpy as np
    np.random.seed(42)
    n_samples = 10000

    X_train = pd.DataFrame(np.random.rand(n_samples, len(feature_cols)), columns=feature_cols)
    y_revenue = np.random.rand(n_samples) * 1000 + 500
    y_trips = np.random.rand(n_samples) * 500 + 100

    # Train revenue model
    model_revenue = CatBoostRegressor(
        iterations=500,
        depth=8,
        learning_rate=0.05,
        loss_function='RMSE',
        verbose=False,
        random_seed=42
    )
    model_revenue.fit(X_train, y_revenue, verbose=False)

    # Train trips model
    model_trips = CatBoostRegressor(
        iterations=500,
        depth=8,
        learning_rate=0.05,
        loss_function='RMSE',
        verbose=False,
        random_seed=42
    )
    model_trips.fit(X_train, y_trips, verbose=False)

    # Calculate metrics
    pred_revenue = model_revenue.predict(X_train)
    pred_trips = model_trips.predict(X_train)
    mape_revenue = mean_absolute_percentage_error(y_revenue, pred_revenue)
    mape_trips = mean_absolute_percentage_error(y_trips, pred_trips)

    print(f"{borough} - Revenue MAPE: {mape_revenue:.4f}, Trips MAPE: {mape_trips:.4f}")

    # Save models to MinIO
    models = {
        'revenue': model_revenue,
        'trips': model_trips,
        'mape_revenue': mape_revenue,
        'mape_trips': mape_trips,
        'feature_cols': feature_cols,
        'borough': borough,
        'trained_at': datetime.now().isoformat()
    }

    # Serialize and upload
    model_bytes = pickle.dumps(models)
    model_key = f"taxi-predictor/v{execution_date}/{borough}.pkl"

    s3.put_object(
        Bucket='ml-models',
        Key=model_key,
        Body=model_bytes
    )
    print(f"Saved model to s3a://ml-models/{model_key}")

    return {
        'borough': borough,
        'mape_revenue': mape_revenue,
        'mape_trips': mape_trips
    }


def validate_models(**context):
    """Validate all trained models meet performance threshold."""
    import boto3
    import pickle

    execution_date = context['execution_date'].strftime('%Y%m%d')
    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id='minioadmin',
        aws_secret_access_key='minioadmin',
    )

    boroughs = ['manhattan', 'brooklyn', 'queens', 'bronx_si']
    threshold = 0.15  # 15% MAPE threshold

    results = []
    for borough in boroughs:
        try:
            response = s3.get_object(Bucket='ml-models', Key=f'taxi-predictor/v{execution_date}/{borough}.pkl')
            models = pickle.loads(response['Body'].read())

            mape_rev = models['mape_revenue']
            mape_trips = models['mape_trips']

            passed = mape_rev < threshold and mape_trips < threshold
            results.append({
                'borough': borough,
                'mape_revenue': mape_rev,
                'mape_trips': mape_trips,
                'passed': passed
            })
            print(f"{borough}: Revenue MAPE={mape_rev:.4f}, Trips MAPE={mape_trips:.4f}, Passed={passed}")
        except Exception as e:
            print(f"Error validating {borough}: {e}")
            results.append({'borough': borough, 'passed': False, 'error': str(e)})

    # Check if all passed
    all_passed = all(r.get('passed', False) for r in results)
    if not all_passed:
        raise ValueError(f"Model validation failed: {results}")

    return results


def generate_forecast(**context):
    """Generate 7-day forecast using trained models."""
    import boto3
    import pickle
    import pandas as pd
    import numpy as np
    from datetime import datetime, timedelta

    execution_date = context['execution_date'].strftime('%Y%m%d')
    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id='minioadmin',
        aws_secret_access_key='minioadmin',
    )

    boroughs = ['manhattan', 'brooklyn', 'queens', 'bronx_si']
    forecast_dates = [(datetime.now() + timedelta(days=i)).strftime('%Y-%m-%d') for i in range(1, 8)]

    predictions = []

    for borough in boroughs:
        # Load model
        response = s3.get_object(Bucket='ml-models', Key=f'taxi-predictor/v{execution_date}/{borough}.pkl')
        models = pickle.loads(response['Body'].read())

        model_revenue = models['revenue']
        model_trips = models['trips']
        feature_cols = models['feature_cols']

        # Generate predictions for each day
        for forecast_date in forecast_dates:
            # Create feature vector (simplified - would use actual features)
            X = pd.DataFrame(np.random.rand(1, len(feature_cols)), columns=feature_cols)

            pred_revenue = model_revenue.predict(X)[0]
            pred_trips = model_trips.predict(X)[0]

            predictions.append({
                'forecast_date': forecast_date,
                'borough': borough,
                'predicted_revenue': float(pred_revenue),
                'predicted_trips': float(pred_trips),
                'model_version': f'v{execution_date}',
                'generated_at': datetime.now().isoformat()
            })

    # Save predictions
    df = pd.DataFrame(predictions)
    csv_buffer = df.to_csv(index=False)

    s3.put_object(
        Bucket='nyc-taxi',
        Key=f'predictions/v{execution_date}/7day_forecast.csv',
        Body=csv_buffer
    )

    print(f"Generated {len(predictions)} predictions for 7 days")
    print(f"Saved to s3a://nyc-taxi/predictions/v{execution_date}/7day_forecast.csv")

    return predictions


# Define DAG
with DAG(
    'nyc_taxi_ml_pipeline',
    default_args=default_args,
    description='NYC Taxi ML Pipeline with CatBoost',
    schedule_interval='0 6 * * *',  # Daily at 6am
    catchup=False,
    tags=['ml', 'nyc-taxi', 'catboost'],
) as dag:

    # Task 1: Check data availability
    check_data = PythonOperator(
        task_id='check_data_availability',
        python_callable=check_minio_data,
    )

    # Task 2: Feature preparation (Spark job)
    feature_prep = BashOperator(
        task_id='feature_preparation',
        bash_command=f'''
            spark-submit --master {SPARK_MASTER} \
                --conf spark.hadoop.fs.s3a.endpoint={MINIO_ENDPOINT} \
                --conf spark.hadoop.fs.s3a.access.key=minioadmin \
                --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
                /opt/airflow/dags/spark_jobs/taxi_feature_engineering.py
        ''',
    )

    # Task 3: Parallel training per borough
    with TaskGroup('train_models') as train_group:
        for borough in ['manhattan', 'brooklyn', 'queens', 'bronx_si']:
            PythonOperator(
                task_id=f'train_{borough}',
                python_callable=train_catboost_borough,
                op_kwargs={'borough': borough},
            )

    # Task 4: Validation
    validate = PythonOperator(
        task_id='validate_models',
        python_callable=validate_models,
    )

    # Task 5: Generate and save predictions
    predict = PythonOperator(
        task_id='predict_and_save',
        python_callable=generate_forecast,
    )

    # DAG flow
    check_data >> feature_prep >> train_group >> validate >> predict
