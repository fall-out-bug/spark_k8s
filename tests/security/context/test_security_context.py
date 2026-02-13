"""Tests for security context configuration"""

import pytest
import yaml
from pathlib import Path


class TestSecurityContext:
    """Tests for security context configuration"""

    def test_pss_restricted_in_prod(self, repository_root):
        """Test that PSS restricted is enabled in production"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["security"]["podSecurityStandards"] == True, \
            "PSS restricted should be enabled in prod"

    def test_non_root_user(self, repository_root):
        """Test that non-root user is configured"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["security"]["runAsUser"] == 185, \
            "Should run as non-root user (UID 185)"
        assert values["security"]["runAsGroup"] == 185, \
            "Should run as non-root group (GID 185)"

    def test_readonly_root_filesystem_option(self, repository_root):
        """Test that readonly root filesystem can be enabled"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        # Can be true or false depending on requirements
        assert "readOnlyRootFilesystem" in values["security"], \
            "ReadOnlyRootFilesystem should be defined"

    def test_privilege_escalation_disabled(self, repository_root):
        """Test that privilege escalation is disabled"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            content = f.read()
        # Check in security context or pod annotations
        assert "allowPrivilegeEscalation: false" in content or \
               "privileged: false" in content, \
               "Privilege escalation should be disabled"
