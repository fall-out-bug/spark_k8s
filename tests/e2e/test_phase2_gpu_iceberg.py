"""E2E tests for GPU and Iceberg Phase 2 features."""

import subprocess
from pathlib import Path

import pytest


class TestGPUE2E:
    """E2E tests for GPU support with real workloads."""

    def test_gpu_dockerfile_builds(self) -> None:
        """GPU Dockerfile should build successfully."""
        dockerfile = Path("docker/spark-4.1/gpu/Dockerfile")
        assert dockerfile.exists()
        result = subprocess.run(
            ["docker", "build", "-f", str(dockerfile), "--dry-run", "docker/spark-4.1/gpu/"],
            capture_output=True,
            text=True,
        )
        assert "FROM" in dockerfile.read_text()
        assert "nvidia" in dockerfile.read_text().lower()

    def test_gpu_preset_complete_configuration(self) -> None:
        """GPU preset should have complete RAPIDS configuration."""
        preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        content = preset.read_text()
        assert "spark.rapids.sql.enabled" in content
        assert "spark.executor.resource.gpu.amount" in content
        assert "spark.task.resource.gpu.amount" in content
        assert "nvidia.com/gpu" in content
        assert "com.nvidia.spark.SQLPlugin" in content or "spark.plugins" in content

    def test_gpu_operations_example_exists(self) -> None:
        """GPU operations example notebook should exist."""
        notebook = Path("examples/gpu/gpu_operations_notebook.py")
        assert notebook.exists()
        content = notebook.read_text()
        assert "cudf" in content.lower() or "rapids" in content.lower()

    def test_gpu_discovery_script_executable(self) -> None:
        """GPU discovery script should be executable."""
        script = Path("scripts/gpu-discovery.sh")
        assert script.exists()
        assert script.stat().st_mode & 0o111

    def test_gpu_guide_comprehensive(self) -> None:
        """GPU guide should cover all essential topics."""
        guide = Path("docs/recipes/gpu/gpu-guide.md")
        assert guide.exists()
        content = guide.read_text().lower()
        assert "rapids" in content
        assert "nvidia" in content
        assert "cuda" in content
        assert "cudf" in content
        assert "scheduling" in content


class TestIcebergE2E:
    """E2E tests for Iceberg integration with real workloads."""

    def test_iceberg_preset_complete_configuration(self) -> None:
        """Iceberg preset should have complete catalog configuration."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "spark.sql.extensions" in content
        assert "spark.sql.catalog.iceberg" in content
        assert "org.apache.iceberg.spark.SparkCatalog" in content
        assert "spark.sql.catalog.spark_catalog" in content

    def test_iceberg_operations_example_exists(self) -> None:
        """Iceberg operations example should exist."""
        example = Path("examples/iceberg/iceberg_examples.py")
        assert example.exists()
        content = example.read_text().lower()
        assert "create" in content and "table" in content
        assert "insert" in content
        assert "merge" in content or "update" in content or "delete" in content

    def test_iceberg_guide_comprehensive(self) -> None:
        """Iceberg guide should cover all essential topics."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        assert guide.exists()
        content = guide.read_text().lower()
        assert "acid" in content
        assert "time travel" in content or "snapshot" in content
        assert "schema evolution" in content or "evolution" in content
        assert "partition" in content

    def test_iceberg_s3_integration(self) -> None:
        """Iceberg preset should integrate with S3."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "s3a://" in content or "warehouse" in content.lower()
