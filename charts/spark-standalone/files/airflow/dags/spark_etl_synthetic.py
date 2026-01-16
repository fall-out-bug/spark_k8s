"""
Synthetic Spark ETL DAG (Spark Standalone + MinIO).
"""

from datetime import datetime

import textwrap
from airflow import DAG
from airflow.models import Variable
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

SPARK_IMAGE = Variable.get("spark_image", default_var="spark-custom:3.5.7")
SPARK_NAMESPACE = Variable.get("spark_namespace", default_var="default")
SPARK_MASTER = Variable.get(
    "spark_standalone_master",
    default_var="spark://spark-sa-spark-standalone-master:7077",
)

S3_ENDPOINT = Variable.get("s3_endpoint", default_var="http://minio:9000")
S3_ACCESS_KEY = Variable.get("s3_access_key", default_var="minioadmin")
S3_SECRET_KEY = Variable.get("s3_secret_key", default_var="minioadmin")

ETL_SCRIPT = textwrap.dedent(
    r"""
    from pyspark.sql import SparkSession
    from pyspark.sql.functions import rand, expr

    spark = SparkSession.builder.appName("SyntheticETL").getOrCreate()

    df = (
        spark.range(0, 100000)
        .withColumn("value", rand())
        .withColumn("category", expr("id % 10"))
    )

    result = df.groupBy("category").agg({"value": "avg", "id": "count"})
    result.write.mode("overwrite").parquet("s3a://processed-data/synthetic/")
    spark.stop()
    """
)

with DAG(
    dag_id="spark_etl_synthetic",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["spark", "etl", "synthetic"],
) as dag:
    KubernetesPodOperator(
        task_id="spark_etl_synthetic",
        name="spark-etl-synthetic",
        namespace=SPARK_NAMESPACE,
        image=SPARK_IMAGE,
        cmds=["bash", "-lc"],
        arguments=[
            "cat > /tmp/etl.py <<'PY'\n"
            + ETL_SCRIPT
            + "\nPY\n"
            + "POD_IP=$(hostname -i) && "
            + f"spark-submit --master {SPARK_MASTER} "
            + "--conf spark.driver.memory=1g "
            + "--conf spark.driver.bindAddress=0.0.0.0 "
            + "--conf spark.driver.host=$POD_IP "
            + "--conf spark.executor.instances=1 "
            + "--conf spark.executor.cores=1 "
            + "--conf spark.executor.memory=1g "
            + "--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem "
            + "--conf spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider "
            + "--conf spark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT "
            + "--conf spark.hadoop.fs.s3a.access.key=$AWS_ACCESS_KEY_ID "
            + "--conf spark.hadoop.fs.s3a.secret.key=$AWS_SECRET_ACCESS_KEY "
            + "--conf spark.hadoop.fs.s3a.path.style.access=true "
            + "--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false "
            + "/tmp/etl.py",
        ],
        env_vars={
            "S3_ENDPOINT": S3_ENDPOINT,
            "AWS_ACCESS_KEY_ID": S3_ACCESS_KEY,
            "AWS_SECRET_ACCESS_KEY": S3_SECRET_KEY,
        },
        get_logs=True,
        is_delete_operator_pod=True,
    )

