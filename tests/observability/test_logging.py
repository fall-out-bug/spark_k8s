"""
JSON logging configuration validation tests.

Tests are parameterized for both Spark 3.5 and Spark 4.1.
"""

import pytest
from test_monitoring_common import get_docker_dir, SPARK_VERSIONS


class TestJSONLogging:
    """Tests for JSON logging configuration"""

    @pytest.fixture(scope="class", params=SPARK_VERSIONS)
    def log4j2_config(self, request):
        version = request.param
        return get_docker_dir(version) / "conf" / "log4j2.properties", version

    def test_log4j2_has_json_appender(self, log4j2_config):
        """Test that log4j2.properties has JSON appender"""
        config_path, version = log4j2_config
        if not config_path.exists():
            pytest.skip(f"Spark {version} has no docker/conf/log4j2.properties (structure differs)")
        content = config_path.read_text()
        assert "json_console" in content or "JsonLayout" in content, f"Spark {version} should have JSON appender"

    def test_log4j2_json_compact(self, log4j2_config):
        """Test that JSON appender uses compact format"""
        config_path, version = log4j2_config
        if not config_path.exists():
            pytest.skip(f"Spark {version} has no docker/conf/log4j2.properties")
        content = config_path.read_text()
        assert "compact = true" in content or "compact=true" in content, f"Spark {version} JSON should be compact"

    def test_log4j2_custom_fields(self, log4j2_config):
        """Test that JSON appender includes custom fields"""
        config_path, version = log4j2_config
        if not config_path.exists():
            pytest.skip(f"Spark {version} has no docker/conf/log4j2.properties")
        content = config_path.read_text()
        assert "service" in content, f"Spark {version} should include service field"
        assert "environment" in content, f"Spark {version} should include environment field"

    def test_log4j2_has_file_appender(self, log4j2_config):
        """Test that log4j2.properties has file appender"""
        config_path, version = log4j2_config
        if not config_path.exists():
            pytest.skip(f"Spark {version} has no docker/conf/log4j2.properties")
        content = config_path.read_text()
        assert "RollingFile" in content or "file" in content.lower(), f"Spark {version} should have file appender"
