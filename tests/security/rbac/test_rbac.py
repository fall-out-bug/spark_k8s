"""Tests for RBAC configuration"""

import pytest
import subprocess
import yaml
from pathlib import Path


class TestRBAC:
    """Tests for RBAC configuration"""

    def test_rbac_enabled_in_prod(self, repository_root):
        """Test that RBAC is enabled in production"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert "rbac" in values, "RBAC section should exist"
        assert values["rbac"]["create"] == True, "RBAC should be created"

    def test_rbac_uses_least_privilege(self, chart_41_path):
        """Test that RBAC follows least privilege"""
        # Check RBAC template
        rbac_template = chart_41_path / "templates" / "rbac" / "role.yaml"
        assert rbac_template.exists(), "RBAC template should exist"

        content = rbac_template.read_text()
        # Check for minimal permissions
        assert "verbs:" in content, "RBAC should define verbs"
        # Should not have wildcard permissions
        assert not '"*"' in content, "No wildcard permissions"

    def test_serviceaccount_created(self, chart_41_path, repository_root):
        """Test that ServiceAccount is created"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        result = subprocess.run(
            ["helm", "template", "test", str(chart_41_path),
            "-f", str(prod_values),
            "--show-only", "templates/rbac/serviceaccount.yaml"],
            capture_output=True
        )
        assert result.returncode == 0, "ServiceAccount template should render"
        assert "ServiceAccount" in result.stdout.decode(), "ServiceAccount should be created"
