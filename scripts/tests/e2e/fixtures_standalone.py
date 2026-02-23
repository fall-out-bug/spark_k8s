"""
Standalone cluster-specific fixtures for E2E tests.

This module provides fixtures for Spark standalone cluster deployment,
Master/Worker pod verification, and standalone-specific metrics.
"""
import os
import time
import subprocess
from typing import Dict, Any, Generator, Optional
from pathlib import Path

import pytest


def _check_kubectl() -> bool:
    """
    Check if kubectl is available.

    Returns:
        bool: True if kubectl is available, False otherwise.
    """
    try:
        result = subprocess.run(
            ["kubectl", "version", "--client"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _get_pods_by_selector(selector: str, namespace: str = "default") -> list:
    """
    Get pods matching a label selector.

    Args:
        selector: Label selector (e.g., "app=spark-master").
        namespace: Kubernetes namespace.

    Returns:
        list: List of pod names.
    """
    try:
        result = subprocess.run([
            "kubectl", "get", "pods",
            "-l", selector,
            "-n", namespace,
            "-o", "jsonpath={.items[*].metadata.name}"
        ], capture_output=True, text=True, timeout=30)

        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip().split()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        # kubectl not available or command failed
        return []


def _wait_for_pods_ready(
    selector: str,
    namespace: str = "default",
    timeout: int = 120
) -> bool:
    """
    Wait for pods matching selector to be ready.

    Args:
        selector: Label selector.
        namespace: Kubernetes namespace.
        timeout: Maximum wait time in seconds.

    Returns:
        bool: True if pods are ready, False otherwise.
    """
    try:
        result = subprocess.run([
            "kubectl", "wait", "--for=condition=ready",
            "pod", "-l", selector,
            "-n", namespace,
            "--timeout", f"{timeout}s"
        ], capture_output=True, timeout=timeout + 10)

        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


@pytest.fixture(scope="session")
def kubectl_available() -> bool:
    """
    Check if kubectl is available for standalone tests.

    Returns:
        bool: True if kubectl is available.

    Yields:
        None: Skips test if kubectl not available.
    """
    if not _check_kubectl():
        pytest.skip("kubectl not available (required for standalone tests)")
    return True


@pytest.fixture(scope="function")
def standalone_cluster(
    kubectl_available: bool,
    request
) -> Generator[Dict[str, Any], None, None]:
    """
    Deploy Spark standalone cluster for testing.

    This fixture checks for an existing standalone cluster.
    If not found, it can optionally deploy one (if helm is available).

    Args:
        kubectl_available: kubectl availability fixture.
        request: Pytest fixture request object.

    Yields:
        Dict: Cluster information including master URL and release name.

    Cleans up:
        Removes cluster if deployed by fixture.
    """
    release_name = "spark-standalone-e2e"
    namespace = "default"

    # Check if cluster already exists
    master_pods = _get_pods_by_selector(
        f"app=spark-master,app.kubernetes.io/instance={release_name}",
        namespace
    )

    if master_pods:
        # Cluster exists, use it
        master_url = f"spark://{release_name}-spark-master:7077"
    else:
        # Try to deploy cluster (requires helm)
        try:
            subprocess.run([
                "helm", "upgrade", "--install", release_name,
                "charts/spark-standalone",
                "--namespace", namespace,
                "--create-namespace",
                "--set", "spark.worker.replicas=2",
                "--wait", "--timeout", "300s"
            ], check=True, capture_output=True, timeout=320)

            # Wait for master
            if not _wait_for_pods_ready(
                f"app=spark-master,app.kubernetes.io/instance={release_name}",
                namespace, 120
            ):
                pytest.skip("Standalone master not ready")

            # Wait for workers
            if not _wait_for_pods_ready(
                f"app=spark-worker,app.kubernetes.io/instance={release_name}",
                namespace, 120
            ):
                pytest.skip("Standalone workers not ready")

            master_url = f"spark://{release_name}-spark-master:7077"
        except (FileNotFoundError, subprocess.TimeoutExpired, subprocess.CalledProcessError):
            pytest.skip("Cannot deploy standalone cluster (helm not available)")

    yield {
        "master_url": master_url,
        "release": release_name,
        "namespace": namespace
    }

    # Note: We don't cleanup the cluster as it may be shared across tests


@pytest.fixture(scope="function")
def standalone_metrics(standalone_cluster: Dict[str, Any]) -> Dict[str, Any]:
    """
    Collect standalone cluster metrics.

    Args:
        standalone_cluster: Standalone cluster fixture.

    Returns:
        Dict: Cluster metrics including worker count.
    """
    release = standalone_cluster["release"]
    namespace = standalone_cluster["namespace"]

    worker_pods = _get_pods_by_selector(
        f"app=spark-worker,app.kubernetes.io/instance={release}",
        namespace
    )

    master_pods = _get_pods_by_selector(
        f"app=spark-master,app.kubernetes.io/instance={release}",
        namespace
    )

    return {
        "worker_count": len(worker_pods),
        "master_count": len(master_pods),
        "master_url": standalone_cluster["master_url"]
    }


@pytest.fixture(scope="function")
def standalone_executor_distribution(
    spark_session: Any,
    standalone_cluster: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Get executor distribution across workers.

    Args:
        spark_session: Spark session fixture.
        standalone_cluster: Standalone cluster fixture.

    Returns:
        Dict: Executor distribution metrics.
    """
    try:
        # Get executor info from SparkContext
        sc = spark_session.sparkContext
        executors = sc.statusTracker().getExecutorInfos()

        # Filter out driver
        worker_executors = [e for e in executors if e.id() != "<driver>"]

        return {
            "executor_count": len(worker_executors),
            "worker_hosts": len(set(e.host() for e in worker_executors))
        }
    except Exception as e:
        return {
            "executor_count": 0,
            "worker_hosts": 0,
            "error": str(e)
        }


# Type alias for Spark session
Any = object
