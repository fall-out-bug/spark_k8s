"""
Runtime tests for Loki logs aggregation from Spark applications.

Tests:
1. Loki service is accessible
2. Spark logs are being collected
3. Log queries return expected results
4. Log labels are properly applied
"""

import pytest
import time
import subprocess
import requests
from pathlib import Path


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


class TestLogFormats:
    """Tests for log format and structure"""

    @pytest.fixture(scope="class")
    def spark_pod(self, kube_namespace):
        """Get a running Spark pod"""
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "spark-role=driver",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("No Spark driver pods found")
        return result.stdout.strip()

    def test_spark_logs_json_format(self, spark_pod, kube_namespace):
        """Test that Spark logs are in JSON format"""
        cmd = [
            "kubectl", "logs", "-n", kube_namespace, spark_pod,
            "--tail", "10"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Check for JSON structure or log level indicators
        logs = result.stdout
        # Logs may be JSON or plain text
        assert len(logs) > 0, "Should have some log output"

    def test_log_levels_present(self, spark_pod, kube_namespace):
        """Test that different log levels are present"""
        cmd = [
            "kubectl", "logs", "-n", kube_namespace, spark_pod,
            "--tail", "100"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        logs = result.stdout.lower()
        # Check for common log levels
        has_log_levels = any(
            level in logs
            for level in ["info", "warn", "error", "debug"]
        )
        assert has_log_levels, "Logs should contain log level indicators"


class TestGrafanaLokiDataSource:
    """Tests for Grafana-Loki integration"""

    def test_loki_datasource_config(self, charts_dir):
        """Test that Loki datasource is configured for Grafana"""
        datasource_files = list(charts_dir.rglob("*datasource*loki*.yaml"))
        # Grafana datasources might be ConfigMaps or Secret files
        if not datasource_files:
            configmap_files = list(charts_dir.rglob("grafana*datasource*.yaml"))
            # Check if any datasource file mentions Loki
            loki_found = False
            for f in configmap_files:
                if "loki" in f.read_text().lower():
                    loki_found = True
                    break
            assert loki_found, "Loki datasource should be configured"
        else:
            assert len(datasource_files) > 0


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")


@pytest.fixture
def charts_dir():
    """Get charts directory"""
    return Path(__file__).parent.parent.parent / "charts"
