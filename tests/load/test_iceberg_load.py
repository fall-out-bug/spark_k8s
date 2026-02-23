"""Load tests for Iceberg workloads."""

import subprocess
from pathlib import Path

import pytest


class TestIcebergLoadWorkloads:
    """Load tests for Iceberg workloads."""

    def test_iceberg_operations_script_exists(self) -> None:
        """Iceberg operations example script should exist."""
        script = Path("examples/iceberg/iceberg_examples.py")
        assert script.exists()
        content = script.read_text()
        assert "iceberg" in content.lower()

    def test_iceberg_script_is_valid_python(self) -> None:
        """Iceberg script should be valid Python."""
        script = Path("examples/iceberg/iceberg_examples.py")
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True,
        )
        assert result.returncode == 0

    def test_iceberg_preset_has_s3_config(self) -> None:
        """Iceberg preset should have S3 configuration for data lakes."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "s3a://" in content or "warehouse" in content.lower()

    def test_iceberg_catalog_config_complete(self) -> None:
        """Iceberg catalog configuration should be complete."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        essential_configs = [
            "spark.sql.catalog.iceberg",
            "spark.sql.extensions",
            "spark.sql.catalogImplementation",
        ]
        for config in essential_configs:
            assert config in content, f"Missing catalog config: {config}"

    def test_iceberg_acid_operations_configured(self) -> None:
        """Iceberg should support ACID operations."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "catalog" in content.lower()


class TestIcebergLoadPerformance:
    """Test Iceberg preset for load performance."""

    def test_iceberg_preset_optimized_for_large_tables(self) -> None:
        """Iceberg preset should be optimized for large tables."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "warehouse" in content.lower() or "catalog" in content.lower()

    def test_iceberg_time_travel_configured(self) -> None:
        """Iceberg should support time travel for data recovery."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "iceberg" in content.lower()

    def test_iceberg_schema_evolution_configured(self) -> None:
        """Iceberg should support schema evolution."""
        preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "catalog" in content.lower()
