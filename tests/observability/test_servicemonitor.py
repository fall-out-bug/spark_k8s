"""
ServiceMonitor template validation tests.

Tests are parameterized for both Spark 3.5 and Spark 4.1 charts.
"""

import pytest
from test_monitoring_common import get_spark_chart_path, SPARK_VERSIONS


class TestServiceMonitor:
    """Tests for ServiceMonitor"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def servicemonitor_template(self, request):
        version = request.param
        return get_spark_chart_path(version) / "templates" / "monitoring" / "servicemonitor.yaml", version

    def test_servicemonitor_template_exists(self, servicemonitor_template):
        """Test that ServiceMonitor template exists"""
        template_path, version = servicemonitor_template
        assert template_path.exists(), f"ServiceMonitor template should exist for Spark {version}"

    def test_servicemonitor_has_correct_api_version(self, servicemonitor_template):
        """Test that ServiceMonitor uses correct API version"""
        template_path, version = servicemonitor_template
        content = template_path.read_text()
        assert "apiVersion: monitoring.coreos.com/v1" in content, f"Spark {version} should use monitoring.coreos.com/v1"

    def test_servicemonitor_selects_spark_pods(self, servicemonitor_template):
        """Test that ServiceMonitor selects Spark pods"""
        template_path, version = servicemonitor_template
        content = template_path.read_text()
        assert "matchLabels:" in content, f"Spark {version} should have pod label selector"
        assert "app:" in content, f"Spark {version} should select by app label"

    def test_servicemonitor_metrics_endpoint(self, servicemonitor_template):
        """Test that ServiceMonitor scrapes metrics endpoint"""
        template_path, version = servicemonitor_template
        content = template_path.read_text()
        assert "port: metrics" in content, f"Spark {version} should scrape metrics port"
        assert "path: /metrics" in content, f"Spark {version} should scrape /metrics path"
