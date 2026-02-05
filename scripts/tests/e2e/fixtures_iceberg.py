"""
Iceberg-specific fixtures for E2E tests.

This module provides fixtures for Apache Iceberg table operations,
catalog configuration, and Iceberg-specific metrics.
"""
import os
import tempfile
import shutil
from typing import Dict, Any, Generator, Optional
from pathlib import Path

import pytest


@pytest.fixture(scope="function")
def iceberg_warehouse() -> Generator[str, None, None]:
    """
    Create a temporary Iceberg warehouse directory.

    Yields:
        str: Path to temporary warehouse directory.

    Cleans up:
        Removes warehouse directory after test.
    """
    warehouse = tempfile.mkdtemp(prefix="iceberg_warehouse_")
    yield warehouse
    # Cleanup
    shutil.rmtree(warehouse, ignore_errors=True)


@pytest.fixture(scope="function")
def iceberg_catalog(
    spark_session: Any,
    iceberg_warehouse: str
) -> Generator[Dict[str, Any], None, None]:
    """
    Configure Iceberg catalog for Spark session.

    Uses Hadoop catalog implementation with local filesystem.

    Args:
        spark_session: Spark session fixture.
        iceberg_warehouse: Temporary warehouse path.

    Yields:
        Dict: Catalog configuration including catalog name and warehouse path.
    """
    catalog_name = "local"
    catalog_uri = f"file://{iceberg_warehouse}"

    # Configure Iceberg catalog
    spark_session.conf.set(f"spark.sql.catalog.{catalog_name}",
                          "org.apache.iceberg.spark.SparkCatalog")
    spark_session.conf.set(f"spark.sql.catalog.{catalog_name}.type", "hadoop")
    spark_session.conf.set(f"spark.sql.catalog.{catalog_name}.warehouse", catalog_uri)

    # Enable Iceberg extensions
    existing_extensions = spark_session.conf.get("spark.sql.extensions", "")
    iceberg_extension = "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
    if existing_extensions:
        if iceberg_extension not in existing_extensions:
            spark_session.conf.set("spark.sql.extensions",
                                  f"{existing_extensions},{iceberg_extension}")
    else:
        spark_session.conf.set("spark.sql.extensions", iceberg_extension)

    yield {
        "catalog_name": catalog_name,
        "warehouse": iceberg_warehouse,
        "catalog_uri": catalog_uri
    }

    # Drop all tables in catalog
    try:
        tables = spark_session.sql(f"SHOW TABLES IN {catalog_name}")
        for row in tables.collect():
            table_name = row["tableName"]
            spark_session.sql(f"DROP TABLE {catalog_name}.{table_name}")
    except Exception:
        # Catalog cleanup failed, may not exist or already cleaned
        catalog_cleanup_failed = True


@pytest.fixture(scope="function")
def iceberg_table(
    spark_session: Any,
    iceberg_catalog: Dict[str, Any],
    sample_dataset_path: str
) -> Generator[Dict[str, Any], None, None]:
    """
    Create Iceberg table from NYC Taxi dataset.

    Args:
        spark_session: Spark session fixture.
        iceberg_catalog: Iceberg catalog configuration.
        sample_dataset_path: Path to sample dataset.

    Yields:
        Dict: Table information including qualified table name.
    """
    catalog_name = iceberg_catalog["catalog_name"]
    table_name = f"{catalog_name}.nyc_taxi"

    # Load dataset and create Iceberg table
    df = spark_session.read.parquet(sample_dataset_path)
    df.writeTo(table_name).using("iceberg").create()

    yield {
        "table_name": table_name,
        "catalog_name": catalog_name,
        "row_count": df.count()
    }

    # Cleanup table
    try:
        spark_session.sql(f"DROP TABLE {table_name}")
    except Exception:
        # Table may not exist or already dropped
        table_cleanup_failed = True


@pytest.fixture(scope="function")
def iceberg_metrics(spark_session: Any, iceberg_catalog: Dict[str, Any]) -> Dict[str, Any]:
    """
    Collect Iceberg table metrics.

    Args:
        spark_session: Spark session fixture.
        iceberg_catalog: Iceberg catalog configuration.

    Returns:
        Dict: Iceberg metrics including snapshot count and partition count.
    """
    catalog_name = iceberg_catalog["catalog_name"]
    table_name = f"{catalog_name}.nyc_taxi"

    metrics: Dict[str, Any] = {}

    try:
        # Get snapshot history
        snapshots = spark_session.sql(
            f"SELECT * FROM {table_name}.snapshots"
        )
        metrics["snapshot_count"] = snapshots.count()

        # Get current snapshot
        current = spark_session.sql(
            f"SELECT * FROM {table_name}.snapshots " +
            "WHERE committed_at IS NOT NULL " +
            "ORDER BY committed_at DESC LIMIT 1"
        )
        if current.count() > 0:
            metrics["current_snapshot_id"] = current.collect()[0]["snapshot_id"]

        # Get partition count
        try:
            partitions = spark_session.sql(f"SELECT * FROM {table_name}.partitions")
            metrics["partition_count"] = partitions.count()
        except Exception as partition_error:
            # Partitions not available for this table
            metrics["partition_count"] = 0

        # Get schema info
        schema_df = spark_session.sql(f"DESCRIBE {table_name}")
        metrics["schema_column_count"] = schema_df.count()

    except Exception as e:
        metrics["error"] = str(e)
        metrics["snapshot_count"] = 0
        metrics["partition_count"] = 0
        metrics["schema_column_count"] = 0

    return metrics


@pytest.fixture(scope="function")
def iceberg_time_travel(spark_session: Any, iceberg_table: Dict[str, Any]) -> Any:
    """
    Provide Iceberg time travel functionality.

    Args:
        spark_session: Spark session fixture.
        iceberg_table: Iceberg table information.

    Returns:
        Function that performs time travel queries.
    """
    table_name = iceberg_table["table_name"]

    def query_as_of(timestamp: Optional[str] = None, snapshot_id: Optional[int] = None) -> Any:
        """
        Query table at a specific point in time.

        Args:
            timestamp: ISO timestamp (e.g., "2024-01-01T00:00:00.000Z").
            snapshot_id: Snapshot ID for time travel.

        Returns:
            DataFrame: Query result at specified point in time.
        """
        if timestamp:
            return spark_session.sql(
                f"SELECT * FROM {table_name} TIMESTAMP AS OF '{timestamp}'"
            )
        elif snapshot_id:
            return spark_session.sql(
                f"SELECT * FROM {table_name} VERSION AS OF {snapshot_id}"
            )
        else:
            return spark_session.sql(f"SELECT * FROM {table_name}")

    return query_as_of


# Type alias for Spark session
Any = object
