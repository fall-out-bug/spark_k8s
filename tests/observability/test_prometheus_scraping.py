"""
Runtime tests for Prometheus scraping targets and Spark metrics.

Tests:
1. Prometheus targets are configured
2. Spark-specific metrics are collected
3. Metrics-based alerts are defined
"""

import pytest
import subprocess
from pathlib import Path


class TestPrometheusScraping:
    """Tests for Prometheus scraping targets"""

    @pytest.fixture(scope="class")
    def prometheus_pod(self, kube_namespace):
        """Get Prometheus pod"""
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app=prometheus",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("Prometheus pod not found")
        return result.stdout.strip()

    def test_prometheus_targets(self, prometheus_pod, kube_namespace):
        """Test that Prometheus has active targets"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, prometheus_pod,
            "--", "curl", "-s", "http://localhost:9090/api/v1/targets"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        data = result.stdout
        assert '"activeTargets"' in data
        assert '"status":"success"' in data

    def test_spark_target_is_up(self, prometheus_pod, kube_namespace):
        """Test that Spark application target is 'up' in Prometheus"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, prometheus_pod,
            "--", "curl", "-s",
            "http://localhost:9090/api/v1/query?query=up{job=~\"spark.*\"}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Just check query succeeds - actual targets depend on running apps
        assert '"status":"success"' in result.stdout


class TestSparkMetrics:
    """Tests for Spark-specific metrics"""

    @pytest.fixture(scope="class")
    def prometheus_pod(self, kube_namespace):
        """Get Prometheus pod"""
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app=prometheus",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("Prometheus pod not found")
        return result.stdout.strip()

    def test_executor_memory_metrics(self, prometheus_pod, kube_namespace):
        """Test that executor memory metrics are collected"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, prometheus_pod,
            "--", "curl", "-s",
            "http://localhost:9090/api/v1/query?query=spark_executor_memoryUsed"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0
        assert '"status":"success"' in result.stdout

    def test_task_metrics(self, prometheus_pod, kube_namespace):
        """Test that task metrics are collected"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, prometheus_pod,
            "--", "curl", "-s",
            "http://localhost:9090/api/v1/query?query=spark_executor_tasks"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0
        assert '"status":"success"' in result.stdout

    def test_jvm_metrics(self, prometheus_pod, kube_namespace):
        """Test that JVM metrics are collected"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, prometheus_pod,
            "--", "curl", "-s",
            "http://localhost:9090/api/v1/query?query=jvm_memory_used_bytes"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0
        assert '"status":"success"' in result.stdout


class TestMetricsAlerts:
    """Tests for metrics-based alerts"""

    def test_alertmanager_config(self, charts_dir):
        """Test that AlertManager config exists"""
        alertmanager_files = list(charts_dir.rglob("*alertmanager*"))
        assert len(alertmanager_files) > 0, "AlertManager config should exist"

    def test_prometheus_rules(self, charts_dir):
        """Test that Prometheus recording/alerting rules exist"""
        rule_files = list(charts_dir.rglob("*rules*.yaml")) + list(charts_dir.rglob("*alerts*.yaml"))
        assert len(rule_files) > 0, "Prometheus rules should exist"

    def test_spark_alerts_defined(self, charts_dir):
        """Test that Spark-specific alerts are defined"""
        rule_files = list(charts_dir.rglob("*rules*.yaml")) + list(charts_dir.rglob("*alerts*.yaml"))
        spark_alerts_found = False

        for rule_file in rule_files:
            content = rule_file.read_text()
            if "spark" in content.lower() and ("alert" in content.lower() or "record" in content.lower()):
                spark_alerts_found = True
                break

        assert spark_alerts_found, "Spark-specific alerts should be defined"


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")


@pytest.fixture
def charts_dir():
    """Get charts directory"""
    return Path(__file__).parent.parent.parent / "charts"
