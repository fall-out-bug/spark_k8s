"""Tests for Network Policies"""

import pytest
from pathlib import Path


class TestNetworkPolicies:
    """Tests for Network Policies"""

    def test_network_policy_template_exists(self, chart_41_path):
        """Test that network policy template exists"""
        network_policy_template = chart_41_path / "templates" / "networking" / "network-policy.yaml"
        assert network_policy_template.exists(), "Network policy template should exist"

    def test_default_deny_policy_exists(self, chart_41_path):
        """Test that default-deny policy is defined"""
        network_policy_template = chart_41_path / "templates" / "networking" / "network-policy.yaml"
        content = network_policy_template.read_text()
        assert "spark-default-deny" in content, "Default-deny policy should be defined"
        assert "policyTypes:\n  - Ingress\n  - Egress" in content, "Should block both ingress and egress"

    def test_explicit_allow_rules(self, chart_41_path):
        """Test that explicit allow rules are defined"""
        network_policy_template = chart_41_path / "templates" / "networking" / "network-policy.yaml"
        content = network_policy_template.read_text()
        assert "spark-connect-ingress" in content, "Should allow ingress to Spark Connect"
        assert "spark-connect-egress-dns" in content, "Should allow DNS access"
        assert "s3-egress" in content, "Should allow S3 access"

    def test_policy_selectors_match_spark_components(self, chart_41_path):
        """Test that policy selectors match actual Spark components"""
        network_policy_template = chart_41_path / "templates" / "networking" / "network-policy.yaml"
        content = network_policy_template.read_text()
        # Check for spark-connect selector
        assert "app: spark-connect" in content, "Should select Spark Connect pods"
        # Check for spark-worker selector (if applicable)
        # Note: spark-worker may not be used in all scenarios
