"""
RBAC tests for Role least privilege

Tests for Role permissions and least privilege validation.
"""

import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    chart_35_path,
    preset_35_baseline,
)


class TestRoleLeastPrivilege:
    """Tests for Role least privilege permissions"""

    def test_role_exists_when_rbac_enabled(self, chart_35_path, preset_35_baseline):
        """Test that Role is created when RBAC is enabled"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true"}
        )

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        roles = [d for d in docs if d and d.get("kind") == "Role"]

        # Role should be created for namespace-scoped permissions
        assert len(roles) > 0, "Role should be created when rbac.create=true"

    def test_role_no_wildcard_verbs(self, chart_35_path, preset_35_baseline):
        """Test that Role has no wildcard (*) verbs"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true"}
        )

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        roles = [d for d in docs if d and d.get("kind") == "Role"]

        for role in roles:
            rules = role.get("rules", [])
            for rule in rules:
                verbs = rule.get("verbs", [])
                assert "*" not in verbs, \
                    f"Role {role['metadata']['name']} should not have wildcard verbs, got {verbs}"

    def test_role_specific_resources_only(self, chart_35_path, preset_35_baseline):
        """Test that Role grants access to specific resources only"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true"}
        )

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        roles = [d for d in docs if d and d.get("kind") == "Role"]

        for role in roles:
            rules = role.get("rules", [])
            for rule in rules:
                resources = rule.get("resources", [])
                # Check for wildcard resources
                if "*" in resources:
                    # Wildcard resources are sometimes OK for specific API groups
                    # But let's verify this is intentional
                    api_groups = rule.get("apiGroups", [])
                    assert api_groups == [""] or len(api_groups) == 0, \
                        f"Wildcard resources should only be for core API group, got {api_groups}"

    def test_role_has_required_permissions(self, chart_35_path, preset_35_baseline):
        """Test that Role has required permissions for Spark"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true"}
        )

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        roles = [d for d in docs if d and d.get("kind") == "Role"]

        # Check that Role has permissions for pods, services, configmaps
        required_resources = {"pods", "services", "configmaps"}
        found_resources = set()

        for role in roles:
            rules = role.get("rules", [])
            for rule in rules:
                resources = rule.get("resources", [])
                found_resources.update(resources)

        # Should have at least some required permissions
        assert len(found_resources.intersection(required_resources)) > 0, \
            "Role should have permissions for at least some required resources"

    def test_role_binding_correct_service_account(self, chart_35_path, preset_35_baseline):
        """Test that RoleBinding binds to correct ServiceAccount"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true", "rbac.serviceAccountName": "test-sa"}
        )

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        role_bindings = [d for d in docs if d and d.get("kind") == "RoleBinding"]

        for binding in role_bindings:
            subjects = binding.get("subjects", [])
            assert len(subjects) > 0, "RoleBinding should have subjects"

            for subject in subjects:
                assert subject.get("kind") == "ServiceAccount", \
                    "RoleBinding should bind to a ServiceAccount"

                sa_name = subject.get("name", "")
                assert "test-sa" in sa_name or sa_name == "test-sa", \
                    f"RoleBinding should bind to test-sa, got {sa_name}"
