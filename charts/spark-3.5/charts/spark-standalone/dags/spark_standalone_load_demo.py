"""Airflow DAG for Spark Standalone load demo via KubernetesPodOperator."""

from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator


with DAG(
    dag_id="spark_standalone_load_demo",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=["spark", "standalone", "load", "demo"],
) as dag:
    run_spark_pi_load = KubernetesPodOperator(
        task_id="run_spark_pi_load",
        name="spark-standalone-load-demo",
        namespace="spark-airflow",
        image="spark-custom:3.5.7",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/bash", "-lc"],
        arguments=[
            (
                "DRIVER_HOST=$(hostname -i) && "
                "/opt/spark/bin/spark-submit "
                "--master spark://airflow-sc-standalone-master:7077 "
                "--conf spark.app.name=airflow-standalone-load-demo "
                "--conf spark.driver.host=$DRIVER_HOST "
                "--conf spark.executor.cores=1 "
                "--conf spark.executor.memory=512m "
                "--conf spark.driver.memory=512m "
                "--conf spark.eventLog.enabled=true "
                "--conf spark.eventLog.dir=s3a://spark-logs/events "
                "--conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 "
                "--conf spark.hadoop.fs.s3a.access.key=minioadmin "
                "--conf spark.hadoop.fs.s3a.secret.key=minioadmin "
                "--conf spark.hadoop.fs.s3a.path.style.access=true "
                "--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false "
                "local:///opt/spark/examples/src/main/python/pi.py 100"
            )
        ],
        service_account_name="spark-standalone",
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
    )

    run_spark_pi_load
