"""Load tests for multi-environment template performance."""

import subprocess
import threading
import time
from pathlib import Path

import pytest


class TestLoadPerformance:
    """Load tests for multi-environment configuration."""

    @pytest.fixture(scope="class")
    def helm_chart_path(self) -> Path:
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path: Path) -> Path:
        return helm_chart_path / "environments"

    def test_helm_template_performance_dev(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test that dev template renders quickly (< 2s)."""
        dev_values = environments_path / "dev" / "values.yaml"
        start = time.time()
        result = subprocess.run(
            ["helm", "template", "test-dev", str(helm_chart_path), "-f", str(dev_values)],
            capture_output=True,
        )
        duration = time.time() - start
        assert result.returncode == 0, f"Dev template should render: {result.stderr.decode()}"
        assert duration < 2.0, f"Template rendering should be fast, took {duration:.2f}s"

    def test_helm_template_performance_staging(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test that staging template renders quickly (< 2s)."""
        staging_values = environments_path / "staging" / "values.yaml"
        start = time.time()
        result = subprocess.run(
            [
                "helm",
                "template",
                "test-staging",
                str(helm_chart_path),
                "-f",
                str(staging_values),
            ],
            capture_output=True,
        )
        duration = time.time() - start
        assert result.returncode == 0
        assert duration < 2.0, f"Template rendering should be fast, took {duration:.2f}s"

    def test_helm_template_performance_prod(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test that prod template renders quickly (< 2s)."""
        prod_values = environments_path / "prod" / "values.yaml"
        start = time.time()
        result = subprocess.run(
            [
                "helm",
                "template",
                "test-prod",
                str(helm_chart_path),
                "-f",
                str(prod_values),
            ],
            capture_output=True,
        )
        duration = time.time() - start
        assert result.returncode == 0
        assert duration < 2.0, f"Template rendering should be fast, took {duration:.2f}s"

    def test_sequential_environment_validation(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test validating all environments sequentially."""
        environments = ["dev", "staging", "prod"]
        results = []
        start = time.time()
        for env in environments:
            env_values = environments_path / env / "values.yaml"
            result = subprocess.run(
                ["helm", "lint", str(helm_chart_path), "-f", str(env_values)],
                capture_output=True,
            )
            results.append((env, result.returncode == 0))
        duration = time.time() - start
        assert all(r[1] for r in results), "All environments should validate"
        assert duration < 10.0, f"Sequential validation should be fast, took {duration:.2f}s"

    def test_concurrent_environment_validation(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test validating environments concurrently."""
        environments = ["dev", "staging", "prod"]
        results: dict[str, bool] = {}
        errors: dict[str, str] = {}

        def validate_env(env: str) -> None:
            env_values = environments_path / env / "values.yaml"
            result = subprocess.run(
                ["helm", "lint", str(helm_chart_path), "-f", str(env_values)],
                capture_output=True,
            )
            results[env] = result.returncode == 0
            if not results[env]:
                errors[env] = result.stderr.decode()

        start = time.time()
        threads = []
        for env in environments:
            thread = threading.Thread(target=validate_env, args=(env,))
            threads.append(thread)
            thread.start()
        for thread in threads:
            thread.join()
        duration = time.time() - start
        assert all(results.values()), f"All environments should validate: {errors}"
        assert duration < 5.0, f"Concurrent validation took {duration:.2f}s"

    def test_all_environment_templates_together(
        self, helm_chart_path: Path, environments_path: Path
    ) -> None:
        """Test rendering all templates together (simulate full deployment)."""
        start = time.time()
        for env in ["dev", "staging", "prod"]:
            env_values = environments_path / env / "values.yaml"
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    f"test-{env}",
                    str(helm_chart_path),
                    "-f",
                    str(env_values),
                ],
                capture_output=True,
            )
            assert result.returncode == 0, f"{env.capitalize()} template should render"
        duration = time.time() - start
        assert duration < 6.0, f"All template rendering should be fast, took {duration:.2f}s"

    def test_large_values_file_parsing(self, environments_path: Path) -> None:
        """Test that large values files parse quickly."""
        import yaml

        files_to_test = [
            environments_path / "dev" / "values.yaml",
            environments_path / "staging" / "values.yaml",
            environments_path / "prod" / "values.yaml",
        ]
        start = time.time()
        for file_path in files_to_test:
            with open(file_path) as f:
                yaml.safe_load(f)
        duration = time.time() - start
        assert duration < 0.5, f"YAML parsing should be fast, took {duration:.3f}s"
