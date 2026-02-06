#!/usr/bin/env python3
"""
Postgres Integration Helpers for Load Testing
Part of WS-013-08: Load Test Scenario Implementation

Provides Postgres connection helpers and batch write optimization.

Usage:
    from postgres import get_postgres_url, get_postgres_properties
    df.write.jdbc(get_postgres_url(), "table", properties=get_postgres_properties())
"""

from typing import Dict, Any
from urllib.parse import quote_plus


# Postgres configuration for load testing
POSTGRES_HOST = "postgres-load-testing.load-testing.svc.cluster.local"
POSTGRES_PORT = "5432"
POSTGRES_DATABASE = "spark_db"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "sparktest"
POSTGRES_SCHEMA = "test_schema"


def get_postgres_url(
    host: str = POSTGRES_HOST,
    port: str = POSTGRES_PORT,
    database: str = POSTGRES_DATABASE,
) -> str:
    """
    Get JDBC URL for Postgres connection.

    Args:
        host: Postgres host
        port: Postgres port
        database: Database name

    Returns:
        JDBC URL string
    """
    return f"jdbc:postgresql://{host}:{port}/{database}"


def get_postgres_properties(
    user: str = POSTGRES_USER,
    password: str = POSTGRES_PASSWORD,
    driver: str = "org.postgresql.Driver",
    batch_size: int = 10000,
    rewrite_batched_inserts: bool = True,
) -> Dict[str, Any]:
    """
    Get Postgres connection properties with batch optimization.

    Args:
        user: Database user
        password: Database password
        driver: JDBC driver class
        batch_size: Batch size for writes
        rewrite_batched_inserts: Enable batch rewrite optimization

    Returns:
        Dictionary of connection properties
    """
    return {
        "user": user,
        "password": password,
        "driver": driver,
        "batchsize": str(batch_size),
        "rewriteBatchedInserts": str(rewrite_batched_inserts).lower(),
    }


def get_table_fqdn(table_name: str, schema: str = POSTGRES_SCHEMA) -> str:
    """
    Get fully qualified table name.

    Args:
        table_name: Table name
        schema: Schema name

    Returns:
        Fully qualified table name (schema.table)
    """
    return f"{schema}.{table_name}"


def get_batch_size_estimator(row_count: int, default_batch_size: int = 10000) -> int:
    """
    Estimate optimal batch size based on row count.

    Args:
        row_count: Number of rows to write
        default_batch_size: Default batch size

    Returns:
        Optimal batch size
    """
    # For small datasets, use smaller batches
    if row_count < 1000:
        return 100
    elif row_count < 10000:
        return 1000
    elif row_count < 100000:
        return 5000
    else:
        return default_batch_size


def get_write_options(
    mode: str = "overwrite",
    truncate: bool = True,
    batch_size: int = 10000,
) -> Dict[str, Any]:
    """
    Get write options for Spark JDBC writes.

    Args:
        mode: Write mode (overwrite, append, etc.)
        truncate: Truncate table before write
        batch_size: Batch size for writes

    Returns:
        Dictionary of write options
    """
    return {
        "mode": mode,
        "truncate": str(truncate).lower(),
        "batchsize": str(batch_size),
        "rewriteBatchedInserts": "true",
    }


# Example usage
if __name__ == "__main__":
    # Print connection info
    print("Postgres connection details:")
    print(f"  URL: {get_postgres_url()}")
    print(f"  Schema: {POSTGRES_SCHEMA}")
    print(f"  Properties: {get_postgres_properties()}")
