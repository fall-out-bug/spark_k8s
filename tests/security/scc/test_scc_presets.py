"""
SCC presets tests for OpenShift configurations

Tests for OpenShift preset configurations and SCC compatibility.
"""

import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    chart_35_path,
    chart_41_path,
)


class TestSCCPresets:
    """Tests for OpenShift preset configurations"""

    @pytest.fixture(scope="class")
    def anyuid_35_path(self, chart_35_path):
        return chart_35_path / "presets" / "openshift" / "anyuid.yaml"

    @pytest.fixture(scope="class")
    def restricted_35_path(self, chart_35_path):
        return chart_35_path / "presets" / "openshift" / "restricted.yaml"

    @pytest.fixture(scope="class")
    def anyuid_41_path(self, chart_41_path):
        return chart_41_path / "presets" / "openshift" / "anyuid.yaml"

    @pytest.fixture(scope="class")
    def restricted_41_path(self, chart_41_path):
        return chart_41_path / "presets" / "openshift" / "restricted.yaml"

    def test_anyuid_preset_valid_for_anyuid_scc(self, anyuid_35_path):
        """Test that anyuid preset is valid for anyuid SCC"""
        with open(anyuid_35_path) as f:
            preset_values = yaml.safe_load(f)

        security_config = preset_values.get("security", {})

        # anyuid preset should bypass PSS (or use privileged)
        pss_enabled = security_config.get("podSecurityStandards", True)
        assert pss_enabled is False or \
               security_config.get("pssProfile") in ["privileged", "baseline"], \
            "anyuid preset should bypass PSS or use privileged profile"

    def test_restricted_preset_valid_for_restricted_scc(self, restricted_35_path):
        """Test that restricted preset is valid for restricted-v2 SCC"""
        with open(restricted_35_path) as f:
            preset_values = yaml.safe_load(f)

        security_config = preset_values.get("security", {})

        # restricted preset should enable PSS restricted
        pss_enabled = security_config.get("podSecurityStandards", False)
        assert pss_enabled is True, "restricted preset should enable PSS"

        pss_profile = security_config.get("pssProfile", "")
        assert pss_profile == "restricted", \
            f"restricted preset should use PSS restricted profile, got {pss_profile}"

    def test_anyuid_external_s3_configured(self, anyuid_35_path):
        """Test that anyuid preset uses external S3"""
        with open(anyuid_35_path) as f:
            preset_values = yaml.safe_load(f)

        s3_config = preset_values.get("global", {}).get("s3", {})

        # Should have endpoint and existingSecret configured
        endpoint = s3_config.get("endpoint", "")
        existing_secret = s3_config.get("existingSecret", "")

        assert endpoint != "", "anyuid preset should configure S3 endpoint"
        assert existing_secret != "", "anyuid preset should use existingSecret for S3 credentials"

    def test_restricted_external_s3_configured(self, restricted_35_path):
        """Test that restricted preset uses external S3"""
        with open(restricted_35_path) as f:
            preset_values = yaml.safe_load(f)

        s3_config = preset_values.get("global", {}).get("s3", {})

        # Should have endpoint and existingSecret configured
        endpoint = s3_config.get("endpoint", "")
        existing_secret = s3_config.get("existingSecret", "")

        assert endpoint != "", "restricted preset should configure S3 endpoint"
        assert existing_secret != "", "restricted preset should use existingSecret for S3 credentials"

    def test_anyuid_external_postgresql_configured(self, anyuid_35_path):
        """Test that anyuid preset uses external PostgreSQL"""
        with open(anyuid_35_path) as f:
            preset_values = yaml.safe_load(f)

        hive_config = preset_values.get("hiveMetastore", {})
        postgresql_config = hive_config.get("postgresql", {})

        # Should use external PostgreSQL
        enabled = postgresql_config.get("enabled", True)
        assert enabled is False, "anyuid preset should use external PostgreSQL (not embedded)"

    def test_restricted_external_postgresql_configured(self, restricted_35_path):
        """Test that restricted preset uses external PostgreSQL"""
        with open(restricted_35_path) as f:
            preset_values = yaml.safe_load(f)

        hive_config = preset_values.get("hiveMetastore", {})
        postgresql_config = hive_config.get("postgresql", {})

        # Should use external PostgreSQL
        enabled = postgresql_config.get("enabled", True)
        assert enabled is False, "restricted preset should use external PostgreSQL (not embedded)"

    def test_openshift_presets_for_spark_41(self, anyuid_41_path, restricted_41_path):
        """Test that OpenShift presets exist for Spark 4.1"""
        # At least one preset should exist
        assert anyuid_41_path.exists() or restricted_41_path.exists(), \
            "At least one OpenShift preset should exist for Spark 4.1"

    def test_routes_enabled_in_openshift_presets(self, anyuid_35_path, restricted_35_path):
        """Test that OpenShift Routes are enabled"""
        for preset_path in [anyuid_35_path, restricted_35_path]:
            with open(preset_path) as f:
                preset_values = yaml.safe_load(f)

            routes_config = preset_values.get("routes", {})
            enabled = routes_config.get("enabled", False)

            # Routes should be enabled for OpenShift
            assert enabled is True, \
                f"OpenShift preset should enable Routes, got {enabled}"

    def test_openshift_uid_configuration(self, anyuid_35_path, restricted_35_path):
        """Test that OpenShift presets configure UID correctly"""
        for preset_path in [anyuid_35_path, restricted_35_path]:
            with open(preset_path) as f:
                preset_values = yaml.safe_load(f)

            security_config = preset_values.get("security", {})
            run_as_user = security_config.get("runAsUser")

            # Should configure UID (185 for spark-k8s or OpenShift range)
            if run_as_user is not None:
                assert run_as_user == 185 or run_as_user >= 1000000000, \
                    f"UID should be 185 or in OpenShift range, got {run_as_user}"
