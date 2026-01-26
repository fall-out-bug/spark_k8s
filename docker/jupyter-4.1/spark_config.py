"""Pre-configured Spark Connect client for Jupyter."""
import os
from pyspark.sql import SparkSession


def get_spark_session(app_name="JupyterSparkConnect"):
    """
    Create Spark session connected to Spark Connect server.

    Environment variables:
    - SPARK_CONNECT_URL: Spark Connect server URL (default: sc://spark-connect:15002)
    """
    connect_url = os.getenv("SPARK_CONNECT_URL", "sc://spark-connect:15002")

    spark = SparkSession.builder \
        .appName(app_name) \
        .remote(connect_url) \
        .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
        .getOrCreate()

    return spark


if __name__ != "__main__":
    spark = get_spark_session()
    print(f"Spark Connect session created: {spark.version}")
