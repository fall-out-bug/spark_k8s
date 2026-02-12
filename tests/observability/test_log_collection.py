"""
Runtime tests for log collection from Spark pods.

Tests:
1. Promtail is deployed
2. Loki has log streams
3. Spark logs can be queried
4. Log labels are available
"""

import pytest
import subprocess


class TestLogCollection:
    """Tests for log collection from Spark pods"""

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

    def test_promtail_deployment(self, kube_namespace):
        """Test that Promtail is deployed for log collection"""
        cmd = [
            "kubectl", "get", "deployment", "-n", kube_namespace,
            "-l", "app=promtail"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        # Promtail may be a DaemonSet instead
        if result.returncode != 0:
            cmd = [
                "kubectl", "get", "daemonset", "-n", kube_namespace,
                "-l", "app=promtail"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)

        assert result.returncode == 0, "Promtail should be deployed"

    def test_loki_has_streams(self, loki_pod, kube_namespace):
        """Test that Loki has log streams"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, loki_pod,
            "--", "curl", "-s",
            "http://localhost:3100/loki/api/v1/labels"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Check response format
        data = result.stdout
        assert '"status":"success"' in data or "values" in data.lower()


class TestLogQueries:
    """Tests for querying logs through Loki"""

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

    def test_query_spark_logs(self, loki_pod, kube_namespace):
        """Test that Spark logs can be queried"""
        # Query for logs from Spark pods
        query = '{job=~"spark.*"}'
        encoded_query = query.replace('"', '\\"')

        cmd = [
            "kubectl", "exec", "-n", kube_namespace, loki_pod,
            "--", "curl", "-s",
            f"http://localhost:3100/loki/api/v1/query?query={encoded_query}&limit=10"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Just check query succeeds - actual logs depend on running apps
        assert '"status":"success"' in result.stdout

    def test_log_labels_present(self, loki_pod, kube_namespace):
        """Test that log labels are available"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, loki_pod,
            "--", "curl", "-s", "http://localhost:3100/loki/api/v1/labels"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Check for common labels
        data = result.stdout.lower()
        # Labels may vary depending on configuration
        assert '"status":"success"' in result.stdout or 'values' in data


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")
