"""Tests for RBAC configuration"""

import pytest
import subprocess
from pathlib import Path


class TestRBAC:
    """Tests for RBAC configuration"""

    @pytest.fixture(scope="class")
    def helm_chart_path(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def prod_values(self, helm_chart_path):
        prod_values = helm_chart_path / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            return yaml.safe_load(f)

    def test_rbac_enabled_in_prod(self, prod_values):
        """Test that RBAC is enabled in production"""
        assert "rbac" in prod_values, "RBAC section should exist"
        assert prod_values["rbac"]["create"] == True, "RBAC should be created"

    def test_rbac_uses_least_privilege(self, helm_chart_path):
        """Test that RBAC follows least privilege"""
        # Check RBAC template
        rbac_template = self.helm_chart_path() / "templates" / "rbac" / "role.yaml"
        assert rbac_template.exists(), "RBAC template should exist"

        content = rbac_template.read_text()
        # Check for minimal permissions
        assert "verbs:" in content, "RBAC should define verbs"
        # Should not have wildcard permissions
        assert not '"*"' in content, "No wildcard permissions"

    def test_serviceaccount_created(self, helm_chart_path):
        """Test that ServiceAccount is created"""
        result = subprocess.run(
            ["helm", "template", "test", str(self.helm_chart_path()),
            "-f", str(self.helm_chart_path() / "environments" / "prod" / "values.yaml"),
            "--show-only", "templates/rbac/serviceaccount.yaml"],
            capture_output=True
        )
        assert result.returncode == 0, "ServiceAccount template should render"
        assert "ServiceAccount" in result.stdout.decode(), "ServiceAccount should be created"
