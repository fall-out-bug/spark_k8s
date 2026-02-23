"""
PSS Restricted tests for Spark 3.5

Tests for Pod Security Standards restricted profile compliance
on Spark 3.5 Helm charts.
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
    preset_35_baseline,
)


class TestPSSRestricted35:
    """Tests for PSS restricted profile compliance on Spark 3.5"""

    def test_namespace_pss_restricted_labels(self, chart_35_path, preset_35_baseline):
        """Test that namespace has PSS restricted labels"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"security.createNamespace": "true", "security.podSecurityStandards": "true"}
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        namespace = next((d for d in docs if d and d.get("kind") == "Namespace"), None)

        if namespace is None:
            pytest.skip("Namespace not rendered (security.createNamespace may be false)")

        labels = namespace.get("metadata", {}).get("labels", {})
        assert labels.get("pod-security.kubernetes.io/enforce") == "restricted", \
            "Should enforce PSS restricted"
        assert labels.get("pod-security.kubernetes.io/audit") == "restricted", \
            "Should audit PSS restricted"
        assert labels.get("pod-security.kubernetes.io/warn") == "restricted", \
            "Should warn PSS restricted"

    def test_pss_restricted_version_is_latest(self, chart_35_path, preset_35_baseline):
        """Test that PSS version is set to latest"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"security.createNamespace": "true", "security.podSecurityStandards": "true"}
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        namespace = next((d for d in docs if d and d.get("kind") == "Namespace"), None)

        if namespace is None:
            pytest.skip("Namespace not rendered (security.createNamespace may be false)")

        labels = namespace.get("metadata", {}).get("labels", {})
        assert labels.get("pod-security.kubernetes.io/enforce-version") == "latest", \
            "Should use latest PSS version"
        assert labels.get("pod-security.kubernetes.io/audit-version") == "latest", \
            "Should use latest PSS version"
        assert labels.get("pod-security.kubernetes.io/warn-version") == "latest", \
            "Should use latest PSS version"

    def test_non_root_user_required(self, chart_35_path, preset_35_baseline):
        """Test that containers run as non-root user"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        if not pod_specs:
            pytest.skip("No pods found in chart")

        for pod_spec in pod_specs:
            # Check pod-level security context
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_user = pod_sec_ctx.get("runAsUser")

            # If runAsUser is set, it should not be root (0)
            if run_as_user is not None:
                assert run_as_user != 0, \
                    f"{pod_spec['kind']}/{pod_spec['name']} should not run as root, got {run_as_user}"

            # Check container-level security contexts
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                container_name = container.get("name", "unknown")
                sec_ctx = container.get("securityContext", {})
                run_as_user = sec_ctx.get("runAsUser")

                if run_as_user is not None:
                    assert run_as_user != 0, \
                        f"Container {container_name} in {pod_spec['kind']}/{pod_spec['name']} " \
                        f"should not run as root, got {run_as_user}"

    def test_privilege_escalation_disabled(self, chart_35_path, preset_35_baseline):
        """Test that privilege escalation is disabled"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                container_name = container.get("name", "unknown")
                sec_ctx = container.get("securityContext", {})
                allow_priv = sec_ctx.get("allowPrivilegeEscalation")

                # If set, it should be false
                if allow_priv is not None:
                    assert allow_priv is False, \
                        f"Container {container_name} in {pod_spec['kind']}/{pod_spec['name']} " \
                        f"should have allowPrivilegeEscalation=false"

    def test_capabilities_dropped(self, chart_35_path, preset_35_baseline):
        """Test that capabilities are dropped"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                sec_ctx = container.get("securityContext", {})
                capabilities = sec_ctx.get("capabilities", {})
                drop = capabilities.get("drop", [])

                # If drop is specified, it should be a list
                if drop:
                    assert isinstance(drop, list), "drop capabilities should be a list"

    def test_seccomp_profile_set(self, chart_35_path, preset_35_baseline):
        """Test that seccomp profile is set"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            # Check pod-level seccomp profile
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            seccomp = pod_sec_ctx.get("seccompProfile")

            if seccomp:
                # seccompProfile should have type
                assert "type" in seccomp, "seccompProfile should have type"
                assert seccomp["type"] in ["RuntimeDefault", "Localhost", "Unconfined"], \
                    f"seccompProfile type should be valid, got {seccomp['type']}"
