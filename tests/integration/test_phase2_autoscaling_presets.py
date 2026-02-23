"""Integration tests for Phase 2 auto-scaling and preset compatibility."""

from pathlib import Path

import subprocess


class TestAutoScalingIntegration:
    """Test auto-scaling preset actual integration."""

    def test_cost_optimized_preset_renders_successfully(self) -> None:
        """Cost-optimized preset should render without errors."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-cost",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_spot_instance_tolerations_applied(self) -> None:
        """Spot instance tolerations should be applied."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-cost",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "tolerations" in result.stdout
        assert "spot" in result.stdout.lower() or "preemptible" in result.stdout.lower()

    def test_dynamic_allocation_enabled(self) -> None:
        """Dynamic allocation should be enabled."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-cost",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "dynamicAllocation.enabled=true" in result.stdout

    def test_autoscaling_templates_exist(self) -> None:
        """Autoscaling templates should exist (opt-in)."""
        cluster_autoscaler = Path("charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml")
        keda_scaler = Path("charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml")
        assert cluster_autoscaler.exists()
        assert keda_scaler.exists()


class TestAllPresetsCompatibility:
    """Test that all presets can be rendered together."""

    def test_base_chart_renders(self) -> None:
        """Base chart should render without presets."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-base",
                "charts/spark-4.1",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Base chart failed: {result.stderr}"

    def test_all_presets_render(self) -> None:
        """All presets should render successfully."""
        presets = [
            ("gpu", "charts/spark-4.1/presets/gpu-values.yaml"),
            ("iceberg", "charts/spark-4.1/presets/iceberg-values.yaml"),
            ("cost-optimized", "charts/spark-4.1/presets/cost-optimized-values.yaml"),
        ]
        for name, preset in presets:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    f"spark-{name}",
                    "charts/spark-4.1",
                    "-f",
                    preset,
                    "--namespace",
                    "test",
                ],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Preset {name} failed: {result.stderr}"
            assert "resources:" in result.stdout, f"Preset {name} missing resources"

    def test_gpu_and_iceberg_combination(self) -> None:
        """GPU + Iceberg presets should work together."""
        result_gpu = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result_gpu.returncode == 0
        result_iceberg = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result_iceberg.returncode == 0
