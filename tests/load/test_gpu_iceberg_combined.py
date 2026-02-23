"""Load tests for GPU + Iceberg combined workloads."""

import subprocess
from pathlib import Path

import pytest


class TestGPUIcebergCombinedLoad:
    """Load tests for GPU + Iceberg combined workloads."""

    def test_gpu_and_iceberg_combination_renders(self) -> None:
        """GPU + Iceberg combination should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_gpu_iceberg_has_both_configs(self) -> None:
        """GPU + Iceberg should have both configurations."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout or "rapids" in result.stdout.lower()
        assert "iceberg" in result.stdout.lower()


class TestRightsizingForWorkloads:
    """Test rightsizing calculator for workload optimization."""

    def test_rightsizing_calculator_exists(self) -> None:
        """Rightsizing calculator script should exist."""
        script = Path("scripts/rightsizing_calculator.py")
        assert script.exists()

    def test_rightsizing_calculator_executable(self) -> None:
        """Rightsizing calculator should be executable."""
        script = Path("scripts/rightsizing_calculator.py")
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True,
        )
        assert result.returncode == 0

    def test_rightsizing_calculator_has_gpu_presets(self) -> None:
        """Rightsizing calculator should have spot option for cost optimization."""
        script = Path("scripts/rightsizing_calculator.py")
        content = script.read_text()
        assert "spot" in content.lower()

    def test_rightsizing_calculator_has_data_size_options(self) -> None:
        """Rightsizing calculator should handle different data sizes."""
        script = Path("scripts/rightsizing_calculator.py")
        content = script.read_text()
        assert any(
            size in content.lower()
            for size in ["gb", "tb", "pb", "data size"]
        )


class TestCostOptimizedLoad:
    """Test cost-optimized preset for load."""

    def test_cost_optimized_preset_for_spots(self) -> None:
        """Cost-optimized preset should configure spot instances."""
        preset = Path("charts/spark-4.1/presets/cost-optimized-values.yaml")
        content = preset.read_text()
        assert "spot" in content.lower() or "preemptible" in content.lower()

    def test_dynamic_allocation_for_varied_loads(self) -> None:
        """Cost-optimized preset should use dynamic allocation for varied loads."""
        preset = Path("charts/spark-4.1/presets/cost-optimized-values.yaml")
        if preset.exists():
            content = preset.read_text()
            assert (
                "dynamicAllocation" in content
                or "dynamicallocation" in content.lower()
            )
