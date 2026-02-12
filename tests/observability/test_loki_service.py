"""
Runtime tests for Loki service accessibility.

Tests:
1. Loki pod is running
2. Loki service exists
3. Loki /ready endpoint responds
"""

import pytest
import subprocess


class TestLokiService:
    """Tests for Loki service accessibility"""

    @pytest.fixture(scope="class")
    def loki_pod(self, kube_namespace):
        """Get Loki pod"""
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app=loki",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("Loki pod not found")
        return result.stdout.strip()

    def test_loki_pod_running(self, loki_pod, kube_namespace):
        """Test that Loki pod is running"""
        cmd = [
            "kubectl", "get", "pod", "-n", kube_namespace, loki_pod,
            "-o", "jsonpath={.status.phase}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.stdout.strip() == "Running"

    def test_loki_service_exists(self, kube_namespace):
        """Test that Loki service exists"""
        cmd = [
            "kubectl", "get", "svc", "-n", kube_namespace, "loki",
            "-o", "jsonpath={.metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.stdout.strip() == "loki"

    def test_loki_ready_endpoint(self, loki_pod, kube_namespace):
        """Test that Loki /ready endpoint returns 200"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, loki_pod,
            "--", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "http://localhost:3100/ready"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.stdout.strip() == "200"


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")
