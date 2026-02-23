"""
S3 security tests for TLS endpoint validation

Tests for S3 TLS in-flight encryption validation.
"""

import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    chart_35_path,
    preset_35_baseline,
)


class TestS3TLSEndpoint:
    """Tests for S3 TLS endpoint validation"""

    def test_s3_endpoint_uses_https_in_prod(self, chart_35_path, preset_35_baseline):
        """Test that S3 endpoint uses HTTPS (not HTTP) in production"""
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        s3_config = preset_values.get("global", {}).get("s3", {})

        if not s3_config.get("enabled", False):
            pytest.skip("S3 not enabled in preset")

        endpoint = s3_config.get("endpoint", "")

        # Check if endpoint is production (not local MinIO)
        is_local_minio = any(
            pattern in endpoint.lower()
            for pattern in ["localhost", "127.0.0.1", "minio", ":9000"]
        )

        if is_local_minio:
            # Local MinIO can use HTTP
            return

        # Production S3 should use HTTPS
        if endpoint and not endpoint.startswith("https://"):
            # For non-local endpoints, HTTPS should be used
            # But allow HTTP for :9000 (MinIO)
            if ":9000" not in endpoint:
                pytest.fail(f"S3 endpoint should use HTTPS for production, got: {endpoint}")

    def test_ssl_enabled_for_external_s3(self, chart_35_path, preset_35_baseline):
        """Test that sslEnabled is true for external S3"""
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        s3_config = preset_values.get("global", {}).get("s3", {})

        if not s3_config.get("enabled", False):
            pytest.skip("S3 not enabled in preset")

        endpoint = s3_config.get("endpoint", "")
        ssl_enabled = s3_config.get("sslEnabled", True)

        # Check if endpoint is production (not local MinIO)
        is_local_minio = any(
            pattern in endpoint.lower()
            for pattern in ["localhost", "127.0.0.1", "minio"]
        )

        if is_local_minio:
            # Local MinIO may not use SSL
            return

        # External S3 should have SSL enabled
        assert ssl_enabled is True, \
            f"sslEnabled should be true for external S3, got: {ssl_enabled}"

    def test_http_only_allowed_for_local_minio(self, chart_35_path, preset_35_baseline):
        """Test that HTTP is only used for local MinIO"""
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        s3_config = preset_values.get("global", {}).get("s3", {})

        if not s3_config.get("enabled", False):
            pytest.skip("S3 not enabled in preset")

        endpoint = s3_config.get("endpoint", "")

        if endpoint and endpoint.startswith("http://"):
            # HTTP should only be used for local MinIO
            is_local_minio = any(
                pattern in endpoint.lower()
                for pattern in ["localhost", "127.0.0.1", "minio"]
            )

            assert is_local_minio, \
                f"HTTP endpoint should only be used for local MinIO, got: {endpoint}"

    def test_path_style_access_for_minio(self, chart_35_path, preset_35_baseline):
        """Test that pathStyleAccess is enabled for MinIO compatibility"""
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        s3_config = preset_values.get("global", {}).get("s3", {})

        if not s3_config.get("enabled", False):
            pytest.skip("S3 not enabled in preset")

        path_style = s3_config.get("pathStyleAccess", False)

        # pathStyleAccess should be true for MinIO
        endpoint = s3_config.get("endpoint", "")
        is_minio = "minio" in endpoint.lower()

        if is_minio:
            assert path_style is True, \
                "pathStyleAccess should be true for MinIO"
