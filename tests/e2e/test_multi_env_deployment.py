"""E2E tests requiring Kubernetes cluster for deployment."""

import subprocess
from pathlib import Path

import pytest


class TestEnvironmentDeployment:
    """E2E tests requiring Kubernetes cluster."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        """Path to Helm chart."""
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path: Path) -> Path:
        """Path to environments directory."""
        return helm_chart_path / "environments"

    @pytest.fixture(scope="class")
    def kind_cluster(self) -> None:
        """Setup kind cluster for testing."""
        kind_check = subprocess.run(["which", "kind"], capture_output=True)
        if kind_check.returncode != 0:
            pytest.skip("kind not installed")

        result = subprocess.run(
            ["kind", "create", "cluster", "--name", "spark-e2e"],
            capture_output=True,
        )
        assert result.returncode == 0, "Kind cluster should be created"

        yield

        subprocess.run(
            ["kind", "delete", "cluster", "--name", "spark-e2e"],
            capture_output=True,
        )

    def test_deploy_to_dev(
        self,
        kind_cluster: None,
        helm_chart_path: Path,
        environments_path: Path,
    ) -> None:
        """Test deployment to dev environment."""
        dev_values = environments_path / "dev" / "values.yaml"

        result = subprocess.run(
            [
                "helm",
                "install",
                "spark-dev",
                str(helm_chart_path),
                "-f",
                str(dev_values),
                "-n",
                "spark-dev",
                "--create-namespace",
            ],
            capture_output=True,
        )
        assert result.returncode == 0, f"Dev deployment should succeed: {result.stderr.decode()}"

        result = subprocess.run(
            [
                "kubectl",
                "rollout",
                "status",
                "deployment/spark-connect",
                "-n",
                "spark-dev",
                "--timeout",
                "120s",
            ],
            capture_output=True,
        )
        assert result.returncode == 0, "Dev rollout should complete"

        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "spark-dev"],
            capture_output=True,
        )
        assert "Running" in result.stdout.decode()

        subprocess.run(
            ["helm", "uninstall", "spark-dev", "-n", "spark-dev"],
            capture_output=True,
        )
