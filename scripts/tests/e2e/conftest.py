"""
Pytest configuration and fixtures for E2E tests.

This module provides fixtures for dataset loading, Spark session creation,
and metrics collection for end-to-end testing.
"""
import os
import time
import json
import tempfile
from pathlib import Path
from typing import Dict, Any, Generator

import pytest


@pytest.fixture(scope="session")
def dataset_path() -> str:
    """
    Path to NYC Taxi full dataset (11GB).

    The dataset path can be configured via NYC_TAXI_FULL_PATH environment variable.
    If not set, uses default path. Skips test if dataset not found.

    Returns:
        str: Path to the NYC Taxi dataset in Parquet format.

    Yields:
        None: Skips test if dataset not found.
    """
    path = os.environ.get(
        "NYC_TAXI_FULL_PATH",
        "/tmp/nyc-taxi-full.parquet"
    )
    if not Path(path).exists():
        pytest.skip(f"Dataset not found at {path}. Set NYC_TAXI_FULL_PATH env variable.")
    return path


@pytest.fixture(scope="session")
def sample_dataset_path() -> str:
    """
    Path to NYC Taxi sample dataset (1GB) for faster testing.

    Returns:
        str: Path to the sample NYC Taxi dataset.

    Yields:
        None: Skips test if dataset not found.
    """
    path = os.environ.get(
        "NYC_TAXI_SAMPLE_PATH",
        "/tmp/nyc-taxi-sample.parquet"
    )
    if not Path(path).exists():
        # Try to generate it
        script_path = Path(__file__).parent.parent / "data" / "generate-dataset.sh"
        if script_path.exists():
            os.system(f"bash {script_path} large")
            if not Path(path).exists():
                pytest.skip(f"Sample dataset not found at {path}")
        else:
            pytest.skip(f"Sample dataset not found at {path} and generate script not found")
    return path


@pytest.fixture(scope="session")
def spark_session(request) -> Any:
    """
    Create a Spark session for E2E tests.

    The session is configured for adaptive query execution and is
    automatically cleaned up after all tests complete.

    Args:
        request: Pytest fixture request object.

    Returns:
        SparkSession: Configured Spark session.
    """
    from pyspark.sql import SparkSession

    builder = SparkSession.builder \
        .appName("e2e-test") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.sql.execution.arrow.pyspark.enabled", "true")

    spark = builder.getOrCreate()

    def cleanup():
        if spark:
            spark.stop()

    request.addfinalizer(cleanup)
    return spark


@pytest.fixture(scope="session")
def query_results_dir() -> Path:
    """
    Directory for storing query execution results and metrics.

    Returns:
        Path: Directory path for storing results.
    """
    results_dir = Path(tempfile.gettempdir()) / "e2e_results"
    results_dir.mkdir(exist_ok=True)
    return results_dir


@pytest.fixture(scope="function")
def metrics_collector() -> Generator[Dict[str, Any], None, Dict[str, Any]]:
    """
    Collect metrics during test execution.

    Tracks execution time and memory usage.

    Yields:
        Dict: Empty dict to be populated during test.

    Returns:
        Dict: Metrics including execution_time and memory_used.
    """
    import psutil

    start_time = time.time()
    process = psutil.Process()
    start_memory = process.memory_info().rss

    # Yield empty dict for test to populate if needed
    yield {}

    end_time = time.time()
    end_memory = process.memory_info().rss

    return {
        "execution_time": end_time - start_time,
        "memory_used_bytes": end_memory - start_memory,
        "memory_used_mb": (end_memory - start_memory) / (1024 * 1024)
    }


@pytest.fixture(scope="function")
def query_metrics(
    spark_session: Any,
    query_results_dir: Path
) -> Generator[Dict[str, Any], None, None]:
    """
    Execute a SQL query and collect metrics.

    Args:
        spark_session: Spark session fixture.
        query_results_dir: Directory for storing results.

    Yields:
        Dict: Function that executes query and returns metrics.
    """
    metrics_data = {}

    def execute_query(
        sql: str,
        query_name: str,
        dataset_path: str = None
    ) -> Dict[str, Any]:
        """
        Execute a SQL query and collect performance metrics.

        Args:
            sql: SQL query string.
            query_name: Name for the query (for logging/results).
            dataset_path: Path to dataset (if not already loaded).

        Returns:
            Dict: Query execution metrics.
        """
        start_time = time.time()
        import psutil
        process = psutil.Process()
        start_memory = process.memory_info().rss

        try:
            df = spark_session.sql(sql)
            row_count = df.count()

            # Get some sample rows for validation
            sample = df.limit(10).collect()

            end_time = time.time()
            end_memory = process.memory_info().rss

            metrics = {
                "query_name": query_name,
                "execution_time": end_time - start_time,
                "memory_used_bytes": end_memory - start_memory,
                "row_count": row_count,
                "success": True
            }

            # Calculate throughput
            if metrics["execution_time"] > 0:
                metrics["throughput_rows_per_sec"] = row_count / metrics["execution_time"]

        except Exception as e:
            end_time = time.time()
            end_memory = process.memory_info().rss
            metrics = {
                "query_name": query_name,
                "execution_time": end_time - start_time,
                "memory_used_bytes": end_memory - start_memory,
                "success": False,
                "error": str(e)
            }

        metrics_data[query_name] = metrics

        # Save to file
        results_file = query_results_dir / f"{query_name}_metrics.json"
        with open(results_file, "w") as f:
            json.dump(metrics, f, indent=2)

        return metrics

    yield execute_query


@pytest.fixture(scope="session")
def nyc_taxi_schema() -> Dict[str, str]:
    """
    NYC Taxi dataset schema definition.

    Returns:
        Dict: Column name to type mapping.
    """
    return {
        "VendorID": "bigint",
        "tpep_pickup_datetime": "timestamp",
        "tpep_dropoff_datetime": "timestamp",
        "passenger_count": "bigint",
        "trip_distance": "double",
        "RatecodeID": "bigint",
        "store_and_fwd_flag": "string",
        "PULocationID": "bigint",
        "DOLocationID": "bigint",
        "payment_type": "bigint",
        "fare_amount": "double",
        "extra": "double",
        "mta_tax": "double",
        "tip_amount": "double",
        "tolls_amount": "double",
        "improvement_surcharge": "double",
        "total_amount": "double"
    }


@pytest.fixture(scope="function")
def load_dataset(
    spark_session: Any,
    dataset_path: str,
    nyc_taxi_schema: Dict[str, str]
) -> Any:
    """
    Load NYC Taxi dataset into Spark.

    Args:
        spark_session: Spark session.
        dataset_path: Path to Parquet dataset.
        nyc_taxi_schema: Schema definition.

    Returns:
        DataFrame: Loaded Spark DataFrame.
    """
    df = spark_session.read.parquet(dataset_path)
    return df


@pytest.fixture(scope="function")
def temp_view(
    spark_session: Any,
    load_dataset: Any
) -> None:
    """
    Create a temporary view for SQL queries.

    Args:
        spark_session: Spark session.
        load_dataset: Loaded dataset fixture.

    Yields:
        None: Creates temporary view.
    """
    load_dataset.createOrReplaceTempView("nyc_taxi")
    yield
    spark_session.catalog.dropTempView("nyc_taxi")


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "e2e: mark test as E2E test"
    )
    config.addinivalue_line(
        "markers", "gpu: mark test as requiring GPU"
    )
    config.addinivalue_line(
        "markers", "iceberg: mark test as requiring Iceberg"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow (full dataset)"
    )
