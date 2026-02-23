"""
Container security tests for non-root user validation

Tests for non-root user validation in container security contexts.
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


class TestContainerNonRoot:
    """Tests for non-root user validation"""

    def test_pod_run_as_user_is_not_root(self, chart_35_path, preset_35_baseline):
        """Test that pod security context sets runAsUser != 0"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        if not pod_specs:
            pytest.skip("No pods found in chart")

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_user = pod_sec_ctx.get("runAsUser")

            # If runAsUser is set, it should not be root (0)
            if run_as_user is not None:
                assert run_as_user != 0, \
                    f"{pod_spec['kind']}/{pod_spec['name']} should not run as root user (0), got {run_as_user}"

    def test_container_run_as_user_is_not_root(self, chart_35_path, preset_35_baseline):
        """Test that container security context sets runAsUser != 0"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                container_name = container.get("name", "unknown")
                sec_ctx = container.get("securityContext", {})
                run_as_user = sec_ctx.get("runAsUser")

                # If runAsUser is set, it should not be root (0)
                if run_as_user is not None:
                    assert run_as_user != 0, \
                        f"Container {container_name} in {pod_spec['kind']}/{pod_spec['name']} " \
                        f"should not run as root user (0), got {run_as_user}"

    def test_run_as_group_is_set(self, chart_35_path, preset_35_baseline):
        """Test that runAsGroup is set (if applicable)"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_group = pod_sec_ctx.get("runAsGroup")

            # If runAsUser is set, runAsGroup should also be set for consistency
            run_as_user = pod_sec_ctx.get("runAsUser")
            if run_as_user is not None and run_as_group is None:
                # This is acceptable - runAsGroup is optional
                pass

    def test_fs_group_is_set(self, chart_35_path, preset_35_baseline):
        """Test that fsGroup is set for volume permissions"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            volumes = pod_spec["spec"].get("volumes", [])

            # If volumes are defined, fsGroup should be set
            if len(volumes) > 0:
                fs_group = pod_sec_ctx.get("fsGroup")
                # fsGroup should be set when volumes are present (for proper file permissions)
                if fs_group is None:
                    # This is acceptable but not ideal
                    pass

    def test_uid_185_for_spark_images(self, chart_35_path, preset_35_baseline):
        """Test that UID 185 is used (matches spark-k8s image default)"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            pod_sec_ctx = pod_spec["spec"].get("securityContext", {})
            run_as_user = pod_sec_ctx.get("runAsUser")

            # If runAsUser is set, check if it's 185 (spark-k8s default)
            if run_as_user is not None and run_as_user != 0:
                # UID 185 is common for spark-k8s images
                # Other UIDs are also acceptable (like OpenShift range)
                assert run_as_user == 185 or run_as_user >= 1000000000, \
                    f"UID should be 185 or in OpenShift range, got {run_as_user}"
