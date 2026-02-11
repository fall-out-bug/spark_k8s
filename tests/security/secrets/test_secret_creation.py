"""
Secret management tests for K8s native secret creation

Tests for Kubernetes Secret creation and validation.
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


class TestSecretCreation:
    """Tests for K8s Secret creation"""

    def test_secret_can_be_rendered(self, chart_35_path, preset_35_baseline):
        """Test that Secret template can be rendered"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        # Check if there's a secret template
        docs = parse_yaml_docs(output)
        secrets = [d for d in docs if d and d.get("kind") == "Secret"]

        # At least one secret should be defined (or preset uses existingSecret)
        if len(secrets) == 0:
            # Check that preset uses existingSecret instead
            with open(preset_35_baseline) as f:
                preset_values = yaml.safe_load(f)

            # Verify that S3 credentials use existingSecret
            s3_config = preset_values.get("global", {}).get("s3", {})
            if s3_config.get("enabled", False):
                assert s3_config.get("existingSecret") != "", \
                    "Should use existingSecret for S3 credentials"

    def test_secret_has_correct_type(self, chart_35_path, preset_35_baseline):
        """Test that Secret has correct type (Opaque, TLS, etc.)"""
        output = helm_template(chart_35_path, [preset_35_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)
        secrets = [d for d in docs if d and d.get("kind") == "Secret"]

        for secret in secrets:
            secret_type = secret.get("type", "Opaque")
            assert secret_type in ["Opaque", "kubernetes.io/tls", "kubernetes.io/basic-auth",
                                  "kubernetes.io/dockerconfigjson"], \
                f"Secret type should be valid, got {secret_type}"

    def test_secret_uses_existing_secret_when_configured(self, chart_35_path, preset_35_baseline):
        """Test that Secret uses existingSecret when configured"""
        # Check preset values
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        # Verify S3 credentials use existingSecret
        s3_config = preset_values.get("global", {}).get("s3", {})
        if s3_config.get("enabled", False):
            assert s3_config.get("existingSecret") != "", \
                "S3 credentials should use existingSecret when S3 is enabled"

    def test_postgresql_secret_uses_existing_secret(self, chart_35_path, preset_35_baseline):
        """Test that PostgreSQL secret uses existingSecret"""
        with open(preset_35_baseline) as f:
            preset_values = yaml.safe_load(f)

        postgresql_config = preset_values.get("postgresql", {})
        if postgresql_config.get("enabled", False):
            # Check that database uses existingSecret
            assert postgresql_config.get("existingSecret") != "", \
                "PostgreSQL should use existingSecret for credentials"
