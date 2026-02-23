"""Tests for autoscaling configuration."""

import os
import pytest
from pathlib import Path


class TestDynamicAllocation:
    """Test Dynamic Allocation settings."""

    @pytest.fixture
    def values_file(self):
        """Path to values file."""
        return Path("charts/spark-4.1/values.yaml")

    @pytest.fixture
    def values_content(self, values_file):
        """Values file content."""
        import yaml
        with open(values_file) as f:
            return yaml.safe_load(f)

    def test_dynamic_allocation_enabled_by_default(self, values_content):
        """Dynamic allocation should be enabled by default."""
        assert values_content["connect"]["dynamicAllocation"]["enabled"] is True

    def test_dynamic_allocation_min_executors_configured(self, values_content):
        """Min executors should be configured."""
        assert "minExecutors" in values_content["connect"]["dynamicAllocation"]
        assert values_content["connect"]["dynamicAllocation"]["minExecutors"] >= 0

    def test_dynamic_allocation_max_executors_configured(self, values_content):
        """Max executors should be configured."""
        assert "maxExecutors" in values_content["connect"]["dynamicAllocation"]
        assert values_content["connect"]["dynamicAllocation"]["maxExecutors"] > 0

    def test_max_executors_greater_than_min(self, values_content):
        """Max executors should be greater than min executors."""
        da = values_content["connect"]["dynamicAllocation"]
        assert da["maxExecutors"] > da["minExecutors"]


class TestClusterAutoscaler:
    """Test Cluster Autoscaler templates."""

    @pytest.fixture
    def template_file(self):
        """Path to cluster autoscaler template."""
        return Path("charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml")

    def test_cluster_autoscaler_template_exists(self, template_file):
        """Cluster Autoscaler template should exist."""
        assert template_file.exists()

    def test_cluster_autoscaler_template_valid_yaml(self, template_file):
        """Cluster Autoscaler template should be valid YAML template."""
        # Helm templates use {{ }} which is not valid YAML directly
        # Just check file is readable and has content
        content = template_file.read_text()
        assert len(content) > 0
        assert "apiVersion" in content

    def test_cluster_autoscaler_has_configmap(self, template_file):
        """Template should create ConfigMap."""
        content = template_file.read_text()
        assert "kind: ConfigMap" in content
        assert "spark-cluster-autoscaler-config" in content

    def test_cluster_autoscaler_has_rbac(self, template_file):
        """Template should create RBAC resources."""
        content = template_file.read_text()
        assert "kind: ClusterRole" in content
        assert "kind: ClusterRoleBinding" in content

    def test_cluster_autoscaler_conditional(self, template_file):
        """Template should be conditional on enabled flag."""
        content = template_file.read_text()
        assert "{{- if .Values.autoscaling.clusterAutoscaler.enabled }}" in content


class TestKEDAScaler:
    """Test KEDA ScaledObject templates."""

    @pytest.fixture
    def template_file(self):
        """Path to KEDA template."""
        return Path("charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml")

    def test_keda_template_exists(self, template_file):
        """KEDA template should exist."""
        assert template_file.exists()

    def test_keda_template_valid_yaml(self, template_file):
        """KEDA template should be valid YAML template."""
        # Helm templates use {{ }} which is not valid YAML directly
        # Just check file is readable and has content
        content = template_file.read_text()
        assert len(content) > 0
        assert "apiVersion" in content

    def test_keda_has_scaledobject(self, template_file):
        """Template should create ScaledObject."""
        content = template_file.read_text()
        assert "kind: ScaledObject" in content
        assert "spark-connect-s3-scaler" in content

    def test_keda_has_s3_trigger(self, template_file):
        """Template should have S3 trigger."""
        content = template_file.read_text()
        assert "type: aws-s3" in content
        assert "s3Bucket" in content

    def test_keda_conditional(self, template_file):
        """Template should be conditional on enabled flag."""
        content = template_file.read_text()
        # Check for the conditional pattern (supports both old and new syntax)
        assert "autoscaling.keda" in content and "enabled" in content


class TestCostOptimizedPreset:
    """Test cost-optimized preset."""

    @pytest.fixture
    def preset_file(self):
        """Path to cost-optimized preset."""
        return Path("charts/spark-4.1/presets/cost-optimized-values.yaml")

    def test_cost_preset_exists(self, preset_file):
        """Cost-optimized preset should exist."""
        assert preset_file.exists()

    def test_cost_preset_valid_yaml(self, preset_file):
        """Preset should be valid YAML."""
        import yaml
        with open(preset_file) as f:
            yaml.safe_load(f)

    def test_cost_preset_has_spot_config(self, preset_file):
        """Preset should have spot instance configuration."""
        content = preset_file.read_text()
        assert "spot" in content.lower() or "preemptible" in content.lower()

    def test_cost_preset_has_node_selector(self, preset_file):
        """Preset should have node selector for spot."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "nodeSelector" in values["connect"]

    def test_cost_preset_has_tolerations(self, preset_file):
        """Preset should have tolerations for spot."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "tolerations" in values["connect"]

    def test_cost_preset_aggressive_dynamic_allocation(self, preset_file):
        """Preset should use aggressive dynamic allocation."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        da = values["connect"]["dynamicAllocation"]
        assert da["enabled"] is True
        assert da["minExecutors"] == 0


class TestRightsizingCalculator:
    """Test rightsizing calculator script."""

    @pytest.fixture
    def calculator_script(self):
        """Path to calculator script."""
        return Path("scripts/rightsizing_calculator.py")

    def test_calculator_exists(self, calculator_script):
        """Calculator script should exist."""
        assert calculator_script.exists()

    def test_calculator_executable(self, calculator_script):
        """Calculator script should be executable."""
        import stat
        st = calculator_script.stat()
        assert st.st_mode & stat.S_IXUSR != 0

    def test_calculator_valid_python(self, calculator_script):
        """Calculator should be valid Python."""
        import ast
        with open(calculator_script) as f:
            ast.parse(f.read())

    def test_calculator_has_main_function(self, calculator_script):
        """Calculator should have main function."""
        content = calculator_script.read_text()
        assert "def main()" in content

    def test_calculator_accepts_data_size(self, calculator_script):
        """Calculator should accept data-size argument."""
        content = calculator_script.read_text()
        assert "--data-size" in content


class TestAutoscalingValues:
    """Test autoscaling values in values.yaml."""

    @pytest.fixture
    def values_file(self):
        """Path to values file."""
        return Path("charts/spark-4.1/values.yaml")

    @pytest.fixture
    def values_content(self, values_file):
        """Values file content."""
        import yaml
        with open(values_file) as f:
            return yaml.safe_load(f)

    def test_autoscaling_section_exists(self, values_content):
        """Autoscaling section should exist."""
        assert "autoscaling" in values_content

    def test_cluster_autoscaler_disabled_by_default(self, values_content):
        """Cluster Autoscaler should be disabled by default."""
        assert values_content["autoscaling"]["clusterAutoscaler"]["enabled"] is False

    def test_keda_disabled_by_default(self, values_content):
        """KEDA should be disabled by default."""
        assert values_content["autoscaling"]["keda"]["enabled"] is False

    def test_cluster_autoscaler_has_scale_down_config(self, values_content):
        """Cluster Autoscaler should have scale-down config."""
        ca = values_content["autoscaling"]["clusterAutoscaler"]
        assert "scaleDown" in ca
        assert "enabled" in ca["scaleDown"]
        assert "unneededTime" in ca["scaleDown"]

    def test_keda_has_s3_config(self, values_content):
        """KEDA should have S3 configuration."""
        keda = values_content["autoscaling"]["keda"]
        assert "s3" in keda
        assert "bucket" in keda["s3"]
        assert "prefix" in keda["s3"]


class TestHelmRender:
    """Test Helm rendering with autoscaling enabled."""

    def test_render_with_cluster_autoscaler(self):
        """Should render Cluster Autoscaler when enabled."""
        import yaml
        import subprocess

        result = subprocess.run(
            [
                "helm", "template", "spark-test", "charts/spark-4.1",
                "--set", "autoscaling.clusterAutoscaler.enabled=true",
                "--show-only", "templates/autoscaling/cluster-autoscaler.yaml"
            ],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        assert "kind: ConfigMap" in result.stdout
        assert "spark-cluster-autoscaler-config" in result.stdout

    def test_render_with_keda(self):
        """Should render KEDA when enabled."""
        import subprocess

        result = subprocess.run(
            [
                "helm", "template", "spark-test", "charts/spark-4.1",
                "--set", "autoscaling.keda.enabled=true",
                "--set", "autoscaling.keda.s3.bucket=test-bucket",
                "--set", "autoscaling.keda.s3.accessKey=test",
                "--set", "autoscaling.keda.s3.secretKey=test",
                "--show-only", "templates/autoscaling/keda-scaledobject.yaml"
            ],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        assert "kind: ScaledObject" in result.stdout

    def test_render_without_autoscaling(self):
        """Should not render autoscaling when disabled."""
        import subprocess

        result = subprocess.run(
            [
                "helm", "template", "spark-test", "charts/spark-4.1",
                "--show-only", "templates/autoscaling/cluster-autoscaler.yaml"
            ],
            capture_output=True,
            text=True
        )

        # Should not contain resources when disabled
        assert "kind: ConfigMap" not in result.stdout


class TestDocumentation:
    """Test auto-scaling documentation."""

    def test_auto_scaling_guide_exists(self):
        """Auto-scaling guide should exist."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        assert guide.exists()

    def test_auto_scaling_guide_has_sections(self):
        """Guide should have required sections."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        content = guide.read_text()

        required_sections = [
            "# Auto-Scaling Guide",
            "## Dynamic Allocation",
            "## Cluster Autoscaler",
            "## KEDA",
            "## Cost-Optimized Preset",
            "## Rightsizing Calculator",
            "## Spot Instance Considerations",
            "## Cost Optimization Best Practices",
        ]

        for section in required_sections:
            assert section in content

    def test_auto_scaling_guide_has_examples(self):
        """Guide should have configuration examples."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        content = guide.read_text()

        assert "```yaml" in content
        assert "dynamicAllocation:" in content
        assert "autoscaling:" in content
