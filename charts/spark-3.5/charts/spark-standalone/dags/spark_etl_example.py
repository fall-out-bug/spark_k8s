"""
Example DAG for Spark ETL on Kubernetes
Demonstrates both Spark Operator and spark-submit approaches
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.providers.cncf.kubernetes.sensors.spark_kubernetes import SparkKubernetesSensor
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.python import PythonOperator
from airflow.models import Variable

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Get configuration from Airflow Variables
SPARK_IMAGE = Variable.get('spark_image', default_var='spark-custom:3.5.7')
SPARK_NAMESPACE = Variable.get('spark_namespace', default_var='spark')
S3_ENDPOINT = Variable.get('s3_endpoint', default_var='http://minio:9000')

# Spark Application spec for Spark Operator
SPARK_APP_SPEC = {
    "apiVersion": "sparkoperator.k8s.io/v1beta2",
    "kind": "SparkApplication",
    "metadata": {
        "name": "spark-etl-{{ ds_nodash }}",
        "namespace": SPARK_NAMESPACE,
    },
    "spec": {
        "type": "Python",
        "pythonVersion": "3",
        "mode": "cluster",
        "image": SPARK_IMAGE,
        "imagePullPolicy": "IfNotPresent",
        "mainApplicationFile": "s3a://spark-jobs/etl/transform.py",
        "sparkVersion": "3.5.7",
        "restartPolicy": {
            "type": "OnFailure",
            "onFailureRetries": 3,
            "onFailureRetryInterval": 10,
            "onSubmissionFailureRetries": 5,
            "onSubmissionFailureRetryInterval": 20,
        },
        "sparkConf": {
            "spark.hadoop.fs.s3a.endpoint": S3_ENDPOINT,
            "spark.hadoop.fs.s3a.path.style.access": "true",
            "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
            "spark.eventLog.enabled": "true",
            "spark.eventLog.dir": "s3a://spark-logs/events",
            "spark.sql.extensions": "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
        },
        "hadoopConf": {
            "fs.s3a.access.key": "{{ var.value.s3_access_key }}",
            "fs.s3a.secret.key": "{{ var.value.s3_secret_key }}",
        },
        "driver": {
            "cores": 1,
            "memory": "2g",
            "labels": {
                "version": "3.5.7",
            },
            "serviceAccount": "spark",
            "envSecretKeyRefs": {
                "AWS_ACCESS_KEY_ID": {
                    "name": "s3-credentials",
                    "key": "access-key",
                },
                "AWS_SECRET_ACCESS_KEY": {
                    "name": "s3-credentials",
                    "key": "secret-key",
                },
            },
        },
        "executor": {
            "cores": 2,
            "instances": 2,
            "memory": "4g",
            "labels": {
                "version": "3.5.7",
            },
            "envSecretKeyRefs": {
                "AWS_ACCESS_KEY_ID": {
                    "name": "s3-credentials",
                    "key": "access-key",
                },
                "AWS_SECRET_ACCESS_KEY": {
                    "name": "s3-credentials",
                    "key": "secret-key",
                },
            },
        },
        "arguments": [
            "--input", "s3a://raw-data/{{ ds }}/",
            "--output", "s3a://processed-data/{{ ds }}/",
            "--date", "{{ ds }}",
        ],
    },
}


with DAG(
    'spark_etl_operator',
    default_args=default_args,
    description='Spark ETL using Spark Kubernetes Operator',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['spark', 'etl', 'operator'],
) as dag_operator:

    # Submit Spark job via Spark Operator
    submit_spark_job = SparkKubernetesOperator(
        task_id='submit_spark_etl',
        namespace=SPARK_NAMESPACE,
        application_file=SPARK_APP_SPEC,
        kubernetes_conn_id='kubernetes_default',
        do_xcom_push=True,
    )

    # Monitor Spark job completion
    monitor_spark_job = SparkKubernetesSensor(
        task_id='monitor_spark_etl',
        namespace=SPARK_NAMESPACE,
        application_name="{{ task_instance.xcom_pull(task_ids='submit_spark_etl')['metadata']['name'] }}",
        kubernetes_conn_id='kubernetes_default',
        attach_log=True,
    )

    submit_spark_job >> monitor_spark_job


# Alternative DAG using spark-submit directly
with DAG(
    'spark_etl_submit',
    default_args=default_args,
    description='Spark ETL using spark-submit',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['spark', 'etl', 'submit'],
) as dag_submit:

    spark_submit_job = SparkSubmitOperator(
        task_id='spark_submit_etl',
        application='s3a://spark-jobs/etl/transform.py',
        conn_id='spark_k8s',
        conf={
            'spark.master': 'k8s://https://kubernetes.default.svc',
            'spark.kubernetes.container.image': SPARK_IMAGE,
            'spark.kubernetes.namespace': SPARK_NAMESPACE,
            'spark.kubernetes.authenticate.driver.serviceAccountName': 'spark',
            'spark.hadoop.fs.s3a.endpoint': S3_ENDPOINT,
            'spark.hadoop.fs.s3a.path.style.access': 'true',
            'spark.eventLog.enabled': 'true',
            'spark.eventLog.dir': 's3a://spark-logs/events',
        },
        application_args=[
            '--input', 's3a://raw-data/{{ ds }}/',
            '--output', 's3a://processed-data/{{ ds }}/',
            '--date', '{{ ds }}',
        ],
        name='spark-etl-{{ ds_nodash }}',
        verbose=True,
    )
