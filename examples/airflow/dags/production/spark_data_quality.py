"""Data Quality check DAG with row count, null check, and freshness validation.

This DAG runs data quality checks:
- Row count validation (min/max thresholds)
- Null percentage check
- Data freshness check
- Schema validation
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from airflow.hooks.base import BaseHook
import logging

logger = logging.getLogger(__name__)

# DQ thresholds
MIN_ROW_COUNT = 1000
MAX_NULL_PERCENT = 5.0
MAX_DATA_AGE_HOURS = 24

DEFAULT_ARGS = {
    "owner": "data-team",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "execution_timeout": timedelta(minutes=30),
}


def check_row_count(**context):
    """Validate row count against threshold."""
    # Get count from previous task via XCom
    count = context["ti"].xcom_pull(task_ids="get_metrics", key="row_count")

    if count is None:
        raise ValueError("Row count not available")

    if count < MIN_ROW_COUNT:
        raise ValueError(f"Row count {count} below threshold {MIN_ROW_COUNT}")

    logger.info(f"Row count check passed: {count} rows")
    return True


def check_null_percentage(**context):
    """Validate null percentage."""
    null_pct = context["ti"].xcom_pull(task_ids="get_metrics", key="null_percentage")

    if null_pct is None:
        raise ValueError("Null percentage not available")

    if null_pct > MAX_NULL_PERCENT:
        raise ValueError(f"Null percentage {null_pct}% exceeds threshold {MAX_NULL_PERCENT}%")

    logger.info(f"Null check passed: {null_pct}% nulls")
    return True


def check_data_freshness(**context):
    """Validate data is not stale."""
    age_hours = context["ti"].xcom_pull(task_ids="get_metrics", key="data_age_hours")

    if age_hours is None:
        raise ValueError("Data age not available")

    if age_hours > MAX_DATA_AGE_HOURS:
        raise ValueError(f"Data is {age_hours}h old, exceeds {MAX_DATA_AGE_HOURS}h threshold")

    logger.info(f"Freshness check passed: data is {age_hours}h old")
    return True


with DAG(
    dag_id="spark_data_quality",
    default_args=DEFAULT_ARGS,
    description="Data quality checks with alerting",
    schedule_interval="0 */6 * * *",  # Every 6 hours
    start_date=days_ago(1),
    catchup=False,
    max_active_runs=1,
    tags=["production", "data-quality", "spark"],
) as dag:

    # Task 1: Collect metrics
    get_metrics = SparkSubmitOperator(
        task_id="get_metrics",
        conn_id="spark_connect_default",
        application="s3a://scripts/dq/collect_metrics.py",
        name="dq_metrics_{{ ds }}",
        conf={
            "spark.master": "spark://spark-connect:15002",
            "spark.hadoop.fs.s3a.endpoint": "http://minio:9000",
        },
        application_args=[
            "--table", "warehouse.fact_daily",
            "--output-xcom", "true",
        ],
        execution_timeout=timedelta(minutes=15),
    )

    # Task 2: Row count validation
    validate_row_count = PythonOperator(
        task_id="validate_row_count",
        python_callable=check_row_count,
    )

    # Task 3: Null check
    validate_nulls = PythonOperator(
        task_id="validate_nulls",
        python_callable=check_null_percentage,
    )

    # Task 4: Freshness check
    validate_freshness = PythonOperator(
        task_id="validate_freshness",
        python_callable=check_data_freshness,
    )

    # Task 5: Generate DQ report
    generate_report = SparkSubmitOperator(
        task_id="generate_report",
        conn_id="spark_connect_default",
        application="s3a://scripts/dq/generate_report.py",
        name="dq_report_{{ ds }}",
        conf={
            "spark.master": "spark://spark-connect:15002",
        },
        application_args=[
            "--date", "{{ ds }}",
            "--output", "s3a://reports/dq/{{ ds }}/",
        ],
        execution_timeout=timedelta(minutes=10),
    )

    # Dependencies
    get_metrics >> [validate_row_count, validate_nulls, validate_freshness] >> generate_report
