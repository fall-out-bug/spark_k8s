"""
Pytest configuration for load tests.

Provides fixtures for Spark Connect clients, metrics collection,
and test configuration.
"""

import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

import pytest
from pyspark.sql import SparkSession

# Add parent directory to path for fixtures
sys.path.insert(0, str(Path(__file__).parent.parent))

# ============================================================================
# Test Configuration
# ============================================================================

def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "load: mark test as load test (long-running)"
    )
    config.addinivalue_line(
        "markers", "baseline: mark test as baseline load test"
    )
    config.addinivalue_line(
        "markers", "gpu: mark test as GPU load test"
    )
    config.addinivalue_line(
        "markers", "iceberg: mark test as Iceberg load test"
    )
    config.addinivalue_line(
        "markers", "comparison: mark test as version comparison test"
    )
    config.addinivalue_line(
        "markers", "security: mark test as security stability test"
    )


# ============================================================================
# Configuration Fixtures
# ============================================================================

@pytest.fixture(scope="session")
def load_test_config() -> Dict[str, Any]:
    """Get load test configuration from environment."""
    return {
        "spark_connect_url": os.getenv(
            "SPARK_CONNECT_URL",
            "sc://localhost:15002"
        ),
        "namespace": os.getenv("TEST_NAMESPACE", "spark-load-test"),
        "duration_sec": int(os.getenv("LOAD_TEST_DURATION", "1800")),  # 30 min default
        "interval_sec": float(os.getenv("LOAD_TEST_INTERVAL", "1.0")),
        "queries_file": os.getenv(
            "QUERIES_FILE",
            str(Path(__file__).parent.parent / "e2e" / "queries" / "standard.sql")
        ),
    }


@pytest.fixture(scope="session")
def metrics_output_dir() -> Path:
    """Get directory for metrics output."""
    output_dir = Path(os.getenv(
        "METRICS_OUTPUT_DIR",
        Path(__file__).parent / "results"
    ))
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


# ============================================================================
# Spark Client Fixtures
# ============================================================================

@pytest.fixture(scope="session")
def spark_connect_client(load_test_config: Dict[str, Any]) -> SparkSession:
    """
    Create a Spark Connect client for load testing.

    Uses sc:// protocol for Spark Connect.
    """
    client = SparkSession.builder.remote(
        load_test_config["spark_connect_url"]
    ).getOrCreate()

    yield client

    client.stop()


@pytest.fixture(scope="session")
def spark_358_client() -> Optional[SparkSession]:
    """Create Spark 3.5.8 client for version comparison."""
    url = os.getenv("SPARK_358_CONNECT_URL", "sc://spark-358:15002")
    if os.getenv("SPARK_358_ENABLED", "false") == "true":
        return SparkSession.builder.remote(url).getOrCreate()
    return None


@pytest.fixture(scope="session")
def spark_411_client() -> Optional[SparkSession]:
    """Create Spark 4.1.1 client for version comparison."""
    url = os.getenv("SPARK_411_CONNECT_URL", "sc://spark-411:15002")
    if os.getenv("SPARK_411_ENABLED", "false") == "true":
        return SparkSession.builder.remote(url).getOrCreate()
    return None


# ============================================================================
# Metrics Collection Fixtures
# ============================================================================

@pytest.fixture(scope="function")
def metrics_collector():
    """
    Create a metrics collector for load tests.

    Returns a function that collects and aggregates metrics.
    """
    collected_metrics: List[Dict[str, Any]] = []

    def collector(metrics: Dict[str, Any]) -> None:
        """Collect metrics from a test iteration."""
        collected_metrics.append({
            **metrics,
            "timestamp": datetime.now().isoformat(),
        })

    yield collector

    # Write metrics to file after test
    if collected_metrics:
        output_file = Path(__file__).parent / "results" / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_metrics.jsonl"
        output_file.parent.mkdir(parents=True, exist_ok=True)

        import json
        with open(output_file, "w") as f:
            for m in collected_metrics:
                f.write(json.dumps(m) + "\n")


# ============================================================================
# Statistics Helpers
# ============================================================================

@pytest.fixture(scope="session")
def calculate_percentiles():
    """Calculate percentiles from a list of values."""
    def helper(values: List[float]) -> Dict[str, float]:
        if not values:
            return {"p50": 0.0, "p95": 0.0, "p99": 0.0}

        sorted_values = sorted(values)
        n = len(sorted_values)

        return {
            "p50": sorted_values[n // 2],
            "p95": sorted_values[int(n * 0.95)],
            "p99": sorted_values[int(n * 0.99)],
        }
    return helper


@pytest.fixture(scope="session")
def calculate_throughput():
    """Calculate throughput from metrics."""
    def helper(
        total_queries: int,
        duration_sec: int,
        success_count: Optional[int] = None
    ) -> Dict[str, float]:
        success = success_count if success_count is not None else total_queries
        return {
            "throughput_qps": total_queries / duration_sec,
            "success_rate": success / total_queries if total_queries > 0 else 0.0,
            "error_rate": (total_queries - success) / total_queries if total_queries > 0 else 0.0,
        }
    return helper
