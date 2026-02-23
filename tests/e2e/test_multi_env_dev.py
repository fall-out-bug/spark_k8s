"""E2E tests for dev environment."""

import subprocess
from pathlib import Path

import pytest


class TestMultiEnvironmentDev:
    """E2E tests for dev environment configuration."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        """Path to Helm chart."""
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path: Path) -> Path:
        """Path to environments directory."""
        return helm_chart_path / "environments"

    def test_dev_values_exists(self, environments_path: Path) -> None:
        """Test that dev values file exists."""
        dev_values = environments_path / "dev" / "values.yaml"
        assert dev_values.exists(), "Dev values file should exist"

    @pytest.mark.skipif(
        subprocess.run(["which", "yamllint"], capture_output=True).returncode != 0,
        reason="yamllint not installed",
    )
    def test_dev_values_valid_yaml(self, environments_path: Path) -> None:
        """Test that dev values is valid YAML."""
        dev_values = environments_path / "dev" / "values.yaml"
        result = subprocess.run(
            ["yamllint", str(dev_values)],
            capture_output=True,
        )
        assert result.returncode == 0, f"Dev values YAML is valid: {result.stdout.decode()}"

    def test_dev_helm_lint(self, helm_chart_path: Path, environments_path: Path) -> None:
        """Test that dev chart passes helm lint."""
        dev_values = environments_path / "dev" / "values.yaml"
        result = subprocess.run(
            ["helm", "lint", str(helm_chart_path), "-f", str(dev_values)],
            capture_output=True,
        )
        assert result.returncode == 0, f"Dev chart should lint: {result.stdout.decode()}"

    def test_dev_helm_template(self, helm_chart_path: Path, environments_path: Path) -> None:
        """Test that dev chart renders successfully."""
        dev_values = environments_path / "dev" / "values.yaml"
        result = subprocess.run(
            [
                "helm",
                "template",
                "test-dev",
                str(helm_chart_path),
                "-f",
                str(dev_values),
            ],
            capture_output=True,
        )
        assert result.returncode == 0, f"Dev chart should render: {result.stderr.decode()}"

    def test_dev_replicas_minimal(self, environments_path: Path) -> None:
        """Test that dev has minimal replicas."""
        import yaml

        dev_values = environments_path / "dev" / "values.yaml"
        with open(dev_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["replicas"] == 1, "Dev should have 1 replica"
        assert values["connect"]["resources"]["requests"]["memory"] == "2Gi"
        assert values["connect"]["dynamicAllocation"]["maxExecutors"] == 5

    def test_dev_debug_enabled(self, environments_path: Path) -> None:
        """Test that debug is enabled in dev."""
        import yaml

        dev_values = environments_path / "dev" / "values.yaml"
        with open(dev_values) as f:
            values = yaml.safe_load(f)

        assert "spark.sql.debug.maxToStringFields" in str(values)
        assert values["connect"]["sparkConf"]["spark.sql.debug.maxToStringFields"] == "100"
