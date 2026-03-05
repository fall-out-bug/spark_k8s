"""
Citibike Analytics Pipeline - Airflow DAG
Analyzes bike-sharing trip data from NYC Citibike.
"""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

CONFIG = {
    "namespace": "spark-infra",
    "spark_master": "spark://spark-infra-spark-standalone-master:7077",
    "minio_endpoint": "http://minio.spark-infra.svc.cluster.local:9000",
    "pushgateway_url": "http://prometheus.observability.svc.cluster.local:9090",
}

default_args = {
    "owner": "analytics-team",
    "depends_on_past": False,
    "start_date": datetime(2026, 2, 1),
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


def build_spark_submit_task(task_id: str, script_name: str, extra_env: dict | None = None):
    """Create a KubernetesPodOperator task that runs a Spark job."""
    env_vars = {
        "MINIO_ENDPOINT": CONFIG["minio_endpoint"],
        "MINIO_ACCESS_KEY": "minioadmin",
        "MINIO_SECRET_KEY": "minioadmin",
        "PUSHGATEWAY_URL": CONFIG["pushgateway_url"],
    }
    if extra_env:
        env_vars.update(extra_env)

    runtime_deps_cmd = "pip install -q boto3 && "

    command = (
        runtime_deps_cmd
        + 'python3 -c "import os,boto3;'
        + f"s3=boto3.client('s3',endpoint_url=os.environ['MINIO_ENDPOINT'],aws_access_key_id=os.environ['MINIO_ACCESS_KEY'],aws_secret_access_key=os.environ['MINIO_SECRET_KEY']);s3.download_file('spark-jobs','dags/spark_jobs/{script_name}','/tmp/{script_name}')\""
        + f" && DRIVER_HOST=$(hostname -i) && /opt/spark/bin/spark-submit --master {CONFIG['spark_master']} "
        "--conf spark.driver.host=$DRIVER_HOST "
        "--conf spark.driver.bindAddress=0.0.0.0 "
        "--conf spark.executor.instances=1 "
        "--conf spark.cores.max=1 "
        "--conf spark.executor.cores=1 "
        "--conf spark.executor.memory=1g "
        "--conf spark.driver.memory=1g "
        "--conf spark.sql.shuffle.partitions=8 "
        "--conf spark.default.parallelism=2 "
        "--conf spark.eventLog.enabled=true "
        "--conf spark.eventLog.dir=s3a://spark-logs/events/ "
        "--conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 "
        "--conf spark.hadoop.fs.s3a.access.key=minioadmin "
        "--conf spark.hadoop.fs.s3a.secret.key=minioadmin "
        "--conf spark.hadoop.fs.s3a.path.style.access=true "
        "--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem "
        f"/tmp/{script_name}"
    )

    return KubernetesPodOperator(
        task_id=task_id,
        name=f"citibike-{task_id.replace('_', '-')}",
        namespace=CONFIG["namespace"],
        image="spark-custom-ml:3.5.7",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/bash", "-lc"],
        arguments=[command],
        env_vars=env_vars,
        service_account_name="spark-standalone",
        get_logs=True,
        random_name_suffix=True,
        reattach_on_restart=False,
        on_finish_action="keep_pod",
        is_delete_operator_pod=False,
        in_cluster=True,
    )


def check_data_availability(**context):
    """Check if Citibike data exists in MinIO."""
    import boto3
    from botocore.client import Config

    s3 = boto3.client(
        "s3",
        endpoint_url=CONFIG["minio_endpoint"],
        aws_access_key_id="minioadmin",
        aws_secret_access_key="minioadmin",
        config=Config(signature_version="s3v4"),
    )

    # Check for citibike bucket or create sample data
    try:
        buckets = [b["Name"] for b in s3.list_buckets()["Buckets"]]
        if "citibike" not in buckets:
            s3.create_bucket(Bucket="citibike")
            # Create sample data marker
            s3.put_object(Bucket="citibike", Key="raw/.initialized", Body=b"")
    except Exception as e:
        print(f"Bucket check/creation: {e}")

    return {"status": "ready"}


with DAG(
    "citibike_analytics_pipeline",
    default_args=default_args,
    description="Citibike Trip Analytics Pipeline",
    schedule_interval="0 8 * * *",
    catchup=False,
    tags=["analytics", "citibike", "transportation"],
    max_active_runs=1,
) as dag:
    check_data = PythonOperator(task_id="check_data_availability", python_callable=check_data_availability)

    feature_prep = build_spark_submit_task(task_id="feature_engineering", script_name="citibike_feature_engineering.py")

    generate_stats = build_spark_submit_task(task_id="generate_statistics", script_name="citibike_statistics.py")

    check_data >> feature_prep >> generate_stats
