"""
Common utilities and constants for observability tests.

This module provides shared helper functions and constants
used across all observability test files.
"""

from pathlib import Path

# Spark versions to test
SPARK_VERSIONS = ["3.5", "4.1"]


def get_charts_dir() -> Path:
    """Get charts directory"""
    return Path(__file__).parent.parent.parent / "charts"


def get_spark_chart_path(version: str) -> Path:
    """Get chart path for a specific Spark version"""
    return get_charts_dir() / f"spark-{version}"


def get_docker_dir(version: str) -> Path:
    """Get docker directory for a specific Spark version"""
    return Path(__file__).parent.parent.parent / "docker" / f"spark-{version}"
