"""
Spark Configuration Helper
Provides functions to connect to Spark via Spark Connect
"""

import os
from typing import Optional


def get_spark_session(
    app_name: str = "JupyterSparkSession",
    connect_server: Optional[str] = None,
    extra_configs: Optional[dict] = None
):
    """
    Create a Spark session via Spark Connect.

    Args:
        app_name: Application name for Spark
        connect_server: Spark Connect server URL (e.g., "sc://spark-connect:15002")
                       If None, uses SPARK_REMOTE env var
        extra_configs: Additional Spark configurations

    Returns:
        SparkSession

    Example:
        >>> spark = get_spark_session("MyApp")
        >>> df = spark.createDataFrame([("Alice", 25)], ["name", "age"])
        >>> df.show()
    """
    from pyspark.sql import SparkSession

    # Spark Connect mode - lightweight client
    connect_url = connect_server or os.environ.get('SPARK_REMOTE', 'sc://spark-connect:15002')
    builder = SparkSession.builder.appName(app_name).remote(connect_url)

    # Apply extra configs
    if extra_configs:
        for key, value in extra_configs.items():
            builder = builder.config(key, value)

    return builder.getOrCreate()


# JDBC URL templates
JDBC_TEMPLATES = {
    'postgres': 'jdbc:postgresql://{host}:{port}/{database}',
    'oracle': 'jdbc:oracle:thin:@//{host}:{port}/{service}',
    'vertica': 'jdbc:vertica://{host}:{port}/{database}',
}


def get_jdbc_url(db_type: str, host: str, port: int, database: str, **kwargs) -> str:
    """
    Generate JDBC URL for common database types.

    Args:
        db_type: 'postgres', 'oracle', or 'vertica'
        host: Database host
        port: Database port
        database: Database name (or service name for Oracle)

    Returns:
        JDBC URL string

    Example:
        >>> url = get_jdbc_url('postgres', 'localhost', 5432, 'mydb')
        >>> print(url)
        jdbc:postgresql://localhost:5432/mydb
    """
    template = JDBC_TEMPLATES.get(db_type)
    if not template:
        raise ValueError(f"Unknown database type: {db_type}. Supported: {list(JDBC_TEMPLATES.keys())}")
    return template.format(host=host, port=port, database=database, service=database, **kwargs)
