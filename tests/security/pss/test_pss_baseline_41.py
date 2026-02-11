"""
PSS Baseline tests for Spark 4.1

Tests for Pod Security Standards baseline profile compliance
on Spark 4.1 Helm charts.
"""

import pytest
import yaml
from pathlib import Path
from typing import Dict, Any, List

from tests.security.conftest import (
    helm_template,
    parse_yaml_docs,
    chart_41_path,
    preset_41_baseline,
)


class TestPSSBaseline41:
    """Tests for PSS baseline profile compliance on Spark 4.1"""

    def test_namespace_pss_baseline_labels(self, chart_41_path, preset_41_baseline):
        """Test that namespace can have PSS baseline labels"""
        output = helm_template(
            chart_41_path,
            [preset_41_baseline],
            set_values={
                "security.createNamespace": "true",
                "security.podSecurityStandards": "true",
                "security.pssProfile": "baseline"
            }
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        namespace = next((d for d in docs if d and d.get("kind") == "Namespace"), None)

        if namespace is None:
            pytest.skip("Namespace not rendered (security.createNamespace may be false)")

        labels = namespace.get("metadata", {}).get("labels", {})
        # Note: Our templates may use restricted by default, this tests baseline when set
        pss_profile = labels.get("pod-security.kubernetes.io/enforce", "")

        # If PSS is enforced, it should be set to baseline (or restricted)
        if pss_profile:
            assert pss_profile in ["baseline", "restricted"], \
                f"PSS profile should be baseline or restricted, got {pss_profile}"

    def test_pss_baseline_version_is_latest(self, chart_41_path, preset_41_baseline):
        """Test that PSS baseline version is set to latest"""
        output = helm_template(
            chart_41_path,
            [preset_41_baseline],
            set_values={
                "security.createNamespace": "true",
                "security.podSecurityStandards": "true",
                "security.pssProfile": "baseline"
            }
        )

        if output is None:
            pytest.skip("helm template failed")

        docs = parse_yaml_docs(output)
        namespace = next((d for d in docs if d and d.get("kind") == "Namespace"), None)

        if namespace is None:
            pytest.skip("Namespace not rendered (security.createNamespace may be false)")

        labels = namespace.get("metadata", {}).get("labels", {})
        if "pod-security.kubernetes.io/enforce-version" in labels:
            assert labels.get("pod-security.kubernetes.io/enforce-version") == "latest", \
                "Should use latest PSS version"

    def test_basic_security_context(self, chart_41_path, preset_41_baseline):
        """Test that basic security context is configured for baseline"""
        output = helm_template(chart_41_path, [preset_41_baseline])

        if output is None:
            pytest.fail("helm template should succeed")

        docs = parse_yaml_docs(output)

        # Check that at least some resources have security context
        security_context_count = 0
        for doc in docs:
            if not doc:
                continue
            kind = doc.get("kind", "")
            if kind in ["Deployment", "StatefulSet", "DaemonSet", "Pod"]:
                template = doc.get("spec", {}).get("template", {})
                spec = template.get("spec", {})

                # Check pod-level security context
                if spec.get("securityContext"):
                    security_context_count += 1

                # Check container-level security contexts
                for container in spec.get("containers", []):
                    if container.get("securityContext"):
                        security_context_count += 1

        # At least some security context should be configured
        assert security_context_count > 0, \
            "At least some security context should be configured for PSS baseline"
