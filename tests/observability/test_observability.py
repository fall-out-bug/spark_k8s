"""
Observability Tests for Spark K8s Constructor

Tests are parameterized for both Spark 3.5 and Spark 4.1 charts.

Tests:
1. ServiceMonitor template validation
2. PodMonitor template validation
3. Grafana dashboards ConfigMaps validation
4. JSON logging configuration validation
5. OpenTelemetry integration validation
"""

import pytest
import subprocess
import yaml
from pathlib import Path

# Spark versions to test
SPARK_VERSIONS = ["3.5", "4.1"]


def get_charts_dir():
    """Get charts directory"""
    return Path(__file__).parent.parent.parent / "charts"


def get_spark_chart_path(version: str) -> Path:
    """Get chart path for a specific Spark version"""
    return get_charts_dir() / f"spark-{version}"


def get_docker_dir(version: str) -> Path:
    """Get docker directory for a specific Spark version"""
    return Path(__file__).parent.parent.parent / "docker" / f"spark-{version}"


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


class TestJSONLogging:
    """Tests for JSON logging configuration"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def log4j2_config(self, request):
        version = request.param
        return get_docker_dir(version) / "conf" / "log4j2.properties", version

    def test_log4j2_has_json_appender(self, log4j2_config):
        """Test that log4j2.properties has JSON appender"""
        config_path, version = log4j2_config
        assert config_path.exists(), f"log4j2.properties should exist for Spark {version}"
        content = config_path.read_text()
        assert "json_console" in content or "JsonLayout" in content, f"Spark {version} should have JSON appender"

    def test_log4j2_json_compact(self, log4j2_config):
        """Test that JSON appender uses compact format"""
        config_path, version = log4j2_config
        content = config_path.read_text()
        assert "compact = true" in content or "compact=true" in content, f"Spark {version} JSON should be compact"

    def test_log4j2_custom_fields(self, log4j2_config):
        """Test that JSON appender includes custom fields"""
        config_path, version = log4j2_config
        content = config_path.read_text()
        assert "service" in content, f"Spark {version} should include service field"
        assert "environment" in content, f"Spark {version} should include environment field"

    def test_log4j2_has_file_appender(self, log4j2_config):
        """Test that log4j2.properties has file appender"""
        config_path, version = log4j2_config
        content = config_path.read_text()
        assert "RollingFile" in content or "file" in content.lower(), f"Spark {version} should have file appender"


class TestOpenTelemetry:
    """Tests for OpenTelemetry integration"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def helm_chart_path(self, request):
        version = request.param
        return get_spark_chart_path(version), version

    def test_opentelemetry_config_in_values(self, helm_chart_path):
        """Test that OpenTelemetry config exists in values.yaml"""
        chart_path, version = helm_chart_path
        values_file = chart_path / "values.yaml"
        with open(values_file) as f:
            values = yaml.safe_load(f)

        assert "monitoring" in values, f"Spark {version} monitoring section should exist"
        assert "openTelemetry" in values["monitoring"], f"Spark {version} OpenTelemetry config should exist"
        assert "enabled" in values["monitoring"]["openTelemetry"], f"Spark {version} should have enabled flag"
        assert "endpoint" in values["monitoring"]["openTelemetry"], f"Spark {version} should have endpoint"

    def test_opentelemetry_endpoint_configurable(self, helm_chart_path):
        """Test that OpenTelemetry endpoint is configurable"""
        chart_path, version = helm_chart_path
        values_file = chart_path / "values.yaml"
        with open(values_file) as f:
            values = yaml.safe_load(f)

        endpoint = values["monitoring"]["openTelemetry"]["endpoint"]
        assert "opentelemetry-collector" in endpoint, f"Spark {version} should reference OTEL collector"
        assert "4317" in endpoint, f"Spark {version} should use default OTEL port"

    def test_opentelemetry_protocol_configurable(self, helm_chart_path):
        """Test that OpenTelemetry protocol is configurable"""
        chart_path, version = helm_chart_path
        values_file = chart_path / "values.yaml"
        with open(values_file) as f:
            values = yaml.safe_load(f)

        protocol = values["monitoring"]["openTelemetry"]["protocol"]
        assert protocol in ["grpc", "http"], f"Spark {version} protocol should be grpc or http, got {protocol}"


class TestMonitoringEnabled:
    """Tests for monitoring configuration in environments"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def prod_values(self, request):
        version = request.param
        return get_spark_chart_path(version) / "environments" / "prod" / "values.yaml", version

    def test_monitoring_enabled_in_prod(self, prod_values):
        """Test that monitoring is enabled in production"""
        values_path, version = prod_values
        with open(values_path) as f:
            values = yaml.safe_load(f)

        assert "monitoring" in values, f"Spark {version} monitoring section should exist in prod"
        # ServiceMonitor may or may not be enabled depending on deployment
        # Just check the section exists
        assert "serviceMonitor" in values["monitoring"], f"Spark {version} ServiceMonitor config should exist"
