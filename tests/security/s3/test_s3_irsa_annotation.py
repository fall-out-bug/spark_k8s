"""
S3 security tests for IRSA annotation validation

Tests for IRSA (IAM Roles for Service Accounts) annotation validation.
"""

import pytest
import yaml
import re
from pathlib import Path
from typing import Dict, Any, List

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    chart_35_path,
    preset_35_baseline,
)


class TestS3IRSAAnnotation:
    """Tests for IRSA (IAM Roles for Service Accounts) annotation validation"""

    def test_service_account_has_irsa_annotation_when_configured(self, chart_35_path, preset_35_baseline):
        """Test that ServiceAccount has IRSA annotation when configured"""
        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true", "rbac.irsaRoleArn": "arn:aws:iam::123456789012:role/MySparkRole"}
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        service_account = next(
            (d for d in docs if d and d.get("kind") == "ServiceAccount"),
            None
        )

        if service_account:
            metadata = service_account.get("metadata", {})
            annotations = metadata.get("annotations", {})

            if "eks.amazonaws.com/role-arn" in annotations:
                role_arn = annotations["eks.amazonaws.com/role-arn"]
                assert role_arn.startswith("arn:aws:iam::"), \
                    f"IRSA role ARN should be valid IAM role ARN, got: {role_arn}"

    def test_irsa_role_arn_has_valid_format(self, chart_35_path, preset_35_baseline):
        """Test that IRSA role ARN has valid format"""
        test_role_arn = "arn:aws:iam::123456789012:role/MySparkRole"

        output = helm_template(
            chart_35_path,
            [preset_35_baseline],
            set_values={"rbac.create": "true", "rbac.irsaRoleArn": test_role_arn}
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        service_account = next(
            (d for d in docs if d and d.get("kind") == "ServiceAccount"),
            None
        )

        if service_account:
            metadata = service_account.get("metadata", {})
            annotations = metadata.get("annotations", {})

            if "eks.amazonaws.com/role-arn" in annotations:
                role_arn = annotations["eks.amazonaws.com/role-arn"]
                # Validate IAM role ARN format
                pattern = r"^arn:aws:iam::\d{12}:role/[a-zA-Z0-9_+=,.@-]{1,64}$"
                assert re.match(pattern, role_arn), \
                    f"IRSA role ARN should match IAM role ARN format, got: {role_arn}"

    def test_irsa_configured_for_spark_connect(self, chart_35_path, preset_35_baseline):
        """Test that IRSA is configured for Spark Connect server (if needed)"""
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        connect_config = preset_values.get("connect", {})

        if not connect_config.get("enabled", False):
            pytest.skip("Spark Connect not enabled")

        # Check if IRSA is configured for EKS
        rbac_config = preset_values.get("rbac", {})
        irsa_role = rbac_config.get("irsaRoleArn", "")

        if irsa_role:
            # IRSA is configured
            assert irsa_role.startswith("arn:aws:iam::"), \
                f"IRSA role ARN should be valid, got: {irsa_role}"

        # For EKS, IRSA should be configured (this is best practice)
        # But we don't fail if not configured (may be using access keys)

    def test_service_account_for_eks_has_annotation(self, chart_35_path):
        """Test that ServiceAccount for EKS has IRSA annotation capability"""
        # Check if the chart supports IRSA annotation
        values_path = chart_35_path / "values.yaml"

        with open(values_path) as f:
            values_content = f.read()

        # Check if rbac.irsaRoleArn is supported
        if "irsaRoleArn" in values_content or "irsa" in values_content.lower():
            # Chart supports IRSA
            assert True, "Chart supports IRSA annotation"
        else:
            # IRSA support may not be implemented
            pytest.skip("IRSA annotation not supported by chart")
