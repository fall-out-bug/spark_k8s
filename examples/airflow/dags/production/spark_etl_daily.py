"""Production ETL DAG with retry, SLA, and alerting.

This DAG demonstrates production-grade patterns:
- Retry logic (3x with exponential backoff)
- SLA monitoring (2 hours)
- Failure callbacks (Slack/Email)
- Execution timeout
- Idempotent design
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from airflow.hooks.base import BaseHook
import logging

logger = logging.getLogger(__name__)

# Configuration
SPARK_CONN_ID = "spark_connect_default"
SPARK_MASTER = "spark://spark-connect:15002"
S3_ENDPOINT = "http://minio:9000"

# SLA and retry settings
DEFAULT_ARGS = {
    "owner": "data-team",
    "depends_on_past": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=30),
    "execution_timeout": timedelta(hours=2),
    "sla": timedelta(hours=2),
    "email_on_failure": True,
    "email_on_retry": False,
    "email": ["data-team@example.com"],
}


def send_failure_alert(context):
    """Send alert on task failure."""
    task_id = context.get("task_instance").task_id
    dag_id = context.get("dag").dag_id
    execution_date = context.get("execution_date")
    exception = context.get("exception")

    message = f"""
    :alert: **Task Failed**
    - **DAG**: {dag_id}
    - **Task**: {task_id}
    - **Execution Date**: {execution_date}
    - **Exception**: {exception}
    """
    logger.error(message)

    # Send Slack notification (configure webhook)
    # requests.post(SLACK_WEBHOOK, json={"text": message})


def send_sla_miss_alert(dag, task_list, blocking_task_list, slas, blocking_tis):
    """Send alert on SLA miss."""
    message = f"""
    :warning: **SLA Miss**
    - **DAG**: {dag.dag_id}
    - **Tasks**: {task_list}
    - **SLAs**: {slas}
    """
    logger.warning(message)


with DAG(
    dag_id="spark_etl_daily",
    default_args=DEFAULT_ARGS,
    description="Daily ETL pipeline with production patterns",
    schedule_interval="0 2 * * *",  # Run at 2 AM daily
    start_date=days_ago(1),
    catchup=False,
    max_active_runs=1,
    tags=["production", "etl", "spark"],
    on_failure_callback=send_failure_alert,
    sla_miss_callback=send_sla_miss_alert,
) as dag:

    # Task 1: Data extraction
    extract_data = SparkSubmitOperator(
        task_id="extract_data",
        conn_id=SPARK_CONN_ID,
        application="s3a://scripts/etl/extract.py",
        name="extract_data_{{ ds }}",
        conf={
            "spark.master": SPARK_MASTER,
            "spark.hadoop.fs.s3a.endpoint": S3_ENDPOINT,
            "spark.hadoop.fs.s3a.access.key": "{{ var.value.s3_access_key }}",
            "spark.hadoop.fs.s3a.secret.key": "{{ var.value.s3_secret_key }}",
        },
        application_args=[
            "--date", "{{ ds }}",
            "--output", "s3a://data/raw/{{ ds }}/",
        ],
        execution_timeout=timedelta(minutes=45),
    )

    # Task 2: Data transformation
    transform_data = SparkSubmitOperator(
        task_id="transform_data",
        conn_id=SPARK_CONN_ID,
        application="s3a://scripts/etl/transform.py",
        name="transform_data_{{ ds }}",
        conf={
            "spark.master": SPARK_MASTER,
            "spark.hadoop.fs.s3a.endpoint": S3_ENDPOINT,
            "spark.hadoop.fs.s3a.access.key": "{{ var.value.s3_access_key }}",
            "spark.hadoop.fs.s3a.secret.key": "{{ var.value.s3_secret_key }}",
            "spark.sql.adaptive.enabled": "true",
        },
        application_args=[
            "--input", "s3a://data/raw/{{ ds }}/",
            "--output", "s3a://data/processed/{{ ds }}/",
        ],
        execution_timeout=timedelta(minutes=60),
    )

    # Task 3: Data loading
    load_data = SparkSubmitOperator(
        task_id="load_data",
        conn_id=SPARK_CONN_ID,
        application="s3a://scripts/etl/load.py",
        name="load_data_{{ ds }}",
        conf={
            "spark.master": SPARK_MASTER,
            "spark.hadoop.fs.s3a.endpoint": S3_ENDPOINT,
            "spark.hadoop.fs.s3a.access.key": "{{ var.value.s3_access_key }}",
            "spark.hadoop.fs.s3a.secret.key": "{{ var.value.s3_secret_key }}",
        },
        application_args=[
            "--input", "s3a://data/processed/{{ ds }}/",
            "--table", "warehouse.fact_daily",
        ],
        execution_timeout=timedelta(minutes=30),
    )

    # Task dependencies
    extract_data >> transform_data >> load_data
