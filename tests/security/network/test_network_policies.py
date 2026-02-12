"""Tests for Network Policies"""

import pytest
from pathlib import Path


class TestNetworkPolicies:
    """Tests for Network Policies"""

    @pytest.fixture(scope="class")
    def network_policy_template(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "templates" / "networking" / "network-policy.yaml"

    def test_network_policy_template_exists(self, network_policy_template):
        """Test that network policy template exists"""
        assert network_policy_template.exists(), "Network policy template should exist"

    def test_default_deny_policy_exists(self, network_policy_template):
        """Test that default-deny policy is defined"""
        content = network_policy_template.read_text()
        assert "spark-default-deny" in content, "Default-deny policy should be defined"
        assert "policyTypes:\n  - Ingress\n  - Egress" in content, "Should block both ingress and egress"

    def test_explicit_allow_rules(self, network_policy_template):
        """Test that explicit allow rules are defined"""
        content = network_policy_template.read_text()
        assert "spark-connect-ingress" in content, "Should allow ingress to Spark Connect"
        assert "spark-connect-egress-dns" in content, "Should allow DNS access"
        assert "s3-egress" in content, "Should allow S3 access"

    def test_policy_selectors_match_spark_components(self, network_policy_template):
        """Test that policy selectors match actual Spark components"""
        content = network_policy_template.read_text()
        # Check for spark-connect selector
        assert "app: spark-connect" in content, "Should select Spark Connect pods"
        # Check for spark-worker selector (if applicable)
        # Note: spark-worker may not be used in all scenarios
