"""
PodMonitor template validation tests.

Tests are parameterized for both Spark 3.5 and Spark 4.1 charts.
"""

import pytest
from test_monitoring_common import get_spark_chart_path, SPARK_VERSIONS


class TestPodMonitor:
    """Tests for PodMonitor"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def podmonitor_template(self, request):
        version = request.param
        return get_spark_chart_path(version) / "templates" / "monitoring" / "podmonitor.yaml", version

    def test_podmonitor_template_exists(self, podmonitor_template):
        """Test that PodMonitor template exists"""
        template_path, version = podmonitor_template
        assert template_path.exists(), f"PodMonitor template should exist for Spark {version}"

    def test_podmonitors_select_executors(self, podmonitor_template):
        """Test that PodMonitor selects executor pods"""
        template_path, version = podmonitor_template
        content = template_path.read_text()
        assert "spark-role: executor" in content, f"Spark {version} should select executor pods"

    def test_podmonitors_scrape_interval(self, podmonitor_template):
        """Test that PodMonitor has scrape interval"""
        template_path, version = podmonitor_template
        content = template_path.read_text()
        assert "interval:" in content, f"Spark {version} should have scrape interval"
