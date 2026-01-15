"""
IPython startup script to initialize Spark session and helper functions.
This script is automatically executed when a Jupyter notebook kernel starts.
Provides pandas-like UX for Data Scientists.
"""
from __future__ import annotations

import os
import sys
from typing import Any

# Import core libraries
try:
    import pandas as pd
    import numpy as np
    import matplotlib.pyplot as plt
    import seaborn as sns
    import plotly.express as px
    import plotly.graph_objects as go
    from IPython.display import display, HTML
except ImportError as e:
    print(f"Warning: Could not import visualization libraries: {e}", file=sys.stderr)
    pd = None
    np = None
    plt = None
    sns = None
    px = None
    go = None

# Import Spark and MLflow
try:
    from pyspark.sql import SparkSession, DataFrame
    from pyspark.sql.types import StructType
    import pyspark.pandas as ps  # Spark pandas API
    import mlflow
    import boto3
    from botocore.config import Config
except ImportError as e:
    print(f"Warning: Could not import required libraries: {e}", file=sys.stderr)
    spark = None
    ps = None
    mlflow = None
    s3_client = None
else:
    # Get configuration from environment
    SPARK_MASTER = os.getenv("SPARK_MASTER_URL", "local[*]")
    S3_ENDPOINT = os.getenv("S3_ENDPOINT_URL", "http://minio:9000")
    S3_ACCESS_KEY = os.getenv("S3_ACCESS_KEY_ID", "minioadmin")
    S3_SECRET_KEY = os.getenv("S3_SECRET_ACCESS_KEY", "minioadmin")
    S3_SIGNATURE_VERSION = os.getenv("AWS_S3_SIGNATURE_VERSION", "s3v4")
    MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")
    SPARK_HOME = os.getenv("SPARK_HOME", "/opt/spark")

    # Initialize Spark Session
    print("🚀 Initializing Spark session...")
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
    
    # Enable Arrow for efficient Spark↔Pandas conversion
    spark_builder.config("spark.sql.execution.arrow.pyspark.enabled", "true")
    spark_builder.config("spark.sql.execution.arrow.maxRecordsPerBatch", "10000")

    # JDBC drivers (loaded from SPARK_HOME/jars)
    spark_builder.config("spark.jars", f"{SPARK_HOME}/jars/postgresql-42.7.1.jar,{SPARK_HOME}/jars/ojdbc8.jar,{SPARK_HOME}/jars/vertica-jdbc-24.1.0-0.jar")

    try:
        spark = spark_builder.getOrCreate()
        print(f"✅ Spark session created (master: {SPARK_MASTER})")
        print(f"   Spark version: {spark.version}")
    except Exception as e:
        print(f"❌ Failed to create Spark session: {e}", file=sys.stderr)
        spark = None
        ps = None

    # Initialize Spark pandas API
    if spark is not None:
        try:
            ps.set_option("compute.default_index_type", "distributed")
            print("✅ Spark pandas API (pyspark.pandas) enabled")
        except Exception as e:
            print(f"⚠️  Spark pandas API warning: {e}", file=sys.stderr)

    # Initialize MLflow
    try:
        mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
        print(f"✅ MLflow tracking URI: {MLFLOW_TRACKING_URI}")
    except Exception as e:
        print(f"⚠️  MLflow warning: {e}", file=sys.stderr)

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
        print(f"✅ S3 client initialized (endpoint: {S3_ENDPOINT})")
    except Exception as e:
        print(f"⚠️  S3 client warning: {e}", file=sys.stderr)
        s3_client = None

    # ===== PANDAS-LIKE HELPERS =====
    
    def to_pandas_safe(df: DataFrame, max_rows: int = 10000) -> pd.DataFrame:
        """Convert Spark DataFrame to pandas safely with row limit.
        
        Args:
            df: Spark DataFrame.
            max_rows: Maximum rows to convert (default: 10000).
        
        Returns:
            pandas DataFrame.
        
        Raises:
            RuntimeError: If Spark session is not available.
        """
        if spark is None:
            raise RuntimeError("Spark session is not available")
        if pd is None:
            raise RuntimeError("pandas is not available")
        
        count = df.count()
        if count > max_rows:
            print(f"⚠️  DataFrame has {count:,} rows, limiting to {max_rows:,} for pandas conversion")
            df = df.limit(max_rows)
        
        return df.toPandas()

    def head_pandas(df: DataFrame, n: int = 5) -> pd.DataFrame:
        """Show first n rows as pandas DataFrame (pandas-like display).
        
        Args:
            df: Spark DataFrame.
            n: Number of rows to show.
        
        Returns:
            pandas DataFrame with first n rows.
        """
        return to_pandas_safe(df.limit(n), max_rows=n)

    def display_spark_df(df: DataFrame, n: int = 10, show_schema: bool = True) -> None:
        """Display Spark DataFrame in pandas-like format with schema.
        
        Args:
            df: Spark DataFrame to display.
            n: Number of rows to show.
            show_schema: Whether to show schema.
        """
        if show_schema:
            print("📋 Schema:")
            df.printSchema()
            print()
        
        print(f"📊 Sample ({n} rows):")
        df_pd = head_pandas(df, n=n)
        display(df_pd)
        
        # Show row count if reasonable
        try:
            count = df.count()
            print(f"\n📈 Total rows: {count:,}")
        except Exception:
            pass

    def read_s3_parquet(spark_session: SparkSession, path: str, schema: StructType | None = None) -> DataFrame:
        """Read Parquet file from S3/MinIO (pandas-like interface).
        
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
        df: DataFrame | pd.DataFrame,
        path: str,
        mode: str = "overwrite",
        partition_by: list[str] | None = None,
    ) -> None:
        """Write DataFrame to Parquet in S3/MinIO (handles both Spark and pandas).
        
        Args:
            df: Spark DataFrame or pandas DataFrame.
            path: S3 path (e.g., s3a://bucket/path/to/output).
            mode: Write mode (overwrite, append, error, ignore).
            partition_by: Optional list of columns to partition by.
        """
        if isinstance(df, pd.DataFrame):
            # Convert pandas to Spark
            if spark is None:
                raise RuntimeError("Spark session is not available")
            df = spark.createDataFrame(df)
        
        writer = df.write.mode(mode)
        if partition_by:
            writer = writer.partitionBy(*partition_by)
        writer.parquet(path)

    def show_sample(df: DataFrame, n: int = 5) -> None:
        """Display sample rows and schema of DataFrame (legacy, use display_spark_df).
        
        Args:
            df: DataFrame to display.
            n: Number of rows to show.
        """
        display_spark_df(df, n=n)

    # Make pandas-like aliases
    def head(df: DataFrame, n: int = 5) -> pd.DataFrame:
        """Pandas-like head() for Spark DataFrame."""
        return head_pandas(df, n=n)

    def tail(df: DataFrame, n: int = 5) -> pd.DataFrame:
        """Pandas-like tail() for Spark DataFrame."""
        if spark is None:
            raise RuntimeError("Spark session is not available")
        if pd is None:
            raise RuntimeError("pandas is not available")
        return df.orderBy(df.columns[0]).limit(n).toPandas()

    # ===== WELCOME MESSAGE =====
    
    print("\n" + "=" * 70)
    print("🎉 JupyterHub + Spark 3.5.7 (Hadoop 3.4) - Ready for Data Science!")
    print("=" * 70)
    print("\n✨ Pre-configured objects:")
    print("   • spark      - SparkSession (ready to use)")
    print("   • ps         - Spark pandas API (pyspark.pandas)")
    print("   • mlflow     - MLflow tracking client")
    print("   • s3_client  - boto3 S3 client")
    print("   • pd, np     - pandas, numpy")
    print("   • plt, sns   - matplotlib, seaborn")
    print("   • px, go     - plotly")
    
    print("\n🔧 Pandas-like helpers:")
    print("   • read_s3_parquet(spark, 's3a://bucket/path') -> Spark DataFrame")
    print("   • write_s3_parquet(df, 's3a://bucket/path')   - Write Spark/pandas DF")
    print("   • display_spark_df(df, n=10)                  - Show like pandas")
    print("   • head(df, n=5) / tail(df, n=5)                - Pandas-like head/tail")
    print("   • to_pandas_safe(df, max_rows=10000)          - Safe Spark→pandas")
    
    print("\n📚 Quick start examples:")
    print("   # Read from S3")
    print("   df = read_s3_parquet(spark, 's3a://data-lake/bronze/events')")
    print("   display_spark_df(df)  # Shows like pandas!")
    print("   ")
    print("   # Use Spark pandas API (pyspark.pandas)")
    print("   df_ps = ps.read_parquet('s3a://data-lake/bronze/events')")
    print("   df_ps.head()  # Works like pandas!")
    print("   ")
    print("   # Convert to pandas (safe, with limit)")
    print("   df_pd = to_pandas_safe(df, max_rows=1000)")
    print("   df_pd.plot()  # Use pandas/plotly/seaborn")
    print("   ")
    print("   # Write back to S3")
    print("   write_s3_parquet(df, 's3a://data-lake/silver/events')")
    
    print("\n💡 Tips:")
    print("   • Use 'ps' (pyspark.pandas) for pandas-like API on Spark")
    print("   • Use 'to_pandas_safe()' to convert Spark→pandas (auto-limits rows)")
    print("   • All Spark DFs display nicely with display_spark_df()")
    print("   • JupyterLab extensions: variable inspector, LSP, plotly widgets")
    
    print("=" * 70 + "\n")
