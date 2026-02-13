"""
Runtime tests for Grafana service accessibility.

Tests:
1. Grafana pod is running
2. Grafana service exists
3. Grafana HTTP endpoint responds
"""

import pytest
import subprocess
from pathlib import Path


class TestGrafanaService:
    """Tests for Grafana service accessibility"""
    skip_pod = False

    @pytest.fixture(scope="class")
    def grafana_pod(self, request):
        """Get Grafana pod"""
        import os
        kube_namespace = os.getenv("KUBE_NAMESPACE", "spark-operations")
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app.kubernetes.io/name=grafana",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            # Try alternate labels
            cmd = [
                "kubectl", "get", "pods", "-n", kube_namespace,
                "-l", "app=grafana",
                "-o", "jsonpath={.items[0].metadata.name}"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0 or not result.stdout.strip():
            request.cls.skip_pod = True
            pytest.skip("Grafana pod not found")
        return result.stdout.strip()

    def test_grafana_pod_running(self, grafana_pod, kube_namespace):
        """Test that Grafana pod is running"""
        cmd = [
            "kubectl", "get", "pod", "-n", kube_namespace, grafana_pod,
            "-o", "jsonpath={.status.phase}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.stdout.strip() == "Running"

    def test_grafana_service_exists(self, kube_namespace):
        """Test that Grafana service exists"""
        cmd = [
            "kubectl", "get", "svc", "-n", kube_namespace, "-o", "jsonpath={.items[*].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        # Service might have different name
        services = result.stdout.lower()
        if not services or result.returncode != 0:
            pytest.skip("No services found in namespace (cluster not running)")
        assert "grafana" in services, f"Grafana service should exist, got services: {result.stdout}"

    def test_grafana_http_endpoint(self, grafana_pod, kube_namespace):
        """Test that Grafana HTTP endpoint responds"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, grafana_pod,
            "--", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "http://localhost:3000/api/health"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.stdout.strip() == "200"


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")
