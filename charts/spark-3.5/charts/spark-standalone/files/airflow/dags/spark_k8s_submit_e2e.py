"""
Spark K8s native submit E2E DAG (KubernetesPodOperator).
"""

from datetime import datetime
import textwrap

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

SPARK_IMAGE = "{{ var.value.get('spark_image', 'spark-custom:3.5.7') }}"
SPARK_NAMESPACE = "{{ var.value.get('spark_namespace', 'default') }}"
SPARK_K8S_SERVICEACCOUNT = "{{ var.value.get('spark_k8s_serviceaccount', 'spark') }}"
SPARK_EVENTLOG_DIR = "{{ var.value.get('spark_eventlog_dir', 's3a://spark-logs/events') }}"
SPARK_UPLOAD_DIR = "s3a://spark-logs/k8s-submit-upload"
SPARK_ROWS = "{{ var.value.get('spark_rows', '20000') }}"
SPARK_SLEEP_SECONDS = "{{ var.value.get('spark_sleep', '120') }}"

S3_ENDPOINT = "{{ var.value.get('s3_endpoint', 'http://minio:9000') }}"
S3_ACCESS_KEY = "{{ var.value.get('s3_access_key', 'minioadmin') }}"
S3_SECRET_KEY = "{{ var.value.get('s3_secret_key', 'minioadmin') }}"

RUN_ID_TEMPLATE = "{{ run_id }}"

JOB_SCRIPT = textwrap.dedent(
    f"""
    import os
    import time
    from pyspark.sql import SparkSession

    spark = SparkSession.builder.appName("AirflowK8sSubmitE2E").getOrCreate()
    rows = int(os.environ.get("SPARK_ROWS", "20000"))
    df = spark.range(0, rows)
    result = df.agg({{"id": "sum"}}).collect()[0][0]
    print(f"RESULT_SUM={{result}}")
    time.sleep(int(os.environ.get("SPARK_SLEEP", "120")))
    spark.stop()
    """
)

with DAG(
    dag_id="spark_k8s_submit_e2e",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["spark", "k8s", "e2e"],
) as dag:
    KubernetesPodOperator(
        task_id="spark_k8s_submit_e2e",
        name="spark-k8s-submit-e2e",
        namespace=SPARK_NAMESPACE,
        service_account_name="spark",
        image=SPARK_IMAGE,
        cmds=["bash", "-lc"],
        arguments=[
            "cat > /tmp/job.py <<'PY'\n"
            + JOB_SCRIPT
            + "\nPY\n"
            + "spark-submit "
            + "--master k8s://https://kubernetes.default.svc:443 "
            + "--deploy-mode client "
            + f"--name airflow-k8s-e2e-{RUN_ID_TEMPLATE} "
            + f"--conf spark.kubernetes.namespace={SPARK_NAMESPACE} "
            + f"--conf spark.kubernetes.authenticate.driver.serviceAccountName={SPARK_K8S_SERVICEACCOUNT} "
            + f"--conf spark.kubernetes.container.image={SPARK_IMAGE} "
            + f"--conf spark.kubernetes.driver.label.e2e_run_id={RUN_ID_TEMPLATE} "
            + "--conf spark.driver.bindAddress=0.0.0.0 "
            + "--conf spark.driver.host=$(hostname -i) "
            + "--conf spark.kubernetes.driverEnv.AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID "
            + "--conf spark.kubernetes.driverEnv.AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY "
            + "--conf spark.executorEnv.AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID "
            + "--conf spark.executorEnv.AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY "
            + "--conf spark.executor.instances=1 "
            + "--conf spark.executor.cores=1 "
            + "--conf spark.executor.memory=512m "
            + "--conf spark.executor.memoryOverhead=128m "
            + "--conf spark.kubernetes.executor.request.cores=0.1 "
            + "--conf spark.kubernetes.executor.limit.cores=0.5 "
            + "--conf spark.kubernetes.executor.deleteOnTermination=false "
            + "--conf spark.eventLog.enabled=true "
            + f"--conf spark.eventLog.dir={SPARK_EVENTLOG_DIR} "
            + "--conf spark.sql.shuffle.partitions=2 "
            + "--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem "
            + "--conf spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider "
            + "--conf spark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT "
            + "--conf spark.hadoop.fs.s3a.access.key=$AWS_ACCESS_KEY_ID "
            + "--conf spark.hadoop.fs.s3a.secret.key=$AWS_SECRET_ACCESS_KEY "
            + "--conf spark.hadoop.fs.s3a.path.style.access=true "
            + "--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false "
            + "/tmp/job.py",
        ],
        env_vars={
            "S3_ENDPOINT": S3_ENDPOINT,
            "AWS_ACCESS_KEY_ID": S3_ACCESS_KEY,
            "AWS_SECRET_ACCESS_KEY": S3_SECRET_KEY,
            "SPARK_ROWS": SPARK_ROWS,
            "SPARK_SLEEP": SPARK_SLEEP_SECONDS,
        },
        get_logs=True,
        is_delete_operator_pod=False,
    )
