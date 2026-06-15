"""
Example DAG for Spark Streaming job management
Demonstrates starting/stopping streaming jobs and monitoring
"""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import BranchPythonOperator, PythonOperator
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from kubernetes import client, config

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

SPARK_IMAGE = Variable.get('spark_image', default_var='spark-custom:3.5.7')
SPARK_NAMESPACE = Variable.get('spark_namespace', default_var='spark')

# Streaming application spec
STREAMING_APP_SPEC = {
    "apiVersion": "sparkoperator.k8s.io/v1beta2",
    "kind": "SparkApplication",
    "metadata": {
        "name": "kafka-stream-processor",
        "namespace": SPARK_NAMESPACE,
    },
    "spec": {
        "type": "Python",
        "pythonVersion": "3",
        "mode": "cluster",
        "image": SPARK_IMAGE,
        "mainApplicationFile": "s3a://spark-jobs/streaming/kafka_consumer.py",
        "sparkVersion": "3.5.7",
        "restartPolicy": {
            "type": "Always",  # Keep streaming job running
        },
        "sparkConf": {
            "spark.streaming.stopGracefullyOnShutdown": "true",
            "spark.streaming.kafka.consumer.cache.enabled": "true",
            "spark.sql.streaming.checkpointLocation": "s3a://checkpoints/streaming/",
        },
        "driver": {
            "cores": 1,
            "memory": "2g",
            "serviceAccount": "spark",
        },
        "executor": {
            "cores": 2,
            "instances": 3,
            "memory": "4g",
        },
        "arguments": [
            "--kafka-bootstrap", "kafka:9092",
            "--topic", "events",
            "--output", "s3a://streaming-output/",
        ],
    },
}


def check_streaming_job_status(**context):
    """Check if streaming job is already running."""
    try:
        config.load_incluster_config()
        api = client.CustomObjectsApi()

        app = api.get_namespaced_custom_object(
            group="sparkoperator.k8s.io",
            version="v1beta2",
            namespace=SPARK_NAMESPACE,
            plural="sparkapplications",
            name="kafka-stream-processor"
        )

        state = app.get('status', {}).get('applicationState', {}).get('state', 'UNKNOWN')

        if state in ['RUNNING', 'SUBMITTED', 'PENDING_RERUN']:
            return 'streaming_already_running'
        else:
            return 'start_streaming_job'

    except client.exceptions.ApiException as e:
        if e.status == 404:
            return 'start_streaming_job'
        raise


def stop_streaming_job(**context):
    """Stop the streaming job gracefully."""
    config.load_incluster_config()
    api = client.CustomObjectsApi()

    try:
        api.delete_namespaced_custom_object(
            group="sparkoperator.k8s.io",
            version="v1beta2",
            namespace=SPARK_NAMESPACE,
            plural="sparkapplications",
            name="kafka-stream-processor"
        )
        print("Streaming job stopped successfully")
    except client.exceptions.ApiException as e:
        if e.status != 404:
            raise


with DAG(
    'spark_streaming_manager',
    default_args=default_args,
    description='Manage Spark Streaming jobs',
    schedule_interval=None,  # Manual trigger only
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['spark', 'streaming', 'kafka'],
) as dag:

    check_status = BranchPythonOperator(
        task_id='check_streaming_status',
        python_callable=check_streaming_job_status,
    )

    start_streaming = SparkKubernetesOperator(
        task_id='start_streaming_job',
        namespace=SPARK_NAMESPACE,
        application_file=STREAMING_APP_SPEC,
        kubernetes_conn_id='kubernetes_default',
    )

    already_running = PythonOperator(
        task_id='streaming_already_running',
        python_callable=lambda: print("Streaming job is already running"),
    )

    check_status >> [start_streaming, already_running]


# DAG to stop streaming
with DAG(
    'spark_streaming_stop',
    default_args=default_args,
    description='Stop Spark Streaming job',
    schedule_interval=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['spark', 'streaming'],
) as dag_stop:

    stop_job = PythonOperator(
        task_id='stop_streaming_job',
        python_callable=stop_streaming_job,
    )
