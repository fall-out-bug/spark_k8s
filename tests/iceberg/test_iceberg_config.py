"""Iceberg configuration and feature tests."""

from pathlib import Path

import pytest


class TestIcebergConfiguration:
    """Test Iceberg configuration in preset."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_extensions_enabled(self, preset_file: Path) -> None:
        """Iceberg extensions should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        ext = values["connect"]["sparkConf"].get("spark.sql.extensions", "")
        assert "IcebergSparkSessionExtensions" in ext

    def test_catalog_configured(self, preset_file: Path) -> None:
        """Iceberg catalog should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        keys = [k for k in values["connect"]["sparkConf"] if "spark.sql.catalog" in k]
        assert any("iceberg" in k.lower() for k in keys)

    def test_warehouse_configured(self, preset_file: Path) -> None:
        """Warehouse location should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        keys = [k for k in values["connect"]["sparkConf"] if "warehouse" in k.lower()]
        assert len(keys) > 0

    def test_s3_configured_for_iceberg(self, preset_file: Path) -> None:
        """S3 should be configured for Iceberg storage."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        keys = [k for k in values["connect"]["sparkConf"] if "fs.s3a" in k]
        assert len(keys) > 0

    def test_vectorization_enabled(self, preset_file: Path) -> None:
        """Vectorization should be enabled for performance."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        val = values["connect"]["sparkConf"].get(
            "spark.sql.iceberg.vectorization.enabled", "false"
        )
        assert val == "true"

    def test_v2_enabled(self, preset_file: Path) -> None:
        """V2 should be enabled for row-level operations."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        val = values["connect"]["sparkConf"].get(
            "spark.sql.iceberg.v2.enabled", "false"
        )
        assert val == "true"


class TestHelmRenderIceberg:
    """Test Helm rendering with Iceberg preset."""

    def test_render_with_iceberg_preset(self) -> None:
        """Should render Iceberg configuration."""
        import subprocess
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/spark-connect.yaml"
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "spark-connect" in result.stdout


class TestIcebergExamplesContent:
    """Test Iceberg examples content."""

    @pytest.fixture
    def example_content(self) -> str:
        """Combined content of Iceberg example modules."""
        base = Path("examples/iceberg")
        return "".join(p.read_text() for p in base.glob("*.py"))

    def test_has_create_table(self, example_content: str) -> None:
        """Example should create Iceberg table."""
        assert "CREATE TABLE" in example_content and "USING iceberg" in example_content

    def test_has_insert_data(self, example_content: str) -> None:
        """Example should insert data."""
        assert "INSERT" in example_content or "append" in example_content or "writeTo" in example_content

    def test_has_snapshot_operations(self, example_content: str) -> None:
        """Example should work with snapshots."""
        assert "snapshot" in example_content.lower()

    def test_has_alter_table(self, example_content: str) -> None:
        """Example should alter table schema."""
        assert "ALTER TABLE" in example_content or "ADD COLUMN" in example_content

    def test_has_operations_list(self, example_content: str) -> None:
        """Example should demonstrate various operations."""
        content = example_content.lower()
        ops = ["create", "insert", "select", "update", "delete", "alter"]
        found = [op for op in ops if op in content]
        assert len(found) >= 4


class TestIcebergFeatures:
    """Test Iceberg feature coverage."""

    @pytest.fixture
    def example_content(self) -> str:
        """Combined content of Iceberg example modules."""
        base = Path("examples/iceberg")
        return "".join(p.read_text() for p in base.glob("*.py"))

    def test_time_travel_covered(self, example_content: str) -> None:
        """Time travel should be covered."""
        assert "VERSION AS OF" in example_content or "TIMESTAMP AS OF" in example_content

    def test_schema_evolution_covered(self, example_content: str) -> None:
        """Schema evolution should be covered."""
        assert "ADD COLUMN" in example_content or "ALTER COLUMN" in example_content

    def test_partition_evolution_covered(self, example_content: str) -> None:
        """Partition evolution should be covered."""
        assert "PARTITION" in example_content

    def test_rollback_covered(self, example_content: str) -> None:
        """Rollback should be covered."""
        assert "rollback" in example_content.lower()

    def test_delete_operations_covered(self, example_content: str) -> None:
        """Delete operations should be covered."""
        assert "DELETE" in example_content
