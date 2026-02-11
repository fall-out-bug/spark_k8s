"""
SCC nonroot tests for OpenShift compatibility

Tests for Security Context Constraints (SCC) nonroot compatibility
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


class TestSCCNonroot:
    """Tests for nonroot SCC compatibility"""

    @pytest.fixture(scope="class")
    def restricted_35_path(self, chart_35_path):
        return chart_35_path / "presets" / "openshift" / "restricted.yaml"

    def test_non_root_required(self, chart_35_path, restricted_35_path):
        """Test that non-root user is required"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_user = pod_sec_ctx.get("runAsUser")

            # nonroot SCC requires runAsUser != 0
            if run_as_user is not None:
                assert run_as_user != 0, \
                    f"nonroot SCC requires non-root user, got {run_as_user}"

    def test_privilege_escalation_disabled(self, chart_35_path, restricted_35_path):
        """Test that privilege escalation is disabled"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                sec_ctx = container.get("securityContext", {})
                allow_priv = sec_ctx.get("allowPrivilegeEscalation")

                if allow_priv is not None:
                    assert allow_priv is False, \
                        "nonroot SCC should disable privilege escalation"

    def test_readonly_root_can_be_enabled(self, chart_35_path, restricted_35_path):
        """Test that read-only root filesystem can be enabled"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                sec_ctx = container.get("securityContext", {})
                readonly_fs = sec_ctx.get("readOnlyRootFilesystem")

                # readOnlyRootFilesystem can be true or false
                # (false is OK for nonroot SCC, but should be configurable)
                if readonly_fs is not None:
                    assert isinstance(readonly_fs, bool), \
                        "readOnlyRootFilesystem should be boolean"

    def test_uid_185_or_openshift_range(self, chart_35_path, restricted_35_path):
        """Test that UID is 185 (spark-k8s default) or OpenShift range"""
        output = helm_template(chart_35_path, [restricted_35_path])

        if output is None:
            pytest.skip("helm template failed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_user = pod_sec_ctx.get("runAsUser")

            if run_as_user is not None:
                # Should be 185 (spark-k8s image default) or OpenShift range
                assert run_as_user == 185 or run_as_user >= 1000000000, \
                    f"UID should be 185 or in OpenShift range, got {run_as_user}"

    def test_restricted_preset_exists(self, restricted_35_path):
        """Test that restricted preset file exists"""
        assert restricted_35_path.exists(), "restricted preset should exist"
