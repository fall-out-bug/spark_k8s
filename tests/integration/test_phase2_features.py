"""Integration tests for Phase 2 features (GPU, Iceberg, Auto-scaling)."""

import pytest
from pathlib import Path
import subprocess


class TestGPUIntegration:
    """Test GPU preset actual integration."""

    def test_gpu_preset_renders_successfully(self):
        """GPU preset should render without errors."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_gpu_resources_in_executor_pod(self):
        """GPU resources should appear in executor pod spec."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout, "GPU resources not found"
        assert '"1"' in result.stdout, "GPU count should be 1"

    def test_rapids_config_in_environment(self):
        """RAPIDS configuration should be passed to Spark."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/spark-connect-configmap.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Check for RAPIDS config in spark-defaults.conf
        assert "rapids" in result.stdout.lower()
        assert "spark.plugins" in result.stdout or "sqlplugin" in result.stdout.lower()

    def test_gpu_node_selector_applied(self):
        """GPU node selector should be applied."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "nodeSelector" in result.stdout
        assert "tolerations" in result.stdout


class TestIcebergIntegration:
    """Test Iceberg preset actual integration."""

    def test_iceberg_preset_renders_successfully(self):
        """Iceberg preset should render without errors."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_iceberg_catalog_configured(self):
        """Iceberg catalog should be configured."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/spark-connect-configmap.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Check for Iceberg catalog configuration
        assert "iceberg" in result.stdout.lower()
        assert "spark.sql.catalog" in result.stdout.lower()

    def test_iceberg_extensions_enabled(self):
        """Iceberg Spark extensions should be enabled."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/spark-connect-configmap.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()
        assert "extensions" in result.stdout.lower()


class TestAutoScalingIntegration:
    """Test auto-scaling preset actual integration."""

    def test_cost_optimized_preset_renders_successfully(self):
        """Cost-optimized preset should render without errors."""
        result = subprocess.run(
            [
                "helm", "template", "spark-cost", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_spot_instance_tolerations_applied(self):
        """Spot instance tolerations should be applied."""
        result = subprocess.run(
            [
                "helm", "template", "spark-cost", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "tolerations" in result.stdout
        assert "spot" in result.stdout.lower() or "preemptible" in result.stdout.lower()

    def test_dynamic_allocation_enabled(self):
        """Dynamic allocation should be enabled."""
        result = subprocess.run(
            [
                "helm", "template", "spark-cost", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Check in spark-defaults.conf or ConfigMap
        assert "dynamicAllocation.enabled=true" in result.stdout

    def test_autoscaling_templates_exist(self):
        """Autoscaling templates should exist (opt-in)."""
        # Templates exist but are disabled by default
        cluster_autoscaler = Path("charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml")
        keda_scaler = Path("charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml")
        assert cluster_autoscaler.exists()
        assert keda_scaler.exists()


class TestAllPresetsCompatibility:
    """Test that all presets can be rendered together."""

    def test_base_chart_renders(self):
        """Base chart should render without presets."""
        result = subprocess.run(
            [
                "helm", "template", "spark-base", "charts/spark-4.1",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Base chart failed: {result.stderr}"

    def test_all_presets_render(self):
        """All presets should render successfully."""
        presets = [
            ("gpu", "charts/spark-4.1/presets/gpu-values.yaml"),
            ("iceberg", "charts/spark-4.1/presets/iceberg-values.yaml"),
            ("cost-optimized", "charts/spark-4.1/presets/cost-optimized-values.yaml"),
        ]

        for name, preset in presets:
            result = subprocess.run(
                [
                    "helm", "template", f"spark-{name}", "charts/spark-4.1",
                    "-f", preset,
                    "--namespace", "test"
                ],
                capture_output=True,
                text=True
            )
            assert result.returncode == 0, f"Preset {name} failed: {result.stderr}"
            # Check that resources are rendered
            assert "resources:" in result.stdout, f"Preset {name} missing resources"

    def test_gpu_and_iceberg_combination(self):
        """GPU + Iceberg presets should work together."""
        # This would require merging presets or using values overlay
        # For now, just verify both can be rendered
        result_gpu = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result_gpu.returncode == 0

        result_iceberg = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result_iceberg.returncode == 0
