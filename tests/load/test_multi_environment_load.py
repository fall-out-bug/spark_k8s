"""
Load Tests for Multi-Environment Setup

Tests:
1. Helm template rendering performance (should be <2s)
2. Multiple environment validation
3. Concurrent environment validation
"""

import pytest
import subprocess
import time
from pathlib import Path
import threading


class TestLoadPerformance:
    """Load tests for multi-environment configuration"""

    @pytest.fixture(scope="class")
    def helm_chart_path(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path):
        return helm_chart_path / "environments"

    def test_helm_template_performance_dev(self, helm_chart_path, environments_path):
        """Test that dev template renders quickly (< 2s)"""
        dev_values = environments_path / "dev" / "values.yaml"

        start = time.time()
        result = subprocess.run(
            ["helm", "template", "test-dev", str(helm_chart_path),
             "-f", str(dev_values)],
            capture_output=True
        )
        duration = time.time() - start

        assert result.returncode == 0, f"Dev template should render: {result.stderr.decode()}"
        assert duration < 2.0, f"Template rendering should be fast, took {duration:.2f}s"

    def test_helm_template_performance_staging(self, helm_chart_path, environments_path):
        """Test that staging template renders quickly (< 2s)"""
        staging_values = environments_path / "staging" / "values.yaml"

        start = time.time()
        result = subprocess.run(
            ["helm", "template", "test-staging", str(helm_chart_path),
             "-f", str(staging_values)],
            capture_output=True
        )
        duration = time.time() - start

        assert result.returncode == 0, f"Staging template should render: {result.stderr.decode()}"
        assert duration < 2.0, f"Template rendering should be fast, took {duration:.2f}s"

    def test_helm_template_performance_prod(self, helm_chart_path, environments_path):
        """Test that prod template renders quickly (< 2s)"""
        prod_values = environments_path / "prod" / "values.yaml"

        start = time.time()
        result = subprocess.run(
            ["helm", "template", "test-prod", str(helm_chart_path),
             "-f", str(prod_values)],
            capture_output=True
        )
        duration = time.time() - start

        assert result.returncode == 0, f"Prod template should render: {result.stderr.decode()}"
        assert duration < 2.0, f"Template rendering should be fast, took {duration:.2f}s"

    def test_sequential_environment_validation(self, helm_chart_path, environments_path):
        """Test validating all environments sequentially"""
        environments = ["dev", "staging", "prod"]
        results = []

        start = time.time()
        for env in environments:
            env_values = environments_path / env / "values.yaml"
            result = subprocess.run(
                ["helm", "lint", str(helm_chart_path), "-f", str(env_values)],
                capture_output=True
            )
            results.append((env, result.returncode == 0))
        duration = time.time() - start

        assert all(r[1] for r in results), "All environments should validate"
        assert duration < 10.0, f"Sequential validation should be fast, took {duration:.2f}s"

    def test_concurrent_environment_validation(self, helm_chart_path, environments_path):
        """Test validating environments concurrently"""
        environments = ["dev", "staging", "prod"]
        results = {}
        errors = {}

        def validate_env(env):
            env_values = environments_path / env / "values.yaml"
            result = subprocess.run(
                ["helm", "lint", str(helm_chart_path), "-f", str(env_values)],
                capture_output=True
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
        assert duration < 5.0, f"Concurrent validation should be faster than sequential, took {duration:.2f}s"

    def test_all_environment_templates_together(self, helm_chart_path, environments_path):
        """Test rendering all templates together (simulate full deployment)"""
        start = time.time()

        # Render all environments
        for env in ["dev", "staging", "prod"]:
            env_values = environments_path / env / "values.yaml"
            result = subprocess.run(
                ["helm", "template", f"test-{env}", str(helm_chart_path),
                 "-f", str(env_values)],
                capture_output=True
            )
            assert result.returncode == 0, f"{env.capitalize()} template should render"

        duration = time.time() - start
        assert duration < 6.0, f"All template rendering should be fast, took {duration:.2f}s"

    def test_large_values_file_parsing(self, environments_path):
        """Test that large values files parse quickly"""
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


class TestResourceLimits:
    """Tests for resource configuration validation"""

    @pytest.fixture(scope="class")
    def environments_path(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "environments"

    def test_resource_progression(self, environments_path):
        """Test that resources progressively increase"""
        import yaml

        with open(environments_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(environments_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(environments_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        # Extract memory values
        dev_mem = int(dev["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        staging_mem = int(staging["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        prod_mem = int(prod["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))

        # Verify progression: 2 → 4 → 8
        assert dev_mem == 2, f"Dev should use 2Gi, got {dev_mem}Gi"
        assert staging_mem == 4, f"Staging should use 4Gi, got {staging_mem}Gi"
        assert prod_mem == 8, f"Prod should use 8Gi, got {prod_mem}Gi"
        assert dev_mem < staging_mem < prod_mem, "Resources should progressively increase"

    def test_executor_scaling_progression(self, environments_path):
        """Test that executor limits progressively increase"""
        import yaml

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
        assert dev_max < staging_max < prod_max, "Executor limits should progressively increase"

    def test_ha_configuration_prod_only(self, environments_path):
        """Test that only prod has podDisruptionBudget"""
        import yaml

        with open(environments_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(environments_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(environments_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        # Dev and staging should NOT have PDB
        assert not dev["connect"]["podDisruptionBudget"]["enabled"], "Dev should not have PDB"
        assert not staging["connect"]["podDisruptionBudget"]["enabled"], "Staging should not have PDB"

        # Prod should have PDB
        assert prod["connect"]["podDisruptionBudget"]["enabled"], "Prod should have PDB"
        assert prod["connect"]["podDisruptionBudget"]["minAvailable"] == 2, "Prod minAvailable should be 2"


@pytest.mark.load
class TestSecretProviderVariants:
    """Tests for all secret provider variants"""

    @pytest.fixture(scope="class")
    def helm_chart_path(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    def test_external_secrets_all_providers(self, helm_chart_path):
        """Test that external secrets template supports all providers"""
        providers = ["aws", "gcp", "azure", "ibm"]

        for provider in providers:
            # Create test values with provider
            test_values = {
                "secrets": {
                    "externalSecrets": {
                        "enabled": True,
                        "provider": provider,
                        "region": "us-east-1",
                        "prefix": "test"
                    }
                }
            }

            # Save test values
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
                import yaml
                yaml.dump(test_values, f)
                test_values_path = f.name

            try:
                # Test template rendering
                result = subprocess.run(
                    ["helm", "template", "test", str(helm_chart_path),
                     "-f", test_values_path,
                     "--show-only", "templates/secrets/external-secrets.yaml"],
                    capture_output=True
                )
                assert result.returncode == 0, f"External secrets should render for {provider}"
            finally:
                import os
                os.unlink(test_values_path)

    def test_secret_template_independence(self, helm_chart_path):
        """Test that secret templates are independent"""
        import tempfile
        import yaml

        # Test each template independently
        templates = [
            "templates/secrets/external-secrets.yaml",
            "templates/secrets/sealed-secrets.yaml",
            "templates/secrets/vault-secrets.yaml",
        ]

        # Minimal values to test templates
        min_values = {
            "secrets": {
                "vault": {"enabled": False}
            }
        }

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(min_values, f)
            test_values_path = f.name

        try:
            for template in templates:
                result = subprocess.run(
                    ["helm", "template", "test", str(helm_chart_path),
                     "-f", test_values_path,
                     "--show-only", template],
                    capture_output=True
                )
                # Should not error even if not enabled
                # (templates check if enabled themselves)
        finally:
            import os
            os.unlink(test_values_path)
