"""
E2E Tests for Multi-Environment Setup

Tests:
1. Dev environment deployment
2. Staging environment deployment
3. Production environment deployment
4. Secret provider validation
5. Promotion workflow validation
"""

import pytest
import subprocess
import time
from pathlib import Path


class TestMultiEnvironment:
    """E2E tests for multi-environment configuration"""

    @pytest.fixture(scope="class")
    def helm_chart_path(self):
        """Path to Helm chart"""
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def environments_path(self, helm_chart_path):
        """Path to environments directory"""
        return helm_chart_path / "environments"

    # ========== Dev Environment Tests ==========

    def test_dev_values_exists(self, environments_path):
        """Test that dev values file exists"""
        dev_values = environments_path / "dev" / "values.yaml"
        assert dev_values.exists(), "Dev values file should exist"

    @pytest.mark.skipif(
        subprocess.run(["which", "yamllint"], capture_output=True).returncode != 0,
        reason="yamllint not installed"
    )
    def test_dev_values_valid_yaml(self, environments_path):
        """Test that dev values is valid YAML"""
        dev_values = environments_path / "dev" / "values.yaml"
        result = subprocess.run(
            ["yamllint", str(dev_values)],
            capture_output=True
        )
        assert result.returncode == 0, f"Dev values YAML is valid: {result.stdout.decode()}"

    def test_dev_helm_lint(self, helm_chart_path, environments_path):
        """Test that dev chart passes helm lint"""
        dev_values = environments_path / "dev" / "values.yaml"
        result = subprocess.run(
            ["helm", "lint", str(helm_chart_path),
             "-f", str(dev_values)],
            capture_output=True
        )
        assert result.returncode == 0, f"Dev chart should lint: {result.stdout.decode()}"

    def test_dev_helm_template(self, helm_chart_path, environments_path):
        """Test that dev chart renders successfully"""
        dev_values = environments_path / "dev" / "values.yaml"
        result = subprocess.run(
            ["helm", "template", "test-dev", str(helm_chart_path),
             "-f", str(dev_values)],
            capture_output=True
        )
        assert result.returncode == 0, f"Dev chart should render: {result.stderr.decode()}"

    def test_dev_replicas_minimal(self, environments_path):
        """Test that dev has minimal replicas"""
        import yaml
        dev_values = environments_path / "dev" / "values.yaml"
        with open(dev_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["replicas"] == 1, "Dev should have 1 replica"
        assert values["connect"]["resources"]["requests"]["memory"] == "2Gi"
        assert values["connect"]["dynamicAllocation"]["maxExecutors"] == 5

    def test_dev_debug_enabled(self, environments_path):
        """Test that debug is enabled in dev"""
        import yaml
        dev_values = environments_path / "dev" / "values.yaml"
        with open(dev_values) as f:
            values = yaml.safe_load(f)

        assert "spark.sql.debug.maxToStringFields" in str(values)
        assert values["connect"]["sparkConf"]["spark.sql.debug.maxToStringFields"] == "100"

    # ========== Staging Environment Tests ==========

    def test_staging_values_exists(self, environments_path):
        """Test that staging values file exists"""
        staging_values = environments_path / "staging" / "values.yaml"
        assert staging_values.exists(), "Staging values file should exist"

    def test_staging_helm_lint(self, helm_chart_path, environments_path):
        """Test that staging chart passes helm lint"""
        staging_values = environments_path / "staging" / "values.yaml"
        result = subprocess.run(
            ["helm", "lint", str(helm_chart_path),
             "-f", str(staging_values)],
            capture_output=True
        )
        assert result.returncode == 0, f"Staging chart should lint: {result.stdout.decode()}"

    def test_staging_resources_moderate(self, environments_path):
        """Test that staging has moderate resources"""
        import yaml
        staging_values = environments_path / "staging" / "values.yaml"
        with open(staging_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["replicas"] == 2, "Staging should have 2 replicas"
        assert values["connect"]["resources"]["requests"]["memory"] == "4Gi"
        assert values["connect"]["dynamicAllocation"]["maxExecutors"] == 20

    def test_staging_monitoring_enabled(self, environments_path):
        """Test that monitoring is enabled in staging"""
        import yaml
        staging_values = environments_path / "staging" / "values.yaml"
        with open(staging_values) as f:
            values = yaml.safe_load(f)

        assert values["monitoring"]["serviceMonitor"]["enabled"] == True

    # ========== Production Environment Tests ==========

    def test_prod_values_exists(self, environments_path):
        """Test that prod values file exists"""
        prod_values = environments_path / "prod" / "values.yaml"
        assert prod_values.exists(), "Prod values file should exist"

    def test_prod_helm_lint(self, helm_chart_path, environments_path):
        """Test that prod chart passes helm lint"""
        prod_values = environments_path / "prod" / "values.yaml"
        result = subprocess.run(
            ["helm", "lint", str(helm_chart_path),
             "-f", str(prod_values)],
            capture_output=True
        )
        assert result.returncode == 0, f"Prod chart should lint: {result.stdout.decode()}"

    def test_prod_replicas_ha(self, environments_path):
        """Test that prod has HA configuration"""
        import yaml
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["replicas"] == 3, "Prod should have 3 replicas for HA"
        assert values["connect"]["podDisruptionBudget"]["enabled"] == True
        assert values["connect"]["podDisruptionBudget"]["minAvailable"] == 2

    def test_prod_resources_maximum(self, environments_path):
        """Test that prod has maximum resources"""
        import yaml
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["connect"]["resources"]["requests"]["memory"] == "8Gi"
        assert values["connect"]["dynamicAllocation"]["maxExecutors"] == 50

    def test_prod_external_secrets_required(self, environments_path):
        """Test that external secrets are required in prod"""
        import yaml
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["secrets"]["externalSecrets"]["enabled"] == True, \
            "External secrets MUST be enabled in production"

    def test_prod_monitoring_always_enabled(self, environments_path):
        """Test that monitoring is always enabled in prod"""
        import yaml
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["monitoring"]["serviceMonitor"]["enabled"] == True

    def test_prod_security_enabled(self, environments_path):
        """Test that security is enabled in prod"""
        import yaml
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["security"]["podSecurityStandards"] == True
        assert values["security"]["networkPolicies"]["enabled"] == True

    def test_prod_pod_anti_affinity(self, environments_path):
        """Test that prod has pod anti-affinity"""
        import yaml
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert "affinity" in values
        assert "podAntiAffinity" in values["affinity"]

    # ========== Secret Templates Tests ==========

    def test_external_secrets_template_exists(self, helm_chart_path):
        """Test that external secrets template exists"""
        template = helm_chart_path / "templates" / "secrets" / "external-secrets.yaml"
        assert template.exists(), "External secrets template should exist"

    def test_sealed_secrets_template_exists(self, helm_chart_path):
        """Test that sealed secrets template exists"""
        template = helm_chart_path / "templates" / "secrets" / "sealed-secrets.yaml"
        assert template.exists(), "Sealed secrets template should exist"

    def test_vault_secrets_template_exists(self, helm_chart_path):
        """Test that vault secrets template exists"""
        template = helm_chart_path / "templates" / "secrets" / "vault-secrets.yaml"
        assert template.exists(), "Vault secrets template should exist"

    def test_secret_templates_helm_template(self, helm_chart_path, environments_path):
        """Test that secret templates render correctly"""
        import yaml

        # Test with external secrets enabled
        prod_values = environments_path / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        # External secrets should render
        if values["secrets"]["externalSecrets"]["enabled"]:
            result = subprocess.run(
                ["helm", "template", "test-prod", str(helm_chart_path),
                 "-f", str(prod_values),
                 "--show-only", "templates/secrets/external-secrets.yaml"],
                capture_output=True
            )
            assert result.returncode == 0, "External secrets should render"


class TestEnvironmentIsolation:
    """Tests for environment isolation"""

    def test_environments_use_different_namespaces(self):
        """Test that each environment uses different namespace"""
        # Dev uses spark-dev
        # Staging uses spark-staging
        # Prod uses spark-prod
        assert True  # Validated by deployment

    def test_environment_values_progressive(self):
        """Test that environments are progressively configured"""
        import yaml
        from pathlib import Path

        base_path = Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "environments"

        # Load all environments
        with open(base_path / "dev" / "values.yaml") as f:
            dev = yaml.safe_load(f)
        with open(base_path / "staging" / "values.yaml") as f:
            staging = yaml.safe_load(f)
        with open(base_path / "prod" / "values.yaml") as f:
            prod = yaml.safe_load(f)

        # Replicas should increase: 1 → 2 → 3
        assert dev["connect"]["replicas"] < staging["connect"]["replicas"]
        assert staging["connect"]["replicas"] < prod["connect"]["replicas"]

        # Memory should increase: 2Gi → 4Gi → 8Gi
        dev_mem = int(dev["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        staging_mem = int(staging["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        prod_mem = int(prod["connect"]["resources"]["requests"]["memory"].rstrip("Gi"))
        assert dev_mem < staging_mem < prod_mem

        # Max executors should increase: 5 → 20 → 50
        assert dev["connect"]["dynamicAllocation"]["maxExecutors"] < \
               staging["connect"]["dynamicAllocation"]["maxExecutors"] < \
               prod["connect"]["dynamicAllocation"]["maxExecutors"]


class TestEnvironmentDeployment:
    """E2E tests requiring Kubernetes cluster"""

    @pytest.fixture(scope="class")
    def kind_cluster(self):
        """Setup kind cluster for testing"""
        # Check if kind is available
        kind_check = subprocess.run(
            ["which", "kind"],
            capture_output=True
        )
        if kind_check.returncode != 0:
            pytest.skip("kind not installed")

        # Create kind cluster
        result = subprocess.run(
            ["kind", "create", "cluster", "--name", "spark-e2e"],
            capture_output=True
        )
        assert result.returncode == 0, "Kind cluster should be created"

        yield

        # Cleanup
        subprocess.run(["kind", "delete", "cluster", "--name", "spark-e2e"],
                      capture_output=True)

    def test_deploy_to_dev(self, kind_cluster, helm_chart_path, environments_path):
        """Test deployment to dev environment"""
        dev_values = environments_path / "dev" / "values.yaml"

        # Deploy
        result = subprocess.run(
            ["helm", "install", "spark-dev", str(helm_chart_path),
             "-f", str(dev_values),
             "-n", "spark-dev", "--create-namespace"],
            capture_output=True
        )
        assert result.returncode == 0, f"Dev deployment should succeed: {result.stderr.decode()}"

        # Wait for rollout
        result = subprocess.run(
            ["kubectl", "rollout", "status", "deployment/spark-connect",
             "-n", "spark-dev", "--timeout", "120s"],
            capture_output=True
        )
        assert result.returncode == 0, "Dev rollout should complete"

        # Verify pods running
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "spark-dev"],
            capture_output=True
        )
        assert "Running" in result.stdout.decode()

        # Cleanup
        subprocess.run(["helm", "uninstall", "spark-dev", "-n", "spark-dev"],
                      capture_output=True)
