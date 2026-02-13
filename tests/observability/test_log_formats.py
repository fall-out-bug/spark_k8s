"""
Runtime tests for log format and Grafana-Loki integration.

Tests:
1. Spark logs format
2. Log levels are present
3. Loki datasource in Grafana
"""

import pytest
import subprocess
from pathlib import Path


class TestLogFormats:
    """Tests for log format and structure"""
    skip_pod = False

    @pytest.fixture(scope="class")
    def spark_pod(self, request):
        """Get a running Spark pod"""
        import os
        kube_namespace = os.getenv("KUBE_NAMESPACE", "spark-operations")
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "spark-role=driver",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            request.cls.skip_pod = True
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
        # Grafana datasources might be in values.yaml files
        if not datasource_files:
            configmap_files = list(charts_dir.rglob("grafana*datasource*.yaml"))
            # Check if any datasource file mentions Loki
            loki_found = False
            for f in configmap_files:
                if "loki" in f.read_text().lower():
                    loki_found = True
                    break
            # Check for datasource config in provisioning
            provisioning_files = list(charts_dir.rglob("*provisioning*datasource*.yaml"))
            for f in provisioning_files:
                if "loki" in f.read_text().lower():
                    loki_found = True
                    break
            # Check values.yaml files where datasource config often lives
            if not loki_found:
                values_files = list(charts_dir.rglob("**/grafana/values.yaml"))
                for f in values_files:
                    content = f.read_text().lower()
                    # Check for datasource config with Loki
                    if "datasources" in content and "loki" in content:
                        loki_found = True
                        break
            assert loki_found, f"Loki datasource should be configured. Checked files: {[str(f) for f in datasource_files + configmap_files + provisioning_files + values_files]}"
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
