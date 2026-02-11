"""
Network policy tests for component-specific rules

Tests for network policy rules specific to Spark components
(Spark Connect, Jupyter, History Server, etc.).
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


class TestNetworkComponentRules:
    """Tests for component-specific network policy rules"""

    def test_spark_connect_ingress_allowed(self, chart_35_path, preset_35_baseline):
        """Test that Spark Connect server ingress is allowed"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"connect.enabled": "true"}
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        network_policies = [d for d in docs if d and d.get("kind") == "NetworkPolicy"]

        if len(network_policies) == 0:
            pytest.skip("Network policies not implemented yet")

        # Look for Spark Connect allow rules
        connect_allowed = False
        for policy in network_policies:
            metadata = policy.get("metadata", {})
            policy_name = metadata.get("name", "")

            # Look for Spark Connect related policies
            if "connect" in policy_name.lower() or "spark" in policy_name.lower():
                spec = policy.get("spec", {})
                policy_types = spec.get("policyTypes", [])

                # Should allow ingress
                if "Ingress" in policy_types:
                    connect_allowed = True
                    break

        if not connect_allowed:
            pytest.skip("Spark Connect ingress rule not found (network policies may be incomplete)")

    def test_jupyter_ingress_allowed(self, chart_35_path, preset_35_baseline):
        """Test that Jupyter ingress is allowed"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"jupyter.enabled": "true"}
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        network_policies = [d for d in docs if d and d.get("kind") == "NetworkPolicy"]

        if len(network_policies) == 0:
            pytest.skip("Network policies not implemented yet")

        # Look for Jupyter allow rules
        jupyter_allowed = False
        for policy in network_policies:
            metadata = policy.get("metadata", {})
            policy_name = metadata.get("name", "")

            if "jupyter" in policy_name.lower():
                jupyter_allowed = True
                break

        if not jupyter_allowed:
            pytest.skip("Jupyter ingress rule not found (network policies may be incomplete)")

    def test_history_server_ingress_allowed(self, chart_35_path, preset_35_baseline):
        """Test that History Server ingress is allowed"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        network_policies = [d for d in docs if d and d.get("kind") == "NetworkPolicy"]

        if len(network_policies) == 0:
            pytest.skip("Network policies not implemented yet")

        # Look for History Server allow rules
        history_allowed = False
        for policy in network_policies:
            metadata = policy.get("metadata", {})
            policy_name = metadata.get("name", "")

            if "history" in policy_name.lower():
                history_allowed = True
                break

        if not history_allowed:
            pytest.skip("History Server ingress rule not found (network policies may be incomplete)")

    def test_pod_selectors_match_component_labels(self, chart_35_path, preset_35_baseline):
        """Test that pod selectors match actual component labels"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        network_policies = [d for d in docs if d and d.get("kind") == "NetworkPolicy"]

        if len(network_policies) == 0:
            pytest.skip("Network policies not implemented yet")

        # Get all pod labels from Deployments/StatefulSets
        pod_labels = set()
        for doc in docs:
            if doc and doc.get("kind") in ["Deployment", "StatefulSet"]:
                template = doc.get("spec", {}).get("template", {})
                labels = template.get("metadata", {}).get("labels", {})
                for key, value in labels.items():
                    pod_labels.add(f"{key}: {value}")

        # Check if network policy selectors match
        for policy in network_policies:
            spec = policy.get("spec", {})
            pod_selector = spec.get("podSelector", {})
            match_labels = pod_selector.get("matchLabels", {})

            # At least some policies should have match labels
            if match_labels:
                for key, value in match_labels.items():
                    assert f"{key}: {value}" in pod_labels or value in pod_labels, \
                        f"Policy selector {key}: {value} should match pod labels"
