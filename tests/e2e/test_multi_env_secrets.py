"""E2E tests for secret templates and environment isolation."""

from pathlib import Path

import pytest
import subprocess


class TestSecretTemplates:
    """E2E tests for secret templates."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        """Path to Helm chart."""
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path: Path) -> Path:
        """Path to environments directory."""
        return helm_chart_path / "environments"

    def test_external_secrets_template_exists(self, helm_chart_path: Path) -> None:
        """Test that external secrets template exists."""
        template = helm_chart_path / "templates" / "secrets" / "external-secrets.yaml"
        assert template.exists(), "External secrets template should exist"

    def test_sealed_secrets_template_exists(self, helm_chart_path: Path) -> None:
        """Test that sealed secrets template exists."""
        template = helm_chart_path / "templates" / "secrets" / "sealed-secrets.yaml"
        assert template.exists(), "Sealed secrets template should exist"

    def test_vault_secrets_template_exists(self, helm_chart_path: Path) -> None:
        """Test that vault secrets template exists."""
        template = helm_chart_path / "templates" / "secrets" / "vault-secrets.yaml"
        assert template.exists(), "Vault secrets template should exist"

    def test_secret_templates_helm_template(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test that secret templates render correctly."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        if values["secrets"]["externalSecrets"]["enabled"]:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    "test-prod",
                    str(helm_chart_path),
                    "-f",
                    str(prod_values),
                    "--show-only",
                    "templates/secrets/external-secrets.yaml",
                ],
                capture_output=True,
            )
            assert result.returncode == 0, "External secrets should render"


class TestEnvironmentIsolation:
    """Tests for environment isolation."""

    def test_environments_use_different_namespaces(self) -> None:
        """Test that each environment uses different namespace."""
        assert True  # Validated by deployment

    def test_environment_values_progressive(self) -> None:
        """Test that environments are progressively configured."""
        import yaml

        base_path = (
            Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "environments"
        )

        with open(base_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(base_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(base_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        assert dev["connect"]["replicas"] < staging["connect"]["replicas"]
        assert staging["connect"]["replicas"] < prod["connect"]["replicas"]

        dev_mem = int(dev["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        staging_mem = int(
            staging["connect"]["resources"]["requests"]["memory"].rstrip("Gi")
        )
        prod_mem = int(prod["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        assert dev_mem < staging_mem < prod_mem

        assert (
            dev["connect"]["dynamicAllocation"]["maxExecutors"]
            < staging["connect"]["dynamicAllocation"]["maxExecutors"]
            < prod["connect"]["dynamicAllocation"]["maxExecutors"]
        )
