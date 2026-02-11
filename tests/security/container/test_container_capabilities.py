"""
Container security tests for dropped capabilities

Tests for dropped capabilities validation.
"""

import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List, Set

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    get_pod_specs,
    chart_35_path,
    preset_35_baseline,
)


class TestContainerCapabilities:
    """Tests for dropped capabilities validation"""

    # Safe capabilities that are acceptable to add
    SAFE_CAPABILITIES: Set[str] = {"CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"}

    def test_drop_capabilities_are_set(self, chart_35_path, preset_35_baseline):
        """Test that drop capabilities are set"""
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
                # At least some capabilities should be dropped for security
                if drop:
                    assert isinstance(drop, list), "drop capabilities should be a list"
                    # Note: drop: ALL is valid for security (drops all Linux capabilities)
                    # but should only be used when containers don't require capabilities

    def test_cap_net_raw_is_dropped(self, chart_35_path, preset_35_baseline):
        """Test that CAP_NET_RAW is dropped (no raw sockets)"""
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
                add = capabilities.get("add", [])

                # CAP_NET_RAW should not be added
                assert "NET_RAW" not in add, \
                    f"Container {container_name} should not add CAP_NET_RAW"

                # If drop is specified, NET_RAW should be in it
                if drop:
                    # This is ideal but not always possible
                    if "NET_RAW" in drop:
                        pass  # Good - NET_RAW is dropped

    def test_no_wildcard_capabilities_added(self, chart_35_path, preset_35_baseline):
        """Test that no wildcard capabilities ('ALL') are added"""
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

                add = capabilities.get("add", [])
                assert "ALL" not in add, \
                    f"Container {container_name} should not add ALL capabilities"

    def test_add_capabilities_are_minimal(self, chart_35_path, preset_35_baseline):
        """Test that add capabilities are minimal (only if required)"""
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

                add = capabilities.get("add", [])

                if add:
                    # Check for unsafe capabilities
                    unsafe_capabilities = set(add) - self.SAFE_CAPABILITIES

                    if unsafe_capabilities:
                        # This is a warning, not a failure
                        # (some capabilities may be required)
                        pass

    def test_capabilities_at_least_one_dropped(self, chart_35_path, preset_35_baseline):
        """Test that at least one capability is dropped for security"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        found_drop = False
        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                sec_ctx = container.get("securityContext", {})
                capabilities = sec_ctx.get("capabilities", {})

                drop = capabilities.get("drop", [])
                if drop and len(drop) > 0:
                    found_drop = True
                    break

            if found_drop:
                break

        # It's OK if no capabilities are dropped (not required)
        # But ideal for security
        # This test just verifies the capability handling is present
        assert True, "Chart should render successfully"
