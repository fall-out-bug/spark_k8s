"""
Spark Operator E2E DAG (KubernetesPodOperator).
"""

from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

SPARK_NAMESPACE = "{{ var.value.get('spark_namespace', 'default') }}"
SPARK_IMAGE = "{{ var.value.get('spark_image', 'spark-custom:3.5.7') }}"
SPARK_VERSION = "{{ var.value.get('spark_version', '3.5.7') }}"
SPARK_OPERATOR_SERVICEACCOUNT = "{{ var.value.get('spark_operator_serviceaccount', 'spark') }}"
SPARK_EVENTLOG_DIR = "{{ var.value.get('spark_eventlog_dir', 's3a://spark-logs/events') }}"

S3_ENDPOINT = "{{ var.value.get('s3_endpoint', 'http://minio:9000') }}"
S3_ACCESS_KEY = "{{ var.value.get('s3_access_key', 'minioadmin') }}"
S3_SECRET_KEY = "{{ var.value.get('s3_secret_key', 'minioadmin') }}"

RUN_ID_TEMPLATE = "{{ run_id }}"

with DAG(
    dag_id="spark_operator_e2e",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["spark", "operator", "e2e"],
) as dag:
    KubernetesPodOperator(
        task_id="spark_operator_e2e",
        name="spark-operator-e2e",
        namespace=SPARK_NAMESPACE,
        image="bitnami/kubectl:latest",
        service_account_name="spark-operator-spark-operator",
        cmds=["bash", "-lc"],
        arguments=[
            "set -euo pipefail\n"
            "JAR=\"spark-examples.jar\"\n"
            "if [[ \"${SPARK_VERSION}\" == 4.1* ]]; then JAR=\"spark-examples_2.13-4.1.0.jar\"; fi\n"
            "cat > /tmp/spark-app.yaml <<YAML\n"
            "apiVersion: sparkoperator.k8s.io/v1beta2\n"
            "kind: SparkApplication\n"
            "metadata:\n"
            f"  name: airflow-spark-operator-{RUN_ID_TEMPLATE}\n"
            "  namespace: ${SPARK_NAMESPACE}\n"
            "spec:\n"
            "  type: Scala\n"
            "  mode: cluster\n"
            "  image: \"${SPARK_IMAGE}\"\n"
            "  sparkVersion: \"${SPARK_VERSION}\"\n"
            "  mainClass: org.apache.spark.examples.SparkPi\n"
            "  mainApplicationFile: \"local:///opt/spark/examples/jars/${JAR}\"\n"
            "  arguments:\n"
            "    - \"10000\"\n"
            "  sparkConf:\n"
            "    spark.eventLog.enabled: \"true\"\n"
            "    spark.eventLog.dir: \"${SPARK_EVENTLOG_DIR}\"\n"
            "    spark.kubernetes.executor.request.cores: \"0.1\"\n"
            "    spark.kubernetes.executor.limit.cores: \"0.5\"\n"
            "    spark.kubernetes.executor.deleteOnTermination: \"false\"\n"
            "    spark.kubernetes.executor.podNamePrefix: \"spark-pi-e2e\"\n"
            "    spark.kubernetes.client.connection.timeout: \"60000\"\n"
            "    spark.kubernetes.client.request.timeout: \"600000\"\n"
            "    spark.hadoop.fs.s3a.endpoint: \"${S3_ENDPOINT}\"\n"
            "    spark.hadoop.fs.s3a.access.key: \"${S3_ACCESS_KEY}\"\n"
            "    spark.hadoop.fs.s3a.secret.key: \"${S3_SECRET_KEY}\"\n"
            "    spark.hadoop.fs.s3a.aws.credentials.provider: \"org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider\"\n"
            "    spark.hadoop.fs.s3a.path.style.access: \"true\"\n"
            "    spark.hadoop.fs.s3a.connection.ssl.enabled: \"false\"\n"
            "  driver:\n"
            "    cores: 1\n"
            "    memory: \"512m\"\n"
            "    serviceAccount: \"${SPARK_OPERATOR_SERVICEACCOUNT}\"\n"
            "    labels:\n"
            f"      e2e_run_id: \"{RUN_ID_TEMPLATE}\"\n"
            "  executor:\n"
            "    cores: 1\n"
            "    instances: 1\n"
            "    memory: \"512m\"\n"
            "  restartPolicy:\n"
            "    type: Never\n"
            "YAML\n"
            "kubectl apply -f /tmp/spark-app.yaml\n"
            "state=\"\"\n"
            "for _ in $(seq 1 120); do\n"
            f"  state=$(kubectl get sparkapplication airflow-spark-operator-{RUN_ID_TEMPLATE} "
            f"-n {SPARK_NAMESPACE} -o jsonpath='{{.status.applicationState.state}}' 2>/dev/null || true)\n"
            "  if [ \"${state}\" = \"COMPLETED\" ]; then\n"
            "    echo \"SparkApplication state: ${state}\"\n"
            "    exit 0\n"
            "  fi\n"
            "  if [ \"${state}\" = \"FAILED\" ]; then\n"
            "    echo \"SparkApplication state: ${state}\"\n"
            "    exit 1\n"
            "  fi\n"
            "  sleep 5\n"
            "done\n"
            "echo \"SparkApplication state: ${state:-unknown}\"\n"
            "exit 1\n",
        ],
        env_vars={
            "SPARK_NAMESPACE": SPARK_NAMESPACE,
            "SPARK_IMAGE": SPARK_IMAGE,
            "SPARK_VERSION": SPARK_VERSION,
            "SPARK_OPERATOR_SERVICEACCOUNT": SPARK_OPERATOR_SERVICEACCOUNT,
            "SPARK_EVENTLOG_DIR": SPARK_EVENTLOG_DIR,
            "S3_ENDPOINT": S3_ENDPOINT,
            "S3_ACCESS_KEY": S3_ACCESS_KEY,
            "S3_SECRET_KEY": S3_SECRET_KEY,
        },
        get_logs=True,
        is_delete_operator_pod=False,
        on_finish_action="keep_pod",
    )
