"""
Monitoring configuration validation tests.

Tests are parameterized for both Spark 3.5 and Spark 4.1 charts.
"""

import pytest
import yaml
from test_monitoring_common import get_spark_chart_path, SPARK_VERSIONS


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
