"""
Initialize Spark session and helper functions when Jupyter kernel starts.
This script is executed automatically when a Jupyter notebook kernel starts.
"""
from __future__ import annotations

import os
import sys
from typing import Any

# Import Spark and MLflow
try:
    from pyspark.sql import SparkSession, DataFrame
    from pyspark.sql.types import StructType
    import mlflow
    import boto3
    from botocore.config import Config
except ImportError as e:
    print(f"Warning: Could not import required libraries: {e}", file=sys.stderr)
    sys.exit(1)

# Get configuration from environment
SPARK_MASTER = os.getenv("SPARK_MASTER_URL", "local[*]")
S3_ENDPOINT = os.getenv("S3_ENDPOINT_URL", "http://minio:9000")
S3_ACCESS_KEY = os.getenv("S3_ACCESS_KEY_ID", "minioadmin")
S3_SECRET_KEY = os.getenv("S3_SECRET_ACCESS_KEY", "minioadmin")
S3_SIGNATURE_VERSION = os.getenv("AWS_S3_SIGNATURE_VERSION", "s3v4")
MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")
SPARK_HOME = os.getenv("SPARK_HOME", "/opt/spark")

# Initialize Spark Session
print("Initializing Spark session...")
spark_builder = (
    SparkSession.builder
    .appName("jupyter-notebook")
    .master(SPARK_MASTER)
)

# Configure S3 access (MinIO or S3 v2)
spark_builder.config("spark.hadoop.fs.s3a.endpoint", S3_ENDPOINT)
spark_builder.config("spark.hadoop.fs.s3a.access.key", S3_ACCESS_KEY)
spark_builder.config("spark.hadoop.fs.s3a.secret.key", S3_SECRET_KEY)
spark_builder.config("spark.hadoop.fs.s3a.path.style.access", "true")
spark_builder.config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
spark_builder.config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
spark_builder.config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")  # For MinIO HTTP

# Spark performance settings
spark_builder.config("spark.sql.shuffle.partitions", "4")
spark_builder.config("spark.sql.adaptive.enabled", "true")
spark_builder.config("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark_builder.config("spark.driver.memory", "2g")
spark_builder.config("spark.executor.memory", "2g")

# JDBC drivers (loaded from SPARK_HOME/jars)
spark_builder.config("spark.jars", f"{SPARK_HOME}/jars/postgresql-42.7.1.jar,{SPARK_HOME}/jars/ojdbc8.jar,{SPARK_HOME}/jars/vertica-jdbc-24.1.0-0.jar")

try:
    spark = spark_builder.getOrCreate()
    print(f"✓ Spark session created successfully (master: {SPARK_MASTER})")
except Exception as e:
    print(f"✗ Failed to create Spark session: {e}", file=sys.stderr)
    spark = None

# Initialize MLflow
try:
    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    print(f"✓ MLflow tracking URI set to: {MLFLOW_TRACKING_URI}")
except Exception as e:
    print(f"✗ Failed to set MLflow tracking URI: {e}", file=sys.stderr)

# Initialize boto3 S3 client
try:
    s3_client = boto3.client(
        "s3",
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=S3_ACCESS_KEY,
        aws_secret_access_key=S3_SECRET_KEY,
        config=Config(signature_version=S3_SIGNATURE_VERSION),
        use_ssl=False,  # For MinIO HTTP
    )
    print(f"✓ S3 client initialized (endpoint: {S3_ENDPOINT})")
except Exception as e:
    print(f"✗ Failed to initialize S3 client: {e}", file=sys.stderr)
    s3_client = None


# Helper functions
def read_s3_parquet(spark_session: SparkSession, path: str, schema: StructType | None = None) -> DataFrame:
    """Read Parquet file from S3/MinIO.
    
    Args:
        spark_session: Active SparkSession.
        path: S3 path (e.g., s3a://bucket/path/to/file.parquet).
        schema: Optional schema for the DataFrame.
    
    Returns:
        DataFrame with data from Parquet file.
    """
    if spark_session is None:
        raise RuntimeError("Spark session is not available")
    
    reader = spark_session.read
    if schema:
        reader = reader.schema(schema)
    
    return reader.parquet(path)


def write_s3_parquet(
    df: DataFrame,
    path: str,
    mode: str = "overwrite",
    partition_by: list[str] | None = None,
) -> None:
    """Write DataFrame to Parquet in S3/MinIO.
    
    Args:
        df: DataFrame to write.
        path: S3 path (e.g., s3a://bucket/path/to/output).
        mode: Write mode (overwrite, append, error, ignore).
        partition_by: Optional list of columns to partition by.
    """
    writer = df.write.mode(mode)
    if partition_by:
        writer = writer.partitionBy(*partition_by)
    writer.parquet(path)


def show_sample(df: DataFrame, n: int = 5) -> None:
    """Display sample rows and schema of DataFrame.
    
    Args:
        df: DataFrame to display.
        n: Number of rows to show.
    """
    print("Schema:")
    df.printSchema()
    print(f"\nSample ({n} rows):")
    df.show(n, truncate=False)


# Make helpers available in notebook namespace
__all__ = [
    "spark",
    "mlflow",
    "s3_client",
    "read_s3_parquet",
    "write_s3_parquet",
    "show_sample",
]

# Welcome message
print("\n" + "=" * 60)
print("JupyterHub + Spark 3.5.7 (Hadoop 3.4) Ready!")
print("=" * 60)
print("\nAvailable objects:")
print("  - spark: SparkSession (pre-configured)")
print("  - mlflow: MLflow client (pre-configured)")
print("  - s3_client: boto3 S3 client (pre-configured)")
print("\nHelper functions:")
print("  - read_s3_parquet(spark, 's3a://bucket/path') -> DataFrame")
print("  - write_s3_parquet(df, 's3a://bucket/path', mode='overwrite')")
print("  - show_sample(df, n=5)")
print("\nExample usage:")
print("  df = read_s3_parquet(spark, 's3a://data-lake/bronze/events')")
print("  show_sample(df)")
print("  write_s3_parquet(df, 's3a://data-lake/silver/events')")
print("=" * 60 + "\n")

