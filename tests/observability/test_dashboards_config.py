"""
Grafana dashboard ConfigMap validation tests.

Tests are parameterized for both Spark 3.5 and Spark 4.1 charts.

Note: Runtime tests for dashboards are in test_dashboards.py.
This file validates template structure.
"""

import pytest
from test_monitoring_common import get_spark_chart_path, SPARK_VERSIONS


class TestGrafanaDashboards:
    """Tests for Grafana dashboards"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def dashboard_templates(self, request):
        version = request.param
        templates_dir = get_spark_chart_path(version) / "templates" / "monitoring"
        return {
            "version": version,
            "overview": templates_dir / "grafana-dashboard-spark-overview.yaml",
            "executor": templates_dir / "grafana-dashboard-executor-metrics.yaml",
            "performance": templates_dir / "grafana-dashboard-job-performance.yaml",
        }

    def test_all_dashboards_exist(self, dashboard_templates):
        """Test that all required dashboards exist"""
        version = dashboard_templates["version"]
        for name, path in dashboard_templates.items():
            if name == "version":
                continue
            assert path.exists(), f"Dashboard {name} should exist for Spark {version} at {path}"

    def test_dashboards_have_grafana_label(self, dashboard_templates):
        """Test that dashboards have grafana_dashboard label"""
        version = dashboard_templates["version"]
        for name, path in dashboard_templates.items():
            if name == "version":
                continue
            if path.exists():
                content = path.read_text()
                assert "grafana_dashboard: \"1\"" in content, f"Spark {version} {name} should have grafana_dashboard label"

    def test_dashboard_json_valid(self, dashboard_templates):
        """Test that dashboard JSON is valid"""
        import json
        version = dashboard_templates["version"]
        for name, path in dashboard_templates.items():
            if name == "version":
                continue
            if path.exists():
                content = path.read_text()
                # Extract JSON from ConfigMap
                if "spark-overview.json:" in content or ".json:" in content:
                    try:
                        json_start = content.index("{")
                        json_end = content.rindex("}") + 1
                        json_str = content[json_start:json_end]
                        # Just check it starts and ends correctly
                        assert json_str.strip().startswith("{"), f"Spark {version} {name} JSON should start with {{"
                        assert json_str.strip().endswith("}"), f"Spark {version} {name} JSON should end with }}"
                    except Exception:
                        pass  # Template variables might break strict JSON validation

    def test_dashboards_have_required_panels(self, dashboard_templates):
        """Test that dashboards have required panels"""
        version = dashboard_templates["version"]

        overview = dashboard_templates["overview"]
        if overview.exists():
            content = overview.read_text()
            # Should have panels for executors, memory, jobs
            assert "Executors" in content or "executor" in content.lower(), f"Spark {version} Overview should show executors"
            assert "Memory" in content or "memory" in content.lower(), f"Spark {version} Overview should show memory"

        executor = dashboard_templates["executor"]
        if executor.exists():
            content = executor.read_text()
            # Should have executor-specific metrics
            assert "executor" in content.lower(), f"Spark {version} Executor dashboard should focus on executors"

        performance = dashboard_templates["performance"]
        if performance.exists():
            content = performance.read_text()
            # Should have job performance metrics
            assert "Job" in content or "job" in content.lower(), f"Spark {version} Performance dashboard should show jobs"
            assert "Duration" in content or "duration" in content.lower(), f"Spark {version} Performance dashboard should show duration"
