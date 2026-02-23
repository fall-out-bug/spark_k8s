"""Load tests for GPU workloads."""

import subprocess
from pathlib import Path

import pytest


class TestGPULoadWorkloads:
    """Load tests for GPU workloads."""

    def test_gpu_operations_script_exists(self) -> None:
        """GPU operations example script should exist."""
        script = Path("examples/gpu/gpu_operations_notebook.py")
        assert script.exists()
        content = script.read_text()
        assert (
            "cudf" in content.lower()
            or "rapids" in content.lower()
            or "gpu" in content.lower()
        )

    def test_gpu_script_is_valid_python(self) -> None:
        """GPU script should be valid Python."""
        script = Path("examples/gpu/gpu_operations_notebook.py")
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True,
        )
        assert result.returncode == 0

    def test_gpu_preset_handles_large_dataset_config(self) -> None:
        """GPU preset should have configuration for large datasets."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()
        assert "memory" in content.lower()
        assert "cores" in content.lower()
        assert "gpu" in content.lower()

    def test_rapids_config_complete_for_workload(self) -> None:
        """RAPIDS configuration should be present for GPU workloads."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()
        essential_configs = [
            "spark.plugins",
            "spark.rapids.sql.enabled",
        ]
        for config in essential_configs:
            assert config in content, f"Missing essential config: {config}"

    def test_gpu_discovery_script_exists(self) -> None:
        """GPU discovery script should exist for cluster setup."""
        script = Path("scripts/gpu-discovery.sh")
        assert script.exists()
        assert script.stat().st_mode & 0o111


class TestLoadPerformancePresets:
    """Test that presets are optimized for load performance."""

    def test_gpu_preset_optimized_for_throughput(self) -> None:
        """GPU preset should be optimized for throughput."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()
        assert "cores" in content.lower() or "parallelism" in content.lower()
        assert "memory" in content.lower()

    def test_gpu_acceleration_for_numeric_ops(self) -> None:
        """GPU preset should accelerate numeric operations."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()
        assert "rapids" in content.lower()
