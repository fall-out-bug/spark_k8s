"""
Synthetic ML training DAG with MLflow logging.
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
MLFLOW_TRACKING_URI = Variable.get(
    "mlflow_tracking_uri",
    default_var="http://spark-sa-spark-standalone-mlflow:5000",
)

S3_ENDPOINT = Variable.get("s3_endpoint", default_var="http://minio:9000")
S3_ACCESS_KEY = Variable.get("s3_access_key", default_var="minioadmin")
S3_SECRET_KEY = Variable.get("s3_secret_key", default_var="minioadmin")

TRAIN_SCRIPT = textwrap.dedent(
    r"""
    from pyspark.sql import SparkSession
    from pyspark.ml.feature import VectorAssembler
    from pyspark.ml.regression import LinearRegression
    from pyspark.ml.evaluation import RegressionEvaluator
    import mlflow
    import mlflow.spark

    spark = SparkSession.builder.appName("MLflowTraining").getOrCreate()

    df = spark.range(0, 10000).selectExpr(
        "id",
        "rand() as feature1",
        "rand() as feature2",
        "id * 0.5 + rand() * 10 as label",
    )

    assembler = VectorAssembler(inputCols=["feature1", "feature2"], outputCol="features")
    data = assembler.transform(df)
    train, test = data.randomSplit([0.8, 0.2], seed=42)

    mlflow.set_tracking_uri("MLFLOW_TRACKING_URI")
    mlflow.set_experiment("spark-standalone-training")

    with mlflow.start_run(run_name="linear-regression"):
        lr = LinearRegression(featuresCol="features", labelCol="label")
        model = lr.fit(train)
        predictions = model.transform(test)
        evaluator = RegressionEvaluator(labelCol="label", predictionCol="prediction")
        rmse = evaluator.evaluate(predictions, {evaluator.metricName: "rmse"})
        r2 = evaluator.evaluate(predictions, {evaluator.metricName: "r2"})
        mlflow.log_metric("rmse", rmse)
        mlflow.log_metric("r2", r2)
        mlflow.spark.log_model(model, "model")

    spark.stop()
    """
).replace("MLFLOW_TRACKING_URI", MLFLOW_TRACKING_URI)

with DAG(
    dag_id="mlflow_training_synthetic",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["spark", "mlflow", "synthetic"],
) as dag:
    KubernetesPodOperator(
        task_id="mlflow_training_synthetic",
        name="mlflow-training-synthetic",
        namespace=SPARK_NAMESPACE,
        image=SPARK_IMAGE,
        cmds=["bash", "-lc"],
        arguments=[
            "cat > /tmp/train.py <<'PY'\n"
            + TRAIN_SCRIPT
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
            + "/tmp/train.py",
        ],
        env_vars={
            "S3_ENDPOINT": S3_ENDPOINT,
            "AWS_ACCESS_KEY_ID": S3_ACCESS_KEY,
            "AWS_SECRET_ACCESS_KEY": S3_SECRET_KEY,
            "MLFLOW_TRACKING_URI": MLFLOW_TRACKING_URI,
        },
        get_logs=True,
        is_delete_operator_pod=True,
    )

