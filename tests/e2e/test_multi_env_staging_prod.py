"""E2E tests for staging and production environments."""

from pathlib import Path

import pytest
import subprocess


class TestMultiEnvironmentStaging:
    """E2E tests for staging environment."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        """Path to Helm chart."""
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path: Path) -> Path:
        """Path to environments directory."""
        return helm_chart_path / "environments"

    def test_staging_values_exists(self, environments_path: Path) -> None:
        """Test that staging values file exists."""
        staging_values = environments_path / "staging" / "values.yaml"
        assert staging_values.exists(), "Staging values file should exist"

    def test_staging_helm_lint(self, helm_chart_path: Path, environments_path: Path) -> None:
        """Test that staging chart passes helm lint."""
        staging_values = environments_path / "staging" / "values.yaml"
        result = subprocess.run(
            ["helm", "lint", str(helm_chart_path), "-f", str(staging_values)],
            capture_output=True,
        )
        assert result.returncode == 0, f"Staging chart should lint: {result.stdout.decode()}"

    def test_staging_resources_moderate(self, environments_path: Path) -> None:
        """Test that staging has moderate resources."""
        import yaml

        staging_values = environments_path / "staging" / "values.yaml"
        with open(staging_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["replicas"] == 2, "Staging should have 2 replicas"
        assert values["connect"]["resources"]["requests"]["memory"] == "4Gi"
        assert values["connect"]["dynamicAllocation"]["maxExecutors"] == 20

    def test_staging_monitoring_enabled(self, environments_path: Path) -> None:
        """Test that monitoring is enabled in staging."""
        import yaml

        staging_values = environments_path / "staging" / "values.yaml"
        with open(staging_values) as f:
            values = yaml.safe_load(f)

        assert values["monitoring"]["serviceMonitor"]["enabled"] is True


class TestMultiEnvironmentProd:
    """E2E tests for production environment."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        """Path to Helm chart."""
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path: Path) -> Path:
        """Path to environments directory."""
        return helm_chart_path / "environments"

    def test_prod_values_exists(self, environments_path: Path) -> None:
        """Test that prod values file exists."""
        prod_values = environments_path / "prod" / "values.yaml"
        assert prod_values.exists(), "Prod values file should exist"

    def test_prod_helm_lint(self, helm_chart_path: Path, environments_path: Path) -> None:
        """Test that prod chart passes helm lint."""
        prod_values = environments_path / "prod" / "values.yaml"
        result = subprocess.run(
            ["helm", "lint", str(helm_chart_path), "-f", str(prod_values)],
            capture_output=True,
        )
        assert result.returncode == 0, f"Prod chart should lint: {result.stdout.decode()}"

    def test_prod_replicas_ha(self, environments_path: Path) -> None:
        """Test that prod has HA configuration."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["replicas"] == 3, "Prod should have 3 replicas for HA"
        assert values["connect"]["podDisruptionBudget"]["enabled"] is True
        assert values["connect"]["podDisruptionBudget"]["minAvailable"] == 2

    def test_prod_resources_maximum(self, environments_path: Path) -> None:
        """Test that prod has maximum resources."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["resources"]["requests"]["memory"] == "8Gi"
        assert values["connect"]["dynamicAllocation"]["maxExecutors"] == 50

    def test_prod_external_secrets_required(self, environments_path: Path) -> None:
        """Test that external secrets are required in prod."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["secrets"]["externalSecrets"]["enabled"] is True, (
            "External secrets MUST be enabled in production"
        )

    def test_prod_monitoring_always_enabled(self, environments_path: Path) -> None:
        """Test that monitoring is always enabled in prod."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["monitoring"]["serviceMonitor"]["enabled"] is True

    def test_prod_security_enabled(self, environments_path: Path) -> None:
        """Test that security is enabled in prod."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["security"]["podSecurityStandards"] is True
        assert values["security"]["networkPolicies"]["enabled"] is True

    def test_prod_pod_anti_affinity(self, environments_path: Path) -> None:
        """Test that prod has pod anti-affinity."""
        import yaml

        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert "affinity" in values
        assert "podAntiAffinity" in values["affinity"]
