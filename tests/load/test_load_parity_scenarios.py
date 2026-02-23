"""Load parity and real-world workload scenario tests."""

import subprocess
from pathlib import Path

import pytest


class TestSpark35Vs41LoadParity:
    """Test load parity between Spark 3.5 and 4.1."""

    def test_both_versions_have_load_presets(self) -> None:
        """Both versions should have presets suitable for load workloads."""
        for version in ["3.5", "4.1"]:
            preset_dir = Path(f"charts/spark-{version}/presets")
            if preset_dir.exists():
                presets = list(preset_dir.glob("*-values.yaml"))
                assert len(presets) > 0, f"Spark {version} has no presets"

    def test_both_versions_support_gpu_loads(self) -> None:
        """Both versions should support GPU for accelerated loads."""
        for version in ["3.5", "4.1"]:
            preset = Path(f"charts/spark-{version}/presets/gpu-values.yaml")
            if preset.exists():
                content = preset.read_text()
                assert "gpu" in content.lower() or "rapids" in content.lower()

    def test_both_versions_support_iceberg_loads(self) -> None:
        """Both versions should support Iceberg for data lake loads."""
        for version in ["3.5", "4.1"]:
            preset = Path(f"charts/spark-{version}/presets/iceberg-values.yaml")
            if preset.exists():
                content = preset.read_text()
                assert "iceberg" in content.lower()


class TestRealWorldWorkloadScenarios:
    """Test real-world workload scenarios."""

    def test_etl_workload_scenario(self) -> None:
        """ETL workload: Read from S3, Transform with GPU/Iceberg, Write back."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-etl",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "s3a://" in result.stdout or "warehouse" in result.stdout.lower()

    def test_ml_workload_scenario(self) -> None:
        """ML workload: GPU acceleration for training."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-ml",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout or "rapids" in result.stdout.lower()

    def test_analytics_workload_scenario(self) -> None:
        """Analytics workload: Iceberg for ACID queries."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-analytics",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()
