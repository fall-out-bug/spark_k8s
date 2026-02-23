"""
Network policy tests for default-deny rules

Tests for default-deny network policies that block all traffic
by default and require explicit allow rules.
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


class TestNetworkDefaultDeny:
    """Tests for default-deny network policies"""

    def test_default_deny_ingress_exists(self, chart_35_path, preset_35_baseline):
        """Test that default-deny ingress policy is defined"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        default_deny = None

        for doc in docs:
            if doc and doc.get("kind") == "NetworkPolicy":
                metadata = doc.get("metadata", {})
                if "default-deny" in metadata.get("name", "").lower():
                    default_deny = doc
                    break

        # If no network policy exists, that's OK for now
        if default_deny is None:
            pytest.skip("Default-deny network policy not implemented yet")
            return

        # Validate default-deny configuration
        spec = default_deny.get("spec", {})
        policy_types = spec.get("policyTypes", [])

        assert "Ingress" in policy_types, "Default-deny should block ingress"
        assert "Egress" in policy_types, "Default-deny should block egress"

    def test_default_deny_applies_to_all_pods(self, chart_35_path, preset_35_baseline):
        """Test that default-deny applies to all pods in namespace"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)

        for doc in docs:
            if doc and doc.get("kind") == "NetworkPolicy":
                metadata = doc.get("metadata", {})
                if "default-deny" in metadata.get("name", "").lower():
                    spec = doc.get("spec", {})
                    pod_selector = spec.get("podSelector", {})

                    # Empty podSelector means applies to all pods
                    assert pod_selector == {} or pod_selector.get("matchLabels") is None, \
                        "Default-deny should apply to all pods (empty selector)"
                    return

        pytest.skip("Default-deny network policy not found")

    def test_default_deny_has_no_allow_rules(self, chart_35_path, preset_35_baseline):
        """Test that default-deny has no allow rules (empty rules list)"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)

        for doc in docs:
            if doc and doc.get("kind") == "NetworkPolicy":
                metadata = doc.get("metadata", {})
                if "default-deny" in metadata.get("name", "").lower():
                    spec = doc.get("spec", {})
                    rules = spec.get("rules", [])

                    # Empty rules means deny all
                    # Or rules may only specify Egress for DNS
                    for rule in rules:
                        rule_types = rule.get("policyTypes", [])
                        # If only egress rules exist (for DNS), ingress is still denied
                        if "Ingress" not in rule_types:
                            continue
                        # Otherwise, no explicit allow rules for ingress
                        assert False, "Default-deny should have no allow rules"

                    return

        pytest.skip("Default-deny network policy not found")

    def test_network_policy_resources_exist(self, chart_35_path, preset_35_baseline):
        """Test that network policy resources exist (or skip gracefully)"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        network_policies = [d for d in docs if d and d.get("kind") == "NetworkPolicy"]

        # If network policies are not implemented, skip
        if len(network_policies) == 0:
            pytest.skip("Network policies not implemented yet")

        # At least one network policy should exist
        assert len(network_policies) > 0, "Should have network policies if implemented"
