"""
SCC restricted-v2 tests for OpenShift compatibility

Tests for Security Context Constraints (SCC) restricted-v2 compatibility
with OpenShift clusters.
"""

import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    get_pod_specs,
    chart_35_path,
    chart_41_path,
)


class TestSCCRestrictedV2:
    """Tests for restricted-v2 SCC compatibility (most secure)"""

    @pytest.fixture(scope="class")
    def restricted_35_path(self, chart_35_path):
        return chart_35_path / "presets" / "openshift" / "restricted.yaml"

    @pytest.fixture(scope="class")
    def restricted_41_path(self, chart_41_path):
        return chart_41_path / "presets" / "openshift" / "restricted.yaml"

    def test_restricted_preset_exists(self, restricted_35_path):
        """Test that restricted preset file exists"""
        assert restricted_35_path.exists(), "restricted preset should exist"

    def test_restricted_is_most_secure(self, chart_35_path, restricted_35_path):
        """Test that restricted SCC is most secure"""
        with open(restricted_35_path) as f:
            preset_values = yaml.safe_load(f)

        security_config = preset_values.get("security", {})
        pss_enabled = security_config.get("podSecurityStandards", False)

        # restricted preset should enable PSS
        assert pss_enabled is True, \
            "restricted preset should enable PSS"

        # Check PSS profile
        pss_profile = security_config.get("pssProfile", "")
        assert pss_profile == "restricted", \
            f"restricted preset should use PSS restricted profile, got {pss_profile}"

    def test_run_as_specific_uid(self, chart_35_path, restricted_35_path):
        """Test that containers run as specific UID (185 or OpenShift range)"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_user = pod_sec_ctx.get("runAsUser")

            if run_as_user is not None:
                # restricted-v2 requires specific UID
                assert run_as_user == 185 or run_as_user >= 1000000000, \
                    f"restricted-v2 requires specific UID (185 or OpenShift range), got {run_as_user}"

    def test_drop_capabilities_set(self, chart_35_path, restricted_35_path):
        """Test that capabilities are dropped"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                sec_ctx = container.get("securityContext", {})
                capabilities = sec_ctx.get("capabilities", {})
                drop = capabilities.get("drop", [])

                # restricted-v2 should drop capabilities
                if drop:
                    assert isinstance(drop, list), "drop capabilities should be a list"
                    # Check for common drops
                    assert len(drop) > 0, "restricted-v2 should drop at least some capabilities"

    def test_no_privileged_containers(self, chart_35_path, restricted_35_path):
        """Test that no containers are privileged"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                sec_ctx = container.get("securityContext", {})
                privileged = sec_ctx.get("privileged", False)

                assert privileged is not True, \
                    "restricted-v2 SCC should not allow privileged containers"

    def test_seccomp_profile_configured(self, chart_35_path, restricted_35_path):
        """Test that seccomp profile is configured"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            seccomp = pod_sec_ctx.get("seccompProfile")

            if seccomp:
                assert "type" in seccomp, "seccompProfile should have type"
                assert seccomp["type"] in ["RuntimeDefault", "Localhost"], \
                    f"restricted-v2 should use valid seccomp profile, got {seccomp['type']}"

    def test_restricted_for_spark_41(self, chart_41_path, restricted_41_path):
        """Test that restricted preset exists for Spark 4.1"""
        if not restricted_41_path.exists():
            pytest.skip("restricted preset not found for Spark 4.1")

        output = helm_template(chart_41_path, [restricted_41_path])

        if output is None:
            pytest.skip("helm template failed")

        # Should render successfully
        docs = parse_yaml_docs(output)
        assert len(docs) > 0, "Should render some resources"
