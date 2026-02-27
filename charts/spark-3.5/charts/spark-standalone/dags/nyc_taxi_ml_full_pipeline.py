"""NYC Taxi ML full pipeline (Airflow + Spark Standalone via KPO)."""

import logging
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

logger = logging.getLogger(__name__)

CONFIG = {
    "namespace": "spark-airflow",
    "spark_master": "spark://airflow-sc-standalone-master:7077",
    "minio_endpoint": "http://minio.spark-infra.svc.cluster.local:9000",
    "pushgateway_url": "http://prometheus-pushgateway.spark-operations:9091",
    "model_version": datetime.now().strftime("%Y%m%d"),
    "mape_threshold": 0.30,
}

default_args = {
    "owner": "ml-team",
    "depends_on_past": False,
    "start_date": datetime(2026, 2, 1),
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


def push_metric(name, value, labels=None):
    import requests

    labels = labels or {}
    labels["version"] = CONFIG["model_version"]
    label_str = ",".join([f'{k}="{v}"' for k, v in labels.items()])
    payload = f"# TYPE {name} gauge\n{name}{{{label_str}}} {value}\n"
    try:
        requests.post(
            f"{CONFIG['pushgateway_url']}/metrics/job/nyc_taxi_ml_pipeline",
            data=payload,
            timeout=10,
        )
    except Exception as exc:
        logger.warning(f"Could not push metric {name}: {exc}")


def build_spark_submit_pod_task(task_id: str, script_name: str, extra_env: dict | None = None):
    env_vars = {
        "MINIO_ENDPOINT": CONFIG["minio_endpoint"],
        "MINIO_ACCESS_KEY": "minioadmin",
        "MINIO_SECRET_KEY": "minioadmin",
        "PUSHGATEWAY_URL": CONFIG["pushgateway_url"],
    }
    if extra_env:
        env_vars.update(extra_env)

    runtime_deps_cmd = ""

    command = (
        runtime_deps_cmd
        + f"wget -q -O /tmp/{script_name} http://minio.spark-infra.svc.cluster.local:9000/spark-jobs/dags/spark_jobs/{script_name}"
        + f" && DRIVER_HOST=$(hostname -i) && /opt/spark/bin/spark-submit --master {CONFIG['spark_master']} "
        "--conf spark.driver.host=$DRIVER_HOST "
        "--conf spark.driver.bindAddress=0.0.0.0 "
        "--conf spark.executor.instances=1 "
        "--conf spark.cores.max=1 "
        "--conf spark.executor.cores=1 "
        "--conf spark.executor.memory=512m "
        "--conf spark.driver.memory=512m "
        "--conf spark.sql.shuffle.partitions=4 "
        "--conf spark.default.parallelism=1 "
        "--conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 "
        "--conf spark.hadoop.fs.s3a.access.key=minioadmin "
        "--conf spark.hadoop.fs.s3a.secret.key=minioadmin "
        "--conf spark.hadoop.fs.s3a.path.style.access=true "
        "--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem "
        f"/tmp/{script_name}"
    )

    return KubernetesPodOperator(
        task_id=task_id,
        name=f"nyc-taxi-{task_id.replace('_', '-')}",
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
    import boto3
    from botocore.client import Config

    s3 = boto3.client(
        "s3",
        endpoint_url=CONFIG["minio_endpoint"],
        aws_access_key_id="minioadmin",
        aws_secret_access_key="minioadmin",
        config=Config(signature_version="s3v4"),
    )
    file_count = s3.list_objects_v2(Bucket="nyc-taxi", Prefix="raw/").get("KeyCount", 0)
    if file_count < 4:
        raise ValueError(f"Insufficient data: only {file_count} files found")
    push_metric("ml_data_files_available", file_count, {"stage": "validation"})
    return {"file_count": file_count}


def validate_models(**context):
    import boto3
    import json
    import pickle

    s3 = boto3.client(
        "s3",
        endpoint_url=CONFIG["minio_endpoint"],
        aws_access_key_id="minioadmin",
        aws_secret_access_key="minioadmin",
    )

    boroughs = ["manhattan", "brooklyn", "queens", "bronx", "staten_island"]
    passed_count = 0
    for borough in boroughs:
        try:
            metrics_key = f"taxi-predictor/v{CONFIG['model_version']}/{borough}.metrics.json"
            try:
                data = json.loads(s3.get_object(Bucket="ml-models", Key=metrics_key)["Body"].read().decode("utf-8"))
            except Exception:
                model = pickle.loads(
                    s3.get_object(Bucket="ml-models", Key=f"taxi-predictor/v{CONFIG['model_version']}/{borough}.pkl")[
                        "Body"
                    ].read()
                )
                data = {"mape_revenue": model.get("mape_revenue", 999.0), "mape_trips": model.get("mape_trips", 999.0)}

            mape_rev = float(data.get("mape_revenue", 999.0))
            mape_trips = float(data.get("mape_trips", 999.0))
            if mape_rev < CONFIG["mape_threshold"] and mape_trips < CONFIG["mape_threshold"]:
                passed_count += 1
        except Exception as exc:
            logger.error(f"Error validating {borough}: {exc}")

    push_metric("ml_validation_models_passed", passed_count, {"stage": "validation"})
    push_metric("ml_validation_total_models", len(boroughs), {"stage": "validation"})
    if passed_count < len(boroughs) // 2:
        raise ValueError(f"Too many models failed validation: {passed_count}/{len(boroughs)} passed")


with DAG(
    "nyc_taxi_ml_full_pipeline",
    default_args=default_args,
    description="NYC Taxi ML Pipeline with Metrics",
    schedule_interval="0 6 * * *",
    catchup=False,
    tags=["ml", "nyc-taxi", "production"],
    max_active_runs=1,
) as dag:
    check_data = PythonOperator(task_id="check_data_availability", python_callable=check_data_availability)

    feature_prep = build_spark_submit_pod_task(task_id="feature_engineering", script_name="taxi_feature_engineering.py")

    train_models = build_spark_submit_pod_task(task_id="train_models", script_name="taxi_catboost_training.py")

    validate = PythonOperator(task_id="validate_models", python_callable=validate_models)

    predict = build_spark_submit_pod_task(
        task_id="generate_predictions",
        script_name="taxi_predict.py",
        extra_env={"MODEL_VERSION": CONFIG["model_version"]},
    )

    check_data >> feature_prep >> train_models >> validate >> predict
