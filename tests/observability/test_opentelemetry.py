"""
OpenTelemetry integration validation tests.

Tests are parameterized for both Spark 3.5 and Spark 4.1 charts.
"""

import pytest
import yaml
from test_monitoring_common import get_spark_chart_path, SPARK_VERSIONS


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
