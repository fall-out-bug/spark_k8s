"""Load tests for resource configuration and secret providers."""

import os
import subprocess
import tempfile
from pathlib import Path

import pytest
import yaml


class TestResourceLimits:
    """Tests for resource configuration validation."""

    @pytest.fixture(scope="class")
    def environments_path(self) -> Path:
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "environments"

    def test_resource_progression(self, environments_path: Path) -> None:
        """Test that resources progressively increase."""
        with open(environments_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(environments_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(environments_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        dev_mem = int(dev["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        staging_mem = int(
            staging["connect"]["resources"]["requests"]["memory"].rstrip("Gi")
        )
        prod_mem = int(prod["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))

        assert dev_mem == 2, f"Dev should use 2Gi, got {dev_mem}Gi"
        assert staging_mem == 4, f"Staging should use 4Gi, got {staging_mem}Gi"
        assert prod_mem == 8, f"Prod should use 8Gi, got {prod_mem}Gi"
        assert dev_mem < staging_mem < prod_mem

    def test_executor_scaling_progression(self, environments_path: Path) -> None:
        """Test that executor limits progressively increase."""
        with open(environments_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(environments_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(environments_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        dev_max = dev["connect"]["dynamicAllocation"]["maxExecutors"]
        staging_max = staging["connect"]["dynamicAllocation"]["maxExecutors"]
        prod_max = prod["connect"]["dynamicAllocation"]["maxExecutors"]

        assert dev_max == 5, f"Dev max executors should be 5, got {dev_max}"
        assert staging_max == 20, f"Staging max executors should be 20, got {staging_max}"
        assert prod_max == 50, f"Prod max executors should be 50, got {prod_max}"
        assert dev_max < staging_max < prod_max

    def test_ha_configuration_prod_only(self, environments_path: Path) -> None:
        """Test that only prod has podDisruptionBudget."""
        with open(environments_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(environments_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(environments_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        assert not dev["connect"]["podDisruptionBudget"]["enabled"]
        assert not staging["connect"]["podDisruptionBudget"]["enabled"]
        assert prod["connect"]["podDisruptionBudget"]["enabled"]
        assert prod["connect"]["podDisruptionBudget"]["minAvailable"] == 2


@pytest.mark.load
class TestSecretProviderVariants:
    """Tests for all secret provider variants."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    def test_external_secrets_all_providers(self, helm_chart_path: Path) -> None:
        """Test that external secrets template supports all providers."""
        providers = ["aws", "gcp", "azure", "ibm"]
        for provider in providers:
            test_values = {
                "secrets": {
                    "externalSecrets": {
                        "enabled": True,
                        "provider": provider,
                        "region": "us-east-1",
                        "prefix": "test",
                    }
                }
            }
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".yaml", delete=False
            ) as f:
                yaml.dump(test_values, f)
                test_values_path = f.name
            try:
                result = subprocess.run(
                    [
                        "helm",
                        "template",
                        "test",
                        str(helm_chart_path),
                        "-f",
                        test_values_path,
                        "--show-only",
                        "templates/secrets/external-secrets.yaml",
                    ],
                    capture_output=True,
                )
                assert result.returncode == 0, f"Should render for {provider}"
            finally:
                os.unlink(test_values_path)

    def test_secret_template_independence(self, helm_chart_path: Path) -> None:
        """Test that secret templates are independent."""
        templates = [
            "templates/secrets/external-secrets.yaml",
            "templates/secrets/sealed-secrets.yaml",
            "templates/secrets/vault-secrets.yaml",
        ]
        min_values = {"secrets": {"vault": {"enabled": False}}}
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".yaml", delete=False
        ) as f:
            yaml.dump(min_values, f)
            test_values_path = f.name
        try:
            for template in templates:
                subprocess.run(
                    [
                        "helm",
                        "template",
                        "test",
                        str(helm_chart_path),
                        "-f",
                        test_values_path,
                        "--show-only",
                        template,
                    ],
                    capture_output=True,
                )
        finally:
            os.unlink(test_values_path)
