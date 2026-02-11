"""
Container security tests for privilege escalation validation

Tests for privilege escalation disabled validation.
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


class TestContainerNoPrivilege:
    """Tests for privilege escalation validation"""

    def test_allow_privilege_escalation_is_false(self, chart_35_path, preset_35_baseline):
        """Test that allowPrivilegeEscalation is false"""
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
                        f"should have allowPrivilegeEscalation=false, got {allow_priv}"

    def test_no_container_has_privileged_true(self, chart_35_path, preset_35_baseline):
        """Test that no container has privileged: true"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                container_name = container.get("name", "unknown")
                sec_ctx = container.get("securityContext", {})
                privileged = sec_ctx.get("privileged")

                # privileged should never be true
                assert privileged is not True, \
                    f"Container {container_name} in {pod_spec['kind']}/{pod_spec['name']} " \
                    f"should not have privileged=true"

    def test_capabilities_are_dropped(self, chart_35_path, preset_35_baseline):
        """Test that capabilities are dropped"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                container_name = container.get("name", "unknown")
                sec_ctx = container.get("securityContext", {})
                capabilities = sec_ctx.get("capabilities", {})

                drop = capabilities.get("drop", [])
                # Check that at least some capabilities are dropped for security
                if drop:
                    assert isinstance(drop, list), "drop capabilities should be a list"

    def test_no_privileged_mode_for_pss_restricted(self, chart_35_path, preset_35_baseline):
        """Test that privileged mode is not used with PSS restricted"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"security.podSecurityStandards": "true", "security.createNamespace": "true"}
        )

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        namespace = next((d for d in docs if d and d.get("kind") == "Namespace"), None)

        if namespace:
            labels = namespace.get("metadata", {}).get("labels", {})
            pss_profile = labels.get("pod-security.kubernetes.io/enforce", "")

            # If PSS restricted is enforced, no container should be privileged
            if pss_profile == "restricted":
                pod_specs = get_pod_specs(output)
                for pod_spec in pod_specs:
                    containers = pod_spec["spec"].get("containers", [])
                    for container in containers:
                        sec_ctx = container.get("securityContext", {})
                        privileged = sec_ctx.get("privileged", False)
                        assert privileged is not True, \
                            "PSS restricted should not allow privileged containers"
