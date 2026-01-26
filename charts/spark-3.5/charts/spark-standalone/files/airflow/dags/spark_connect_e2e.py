"""
Spark Connect E2E DAG (KubernetesPodOperator).
"""

from datetime import datetime
import textwrap

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

SPARK_IMAGE = "{{ var.value.get('spark_image', 'spark-custom:3.5.7') }}"
SPARK_NAMESPACE = "{{ var.value.get('spark_namespace', 'default') }}"
SPARK_CONNECT_URL = "{{ var.value.get('spark_connect_url', 'sc://spark-connect:15002') }}"
SPARK_ROWS = "{{ var.value.get('spark_rows', '20000') }}"

CONNECT_SCRIPT = textwrap.dedent(
    f"""
    import os
    from pyspark.sql import SparkSession

    spark = (
        SparkSession.builder.appName("AirflowSparkConnectE2E")
        .remote(os.environ["SPARK_CONNECT_URL"])
        .config("spark.sql.shuffle.partitions", "2")
        .getOrCreate()
    )

    rows = int(os.environ.get("SPARK_ROWS", "20000"))
    df = spark.range(0, rows)
    result = df.agg({{"id": "sum"}}).collect()[0][0]
    print(f"RESULT_SUM={{result}}")
    spark.stop()
    """
)

with DAG(
    dag_id="spark_connect_e2e",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["spark", "connect", "e2e"],
) as dag:
    KubernetesPodOperator(
        task_id="spark_connect_e2e",
        name="spark-connect-e2e",
        namespace=SPARK_NAMESPACE,
        image=SPARK_IMAGE,
        cmds=["bash", "-lc"],
        arguments=[
            "python3 - <<'PY'\n" + CONNECT_SCRIPT + "\nPY",
        ],
        env_vars={
            "SPARK_CONNECT_URL": SPARK_CONNECT_URL,
            "SPARK_ROWS": SPARK_ROWS,
        },
        get_logs=True,
        is_delete_operator_pod=False,
    )
