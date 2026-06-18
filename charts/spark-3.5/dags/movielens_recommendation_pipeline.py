"""
MovieLens Recommendation Pipeline - Airflow DAG
Generates movie recommendations using collaborative filtering.
"""

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

_MASTER_HOST = os.environ.get("SPARK_MASTER_HOST", "spark-infra-standalone-master")

CONFIG = {
    "namespace": "spark-infra",
    "spark_master": f"spark://{_MASTER_HOST}:7077",
    "minio_endpoint": "http://minio.spark-infra.svc.cluster.local:9000",
    "pushgateway_url": "http://prometheus.observability.svc.cluster.local:9090",
}

default_args = {
    "owner": "ml-team",
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
        name=f"movielens-{task_id.replace('_', '-')}",
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


def download_movielens_data(**context):
    """Download MovieLens 100k dataset."""
    import io
    import zipfile

    import boto3
    import requests

    print("Downloading MovieLens 100k dataset...")

    # Download dataset
    url = "https://files.grouplens.org/datasets/movielens/ml-100k.zip"
    response = requests.get(url, timeout=60)
    response.raise_for_status()

    # Extract and upload to MinIO
    s3 = boto3.client(
        "s3",
        endpoint_url=CONFIG["minio_endpoint"],
        aws_access_key_id="minioadmin",
        aws_secret_access_key="minioadmin",
    )

    # Create bucket if needed
    try:
        s3.head_bucket(Bucket="movielens")
    except Exception:
        s3.create_bucket(Bucket="movielens")

    # Extract and upload files
    with zipfile.ZipFile(io.BytesIO(response.content)) as z:
        for filename in ["u.data", "u.item", "u.user", "u.genre", "u.occupation"]:
            with z.open(f"ml-100k/{filename}") as f:
                content = f.read()
                s3.put_object(Bucket="movielens", Key=f"raw/{filename}", Body=content)
                print(f"  Uploaded {filename} ({len(content)} bytes)")

    print("MovieLens data ready!")
    return {"files_uploaded": 5}


def validate_recommendations(**context):
    """Validate generated recommendations."""
    import boto3

    s3 = boto3.client(
        "s3",
        endpoint_url=CONFIG["minio_endpoint"],
        aws_access_key_id="minioadmin",
        aws_secret_access_key="minioadmin",
    )

    # Check recommendations exist
    try:
        objs = s3.list_objects_v2(Bucket="movielens", Prefix="recommendations/")
        count = objs.get("KeyCount", 0)
        print(f"Found {count} recommendation files")
        if count == 0:
            raise ValueError("No recommendations generated")
        return {"recommendation_files": count}
    except Exception as e:
        print(f"Validation error: {e}")
        raise


with DAG(
    "movielens_recommendation_pipeline",
    default_args=default_args,
    description="MovieLens Collaborative Filtering Recommendations",
    schedule="0 3 * * 0",  # Weekly on Sunday at 3am
    catchup=False,
    tags=["ml", "recommendations", "movielens"],
    max_active_runs=1,
) as dag:
    download_data = PythonOperator(
        task_id="download_movielens_data",
        python_callable=download_movielens_data,
    )

    build_features = build_spark_submit_task(
        task_id="build_features",
        script_name="movielens_feature_engineering.py",
    )

    train_model = build_spark_submit_task(
        task_id="train_als_model",
        script_name="movielens_als_training.py",
    )

    generate_recs = build_spark_submit_task(
        task_id="generate_recommendations",
        script_name="movielens_generate_recs.py",
    )

    validate = PythonOperator(
        task_id="validate_recommendations",
        python_callable=validate_recommendations,
    )

    download_data >> build_features >> train_model >> generate_recs >> validate
