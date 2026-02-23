"""
Runtime tests for Prometheus metrics scraping from Spark applications.

Tests:
1. Metrics endpoint is accessible
2. Spark executor metrics are exposed
"""

import pytest
import time
import subprocess
import requests


class TestMetricsEndpoint:
    """Tests for Spark metrics endpoint accessibility"""

    @pytest.fixture(scope="class")
    def spark_pod(self, kube_namespace):
        """Get a running Spark executor pod"""
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "spark-role=executor",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("No Spark executor pods found")
        return result.stdout.strip()

    def test_metrics_port_forward(self, spark_pod, kube_namespace):
        """Test that metrics port can be forwarded"""
        # Start port-forward
        cmd = [
            "kubectl", "port-forward", "-n", kube_namespace,
            spark_pod, "9090:9090"
        ]
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        time.sleep(2)

        try:
            response = requests.get("http://localhost:9090/metrics", timeout=5)
            assert response.status_code == 200
            assert "text/plain" in response.headers.get("content-type", "")
        finally:
            proc.terminate()
            proc.wait()

    def test_metrics_content(self, spark_pod, kube_namespace):
        """Test that metrics contain expected Spark metrics"""
        cmd = [
            "kubectl", "port-forward", "-n", kube_namespace,
            spark_pod, "9090:9090"
        ]
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        time.sleep(2)

        try:
            response = requests.get("http://localhost:9090/metrics", timeout=5)
            metrics = response.text

            # Check for Spark metrics
            assert "spark_" in metrics or "executor" in metrics.lower()

            # Check for standard Prometheus metrics
            assert "jvm_" in metrics or "process_" in metrics or "go_" in metrics
        finally:
            proc.terminate()
            proc.wait()


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")
