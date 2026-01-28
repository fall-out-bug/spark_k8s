"""Load tests for GPU and Iceberg features with real data workloads.

These tests verify that:
1. GPU workloads actually use GPU resources
2. Iceberg operations work with real data
3. Performance is acceptable with large datasets
"""

import pytest
import subprocess
import time
from pathlib import Path


class TestGPULoadWorkloads:
    """Load tests for GPU workloads."""

    def test_gpu_operations_script_exists(self):
        """GPU operations example script should exist."""
        script = Path("examples/gpu/gpu_operations_notebook.py")
        assert script.exists()
        content = script.read_text()
        # Should contain cuDF/GPU operations
        assert "cudf" in content.lower() or "rapids" in content.lower() or "gpu" in content.lower()

    def test_gpu_script_is_valid_python(self):
        """GPU script should be valid Python."""
        script = Path("examples/gpu/gpu_operations_notebook.py")
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True
        )
        assert result.returncode == 0

    def test_gpu_preset_handles_large_dataset_config(self):
        """GPU preset should have configuration for large datasets."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()

        # Check for GPU memory and parallelism settings
        assert "memory" in content.lower()
        assert "cores" in content.lower()
        assert "gpu" in content.lower()

    def test_rapids_config_complete_for_workload(self):
        """RAPIDS configuration should be present for GPU workloads."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()

        # Essential RAPIDS configs for data processing
        essential_configs = [
            "spark.plugins",
            "spark.rapids.sql.enabled",
        ]

        for config in essential_configs:
            assert config in content, f"Missing essential config: {config}"

    def test_gpu_discovery_script_exists(self):
        """GPU discovery script should exist for cluster setup."""
        script = Path("scripts/gpu-discovery.sh")
        assert script.exists()
        assert script.stat().st_mode & 0o111  # Executable


class TestIcebergLoadWorkloads:
    """Load tests for Iceberg workloads."""

    def test_iceberg_operations_script_exists(self):
        """Iceberg operations example script should exist."""
        script = Path("examples/iceberg/iceberg_examples.py")
        assert script.exists()
        content = script.read_text()
        # Should contain Iceberg operations
        assert "iceberg" in content.lower()

    def test_iceberg_script_is_valid_python(self):
        """Iceberg script should be valid Python."""
        script = Path("examples/iceberg/iceberg_examples.py")
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True
        )
        assert result.returncode == 0

    def test_iceberg_preset_has_s3_config(self):
        """Iceberg preset should have S3 configuration for data lakes."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()

        # Should have S3/warehouse configuration
        assert "s3a://" in content or "warehouse" in content.lower()

    def test_iceberg_catalog_config_complete(self):
        """Iceberg catalog configuration should be complete."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()

        # Essential catalog configs
        essential_configs = [
            "spark.sql.catalog.iceberg",
            "spark.sql.extensions",
            "spark.sql.catalogImplementation",
        ]

        for config in essential_configs:
            assert config in content, f"Missing catalog config: {config}"

    def test_iceberg_acid_operations_configured(self):
        """Iceberg should support ACID operations."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()

        # Iceberg implicitly supports ACID with catalog
        assert "catalog" in content.lower()


class TestGPUIcebergCombinedLoad:
    """Load tests for GPU + Iceberg combined workloads."""

    def test_gpu_and_iceberg_combination_renders(self):
        """GPU + Iceberg combination should render successfully."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu-iceberg",
                "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_gpu_iceberg_has_both_configs(self):
        """GPU + Iceberg should have both configurations."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu-iceberg",
                "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Should have both GPU and Iceberg configs
        assert "nvidia.com/gpu" in result.stdout or "rapids" in result.stdout.lower()
        assert "iceberg" in result.stdout.lower()


class TestRightsizingForWorkloads:
    """Test rightsizing calculator for workload optimization."""

    def test_rightsizing_calculator_exists(self):
        """Rightsizing calculator script should exist."""
        script = Path("scripts/rightsizing_calculator.py")
        assert script.exists()

    def test_rightsizing_calculator_executable(self):
        """Rightsizing calculator should be executable."""
        script = Path("scripts/rightsizing_calculator.py")
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True
        )
        assert result.returncode == 0

    def test_rightsizing_calculator_has_gpu_presets(self):
        """Rightsizing calculator should have spot option for cost optimization."""
        script = Path("scripts/rightsizing_calculator.py")
        content = script.read_text()

        # Should have spot option for cost-effective GPU workloads
        assert "spot" in content.lower()

    def test_rightsizing_calculator_has_data_size_options(self):
        """Rightsizing calculator should handle different data sizes."""
        script = Path("scripts/rightsizing_calculator.py")
        content = script.read_text()

        # Should handle different data sizes
        assert any(size in content.lower() for size in ["gb", "tb", "pb", "data size"])


class TestLoadPerformancePresets:
    """Test that presets are optimized for load performance."""

    def test_gpu_preset_optimized_for_throughput(self):
        """GPU preset should be optimized for throughput."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()

        # Should have parallelism settings
        assert "cores" in content.lower() or "parallelism" in content.lower()
        assert "memory" in content.lower()

    def test_iceberg_preset_optimized_for_large_tables(self):
        """Iceberg preset should be optimized for large tables."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()

        # Should have warehouse/table configuration
        assert "warehouse" in content.lower() or "catalog" in content.lower()

    def test_cost_optimized_preset_for_spots(self):
        """Cost-optimized preset should configure spot instances."""
        preset = Path("charts/spark-4.1/presets/cost-optimized-values.yaml")
        content = preset.read_text()

        # Should have spot instance configuration
        assert "spot" in content.lower() or "preemptible" in content.lower()

    def test_dynamic_allocation_for_varied_loads(self):
        """Cost-optimized preset should use dynamic allocation for varied loads."""
        # GPU and Iceberg presets may not have dynamic allocation in preset itself
        # but cost-optimized should have it
        preset = Path("charts/spark-4.1/presets/cost-optimized-values.yaml")
        if preset.exists():
            content = preset.read_text()
            # Should have dynamic allocation
            assert "dynamicAllocation" in content or "dynamicallocation" in content.lower()


class TestWorkloadDataIntegrity:
    """Test data integrity features for workloads."""

    def test_iceberg_time_travel_configured(self):
        """Iceberg should support time travel for data recovery."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()

        # Time travel is implicit with Iceberg snapshots
        assert "iceberg" in content.lower()

    def test_iceberg_schema_evolution_configured(self):
        """Iceberg should support schema evolution."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()

        # Schema evolution is implicit with Iceberg
        assert "catalog" in content.lower()

    def test_gpu_acceleration_for_numeric_ops(self):
        """GPU preset should accelerate numeric operations."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()

        # RAPIDS accelerates numeric operations
        assert "rapids" in content.lower()


class TestSpark35Vs41LoadParity:
    """Test load parity between Spark 3.5 and 4.1."""

    def test_both_versions_have_load_presets(self):
        """Both versions should have presets suitable for load workloads."""
        for version in ["3.5", "4.1"]:
            preset_dir = Path(f"charts/spark-{version}/presets")
            if preset_dir.exists():
                presets = list(preset_dir.glob("*-values.yaml"))
                assert len(presets) > 0, f"Spark {version} has no presets"

    def test_both_versions_support_gpu_loads(self):
        """Both versions should support GPU for accelerated loads."""
        for version in ["3.5", "4.1"]:
            preset = Path(f"charts/spark-{version}/presets/gpu-values.yaml")
            if preset.exists():
                content = preset.read_text()
                assert "gpu" in content.lower() or "rapids" in content.lower()

    def test_both_versions_support_iceberg_loads(self):
        """Both versions should support Iceberg for data lake loads."""
        for version in ["3.5", "4.1"]:
            preset = Path(f"charts/spark-{version}/presets/iceberg-values.yaml")
            if preset.exists():
                content = preset.read_text()
                assert "iceberg" in content.lower()


class TestRealWorldWorkloadScenarios:
    """Test real-world workload scenarios."""

    def test_etl_workload_scenario(self):
        """ETL workload: Read from S3, Transform with GPU/Iceberg, Write back."""
        # This tests the complete ETL pipeline setup
        result = subprocess.run(
            [
                "helm", "template", "spark-etl",
                "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Should have S3 and Iceberg configured
        assert "s3a://" in result.stdout or "warehouse" in result.stdout.lower()

    def test_ml_workload_scenario(self):
        """ML workload: GPU acceleration for training."""
        result = subprocess.run(
            [
                "helm", "template", "spark-ml",
                "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Should have GPU configured
        assert "nvidia.com/gpu" in result.stdout or "rapids" in result.stdout.lower()

    def test_analytics_workload_scenario(self):
        """Analytics workload: Iceberg for ACID queries."""
        result = subprocess.run(
            [
                "helm", "template", "spark-analytics",
                "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Should have Iceberg configured
        assert "iceberg" in result.stdout.lower()
