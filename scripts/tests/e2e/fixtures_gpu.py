"""
GPU-specific fixtures for E2E tests.

This module provides fixtures for GPU detection, metrics collection,
and GPU-specific Spark configuration.
"""
import os
import json
import subprocess
from typing import Dict, Any, Generator, Optional
from pathlib import Path

import pytest

# Type for SparkSession (avoiding circular import)
Any = object


def _check_nvidia_smi() -> bool:
    """
    Check if nvidia-smi is available and GPU is present.

    Returns:
        bool: True if GPU is available, False otherwise.
    """
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0 and bool(result.stdout.strip())
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _get_gpu_stats() -> Dict[str, Any]:
    """
    Get current GPU statistics.

    Returns:
        Dict: GPU utilization and memory metrics.
    """
    try:
        result = subprocess.run([
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"
        ], capture_output=True, text=True, timeout=5)

        if result.returncode == 0:
            parts = result.stdout.strip().split(",")
            if len(parts) >= 3:
                return {
                    "gpu_utilization": int(parts[0].strip()),
                    "gpu_memory_used_mb": int(parts[1].strip()),
                    "gpu_memory_total_mb": int(parts[2].strip())
                }
    except (FileNotFoundError, subprocess.TimeoutExpired, ValueError) as e:
        # Log the exception and return default metrics
        # GPU metrics not available, using defaults

    return {
        "gpu_utilization": 0,
        "gpu_memory_used_mb": 0,
        "gpu_memory_total_mb": 0
    }


@pytest.fixture(scope="session")
def gpu_available() -> bool:
    """
    Check if NVIDIA GPU is available.

    Skips tests if no GPU is present.

    Returns:
        bool: True if GPU is available.

    Yields:
        None: Skips test if GPU not available.
    """
    if not _check_nvidia_smi():
        pytest.skip("No GPU available (nvidia-smi not found)")
    return True


@pytest.fixture(scope="function")
def gpu_metrics() -> Generator[Dict[str, Any], None, Dict[str, Any]]:
    """
    Collect GPU metrics during test execution.

    Measures GPU utilization before and after test.

    Yields:
        Dict: Empty dict for test to populate if needed.

    Returns:
        Dict: GPU metrics including utilization and memory usage.
    """
    # Get baseline metrics
    baseline = _get_gpu_stats()

    # Yield for test execution
    yield {}

    # Get final metrics
    final = _get_gpu_stats()

    return {
        "baseline": baseline,
        "final": final,
        "utilization_delta": final["gpu_utilization"] - baseline["gpu_utilization"],
        "memory_delta_mb": final["gpu_memory_used_mb"] - baseline["gpu_memory_used_mb"]
    }


@pytest.fixture(scope="function")
def spark_session_with_gpu(request, spark_session: Any, gpu_available: bool) -> Any:
    """
    Create Spark session with GPU support enabled.

    Configures Spark for RAPIDS acceleration with CUDA support.

    Args:
        request: Pytest fixture request object.
        spark_session: Base Spark session fixture.
        gpu_available: GPU availability fixture.

    Returns:
        SparkSession: Spark session with GPU configuration.
    """
    # Enable RAPIDS GPU acceleration
    spark_session.conf.set("spark.rapids.sql.enabled", "true")
    spark_session.conf.set("spark.rapids.sql.incompatibleOps.enabled", "true")
    spark_session.conf.set("spark.rapids.sql.castFloatToString.enabled", "true")
    spark_session.conf.set("spark.rapids.sql.hashOptimizeSort.enabled", "true")

    # Set GPU resource scheduling
    spark_session.conf.set("spark.task.resource.gpu.amount", "1")
    spark_session.conf.set("spark.executor.resource.gpu.amount", "1")

    return spark_session


@pytest.fixture(scope="session")
def cuda_version() -> Optional[str]:
    """
    Get CUDA version from nvidia-smi.

    Returns:
        Optional[str]: CUDA version string or None if not available.
    """
    try:
        result = subprocess.run([
            "nvidia-smi", "--query-gpu=cuda_version", "--format=csv,noheader"
        ], capture_output=True, text=True, timeout=5)

        if result.returncode == 0:
            version = result.stdout.strip().strip('"/')
            return version
    except (FileNotFoundError, subprocess.TimeoutExpired):
        # CUDA version not available
        return None


@pytest.fixture(scope="function")
def gpu_performance_metrics(spark_session: Any) -> Dict[str, Any]:
    """
    Collect GPU performance metrics for Spark queries.

    Returns:
        Dict: Performance metrics including GPU speedup factor.
    """
    return {
        "gpu_enabled": spark_session.conf.get("spark.rapids.sql.enabled", "false") == "true",
        "gpu_resource_amount": spark_session.conf.get("spark.task.resource.gpu.amount", "0")
    }
