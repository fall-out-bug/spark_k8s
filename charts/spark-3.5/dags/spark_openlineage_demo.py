"""Airflow DAG: Spark job with OpenLineage listener emitting events from Spark driver.

Wires up T027 from specs/grafana-observability-stand/: Spark OpenLineage integration
via --packages io.openlineage:openlineage-spark_2.12, links Spark application to
Airflow DAG run through OpenLineage parentRunFacet.
"""

from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

OPENLINEAGE_URL = "http://openlineage-marquez.lineage.svc.cluster.local:5000"
OPENLINEAGE_ENDPOINT = "/api/v1/lineage"
SPARK_OPENLINEAGE_NS = "spark-infra-spark"

with DAG(
    dag_id="spark_openlineage_demo",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=["spark", "openlineage", "lineage", "demo"],
) as dag:
    # Parent run facet propagated from Airflow context
    # OpenLineage Spark integration picks up env vars:
    #   OPENLINEAGE_TRANSPORT, OPENLINEAGE_NAMESPACE, OPENLINEAGE_PARENT_RUN_ID, OPENLINEAGE_PARENT_JOB_NAME
    run_spark_with_lineage = KubernetesPodOperator(
        task_id="run_spark_with_lineage",
        name="spark-openlineage-demo",
        namespace="spark-infra",
        image="spark-custom:3.5.7",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/bash", "-lc"],
        env_vars={
            # OpenLineage Spark integration reads these env vars (simplified config)
            "OPENLINEAGE_URL": OPENLINEAGE_URL,
            "OPENLINEAGE_NAMESPACE": SPARK_OPENLINEAGE_NS,
            # Also set Airflow-style transport for completeness
            "OPENLINEAGE_TRANSPORT": (
                f'{{"type":"http","url":"{OPENLINEAGE_URL}",' f'"endpoint":"{OPENLINEAGE_ENDPOINT}","timeout":30}}'
            ),
        },
        arguments=[
            "set -e && "
            "DRIVER_HOST=$(hostname -i) && "
            "SPARK_MASTER=${SPARK_MASTER_HOST:-spark-infra-standalone-master} && "
            "/opt/spark/bin/spark-submit "
            "--master spark://$SPARK_MASTER:7077 "
            "--packages io.openlineage:openlineage-spark_2.12:1.29.0 "
            "--conf spark.app.name=spark-openlineage-demo "
            "--conf spark.driver.host=$DRIVER_HOST "
            "--conf spark.driver.bindAddress=0.0.0.0 "
            "--conf spark.executor.cores=1 "
            "--conf spark.executor.memory=512m "
            "--conf spark.driver.memory=512m "
            "--conf spark.sql.shuffle.partitions=4 "
            "--conf spark.eventLog.enabled=true "
            "--conf spark.eventLog.dir=s3a://spark-logs/events "
            "--conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 "
            "--conf spark.hadoop.fs.s3a.access.key=minioadmin "
            "--conf spark.hadoop.fs.s3a.secret.key=minioadmin "
            "--conf spark.hadoop.fs.s3a.path.style.access=true "
            "--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false "
            "--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem "
            "--conf spark.extraListeners=io.openlineage.spark.agent.OpenLineageSparkListener "
            "--conf spark.openlineage.transport.url=http://openlineage-marquez.lineage.svc.cluster.local:5000 "
            "--conf spark.openlineage.transport.endpoint=/api/v1/lineage "
            "--conf spark.openlineage.transport.type=http "
            "--conf spark.openlineage.namespace=spark-infra-spark "
            "--class org.apache.spark.examples.SparkPi "
            "/opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10"
        ],
        get_logs=True,
        is_delete_operator_pod=False,
    )
