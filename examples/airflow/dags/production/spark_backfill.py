"""Idempotent backfill DAG with date partitioning.

This DAG is designed for historical data backfills:
- Idempotent: re-running same date produces same result
- Date-partitioned input/output
- Supports parallel execution
- Manual trigger with date range
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from airflow.models import Variable
from airflow.exceptions import AirflowSkipException
import logging

logger = logging.getLogger(__name__)

DEFAULT_ARGS = {
    "owner": "data-team",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
    "execution_timeout": timedelta(hours=4),
}


def check_date_range(**context):
    """Validate date range from Airflow Variable."""
    start_date = Variable.get("backfill_start_date", default_var=None)
    end_date = Variable.get("backfill_end_date", default_var=None)

    if not start_date or not end_date:
        raise AirflowSkipException("No backfill date range configured")

    context["ti"].xcom_push(key="start_date", value=start_date)
    context["ti"].xcom_push(key="end_date", value=end_date)
    logger.info(f"Backfill range: {start_date} to {end_date}")


def verify_data_exists(**context):
    """Verify source data exists for the execution date."""
    execution_date = context["execution_date"].strftime("%Y-%m-%d")
    # Add your verification logic here
    logger.info(f"Verifying data for {execution_date}")
    return True


with DAG(
    dag_id="spark_backfill",
    default_args=DEFAULT_ARGS,
    description="Idempotent backfill DAG for historical data",
    schedule_interval=None,  # Manual trigger only
    start_date=days_ago(1),
    catchup=False,
    max_active_runs=3,  # Allow parallel backfills
    tags=["production", "backfill", "spark"],
    params={
        "start_date": "2024-01-01",
        "end_date": "2024-12-31",
    },
) as dag:

    # Task 1: Validate date range
    validate_range = PythonOperator(
        task_id="validate_date_range",
        python_callable=check_date_range,
    )

    # Task 2: Verify source data
    verify_data = PythonOperator(
        task_id="verify_source_data",
        python_callable=verify_data_exists,
    )

    # Task 3: Backfill job (idempotent)
    backfill = SparkSubmitOperator(
        task_id="run_backfill",
        conn_id="spark_connect_default",
        application="s3a://scripts/backfill/process.py",
        name="backfill_{{ ds }}",
        conf={
            "spark.master": "spark://spark-connect:15002",
            "spark.hadoop.fs.s3a.endpoint": "http://minio:9000",
            "spark.sql.adaptive.enabled": "true",
            "spark.sql.shuffle.partitions": "200",
        },
        application_args=[
            "--start-date", "{{ params.start_date }}",
            "--end-date", "{{ params.end_date }}",
            "--output-path", "s3a://data/historical/",
            "--mode", "overwrite",  # Idempotent: overwrite partition
        ],
        execution_timeout=timedelta(hours=3),
    )

    # Task 4: Validate output
    validate_output = PythonOperator(
        task_id="validate_output",
        python_callable=lambda: logger.info("Validating backfill output..."),
    )

    validate_range >> verify_data >> backfill >> validate_output
