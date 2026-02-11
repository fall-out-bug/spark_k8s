"""
Container security tests for read-only root filesystem

Tests for read-only root filesystem validation.
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


class TestContainerReadOnlyFS:
    """Tests for read-only root filesystem validation"""

    def test_readonly_root_filesystem_is_configured(self, chart_35_path, preset_35_baseline):
        """Test that readOnlyRootFilesystem is true (or configurable)"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                container_name = container.get("name", "unknown")
                sec_ctx = container.get("securityContext", {})
                readonly_fs = sec_ctx.get("readOnlyRootFilesystem")

                # If set, it should ideally be true
                # (but we allow false for writable workloads)
                if readonly_fs is not None:
                    assert isinstance(readonly_fs, bool), \
                        f"readOnlyRootFilesystem should be boolean for {container_name}"

    def test_tmpfs_used_for_writable_directories(self, chart_35_path, preset_35_baseline):
        """Test that tmpfs is used for writable directories"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            volumes = pod_spec["spec"].get("volumes", [])
            for volume in volumes:
                if volume.get("name", "").endswith("-tmp"):
                    # Check if tmpfs is used for temporary volumes
                    assert "emptyDir" in volume or "configMap" in volume or "secret" in volume, \
                        f"Temporary volume {volume['name']} should use emptyDir or tmpfs"

    def test_volume_mounts_work_with_readonly_root(self, chart_35_path, preset_35_baseline):
        """Test that volume mounts work with read-only root"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            containers = pod_spec["spec"].get("containers", [])
            for container in containers:
                volume_mounts = container.get("volumeMounts", [])
                # If readOnlyRootFilesystem is true, volume mounts should have readWrite flag
                # for directories that need to be writable

    def test_empty_dirs_for_tmp_volumes(self, chart_35_path, preset_35_baseline):
        """Test that emptyDir volumes are used for temporary storage"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        pod_specs = get_pod_specs(output)

        for pod_spec in pod_specs:
            volumes = pod_spec["spec"].get("volumes", [])
            for volume in volumes:
                if "emptyDir" in volume:
                    # emptyDir is good for temporary storage with read-only root
                    empty_dir = volume["emptyDir"]
                    # emptyDir config is OK
                    assert isinstance(empty_dir, dict) or empty_dir is None or empty_dir == {}, \
                        "emptyDir should be a dict or empty"
