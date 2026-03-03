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
    run_spark_demo_pipeline = KubernetesPodOperator(
        task_id="run_spark_demo_pipeline",
        name="spark-standalone-load-demo",
        namespace="spark-infra",
        image="spark-custom:3.5.7",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/bash", "-lc"],
        arguments=[
            (
                "cat > /tmp/airflow_demo_pipeline.py <<'PYEOF'\n"
                "from datetime import datetime\n"
                "from pyspark.sql import SparkSession\n"
                "from pyspark.sql.functions import col\n"
                "\n"
                "run_id = datetime.utcnow().strftime('%Y%m%d%H%M%S')\n"
                "\n"
                "spark = (SparkSession.builder\n"
                "    .appName('airflow-demo-pipeline')\n"
                "    .enableHiveSupport()\n"
                "    .getOrCreate())\n"
                "\n"
                "df = spark.range(200000).withColumn('bucket', col('id') % 20)\n"
                "output_path = f's3a://spark-jobs/airflow-demo/{run_id}/'\n"
                "df.write.mode('overwrite').parquet(output_path)\n"
                "\n"
                "agg = df.groupBy('bucket').count()\n"
                "agg.createOrReplaceTempView('agg')\n"
                "\n"
                "spark.sql(\"CREATE DATABASE IF NOT EXISTS demo_shared LOCATION 's3a://warehouse/spark-35/demo_shared.db'\")\n"
                "spark.sql('DROP TABLE IF EXISTS demo_shared.airflow_demo_metrics')\n"
                "spark.sql(\"CREATE TABLE demo_shared.airflow_demo_metrics USING PARQUET LOCATION 's3a://warehouse/spark-35/demo_shared.db/airflow_demo_metrics' AS SELECT * FROM agg\")\n"
                "rows = spark.sql('SELECT count(*) AS c FROM demo_shared.airflow_demo_metrics').collect()[0]['c']\n"
                "\n"
                "print(f'DEMO_PIPELINE_OK rows={rows} output={output_path}')\n"
                "spark.stop()\n"
                "PYEOF\n"
                "DRIVER_HOST=$(hostname -i) && "
                "/opt/spark/bin/spark-submit "
                "--master spark://spark-infra-spark-standalone-master:7077 "
                "--conf spark.app.name=airflow-demo-pipeline "
                "--conf spark.driver.host=$DRIVER_HOST "
                "--conf spark.driver.bindAddress=0.0.0.0 "
                "--conf spark.executor.cores=1 "
                "--conf spark.executor.memory=512m "
                "--conf spark.driver.memory=512m "
                "--conf spark.sql.shuffle.partitions=8 "
                "--conf spark.sql.legacy.allowNonEmptyLocationInCTAS=true "
                "--conf spark.eventLog.enabled=true "
                "--conf spark.eventLog.dir=s3a://spark-logs/events "
                "--conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 "
                "--conf spark.hadoop.fs.s3a.access.key=minioadmin "
                "--conf spark.hadoop.fs.s3a.secret.key=minioadmin "
                "--conf spark.hadoop.fs.s3a.path.style.access=true "
                "--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false "
                "--conf spark.hadoop.hive.metastore.uris=thrift://spark-shared-spark-35-metastore:9083 "
                "--conf spark.sql.warehouse.dir=s3a://warehouse/spark-35 "
                "/tmp/airflow_demo_pipeline.py"
            )
        ],
        service_account_name="spark-standalone",
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
    )
