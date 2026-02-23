"""Iceberg preset and example tests."""

from pathlib import Path

import pytest


class TestIcebergPreset:
    """Test Iceberg preset configuration."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_iceberg_preset_exists(self, preset_file: Path) -> None:
        """Iceberg preset should exist."""
        assert preset_file.exists()

    def test_iceberg_preset_valid_yaml(self, preset_file: Path) -> None:
        """Preset should be valid YAML."""
        import yaml
        with open(preset_file) as f:
            yaml.safe_load(f)

    def test_iceberg_preset_has_catalog_config(self, preset_file: Path) -> None:
        """Preset should have Iceberg catalog configuration."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        assert "spark.sql.extensions" in spark_conf
        assert "iceberg" in spark_conf.get("spark.sql.extensions", "").lower()

    def test_iceberg_preset_has_warehouse_config(self, preset_file: Path) -> None:
        """Preset should have warehouse configuration."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        content = str(spark_conf).lower()
        assert "warehouse" in content

    def test_iceberg_preset_has_catalog_type(self, preset_file: Path) -> None:
        """Preset should specify catalog type."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        keys = [k.lower() for k in values["connect"]["sparkConf"]]
        assert any("catalog" in k and "type" in k for k in keys)


class TestIcebergExamples:
    """Test Iceberg example notebook."""

    @pytest.fixture
    def example_file(self) -> Path:
        """Path to Iceberg examples."""
        return Path("examples/iceberg/iceberg_examples.py")

    def test_example_exists(self, example_file: Path) -> None:
        """Iceberg example should exist."""
        assert example_file.exists()

    def test_example_valid_python(self, example_file: Path) -> None:
        """Example should be valid Python."""
        import ast
        ast.parse(example_file.read_text())

    def test_example_imports_pyspark(self, example_file: Path) -> None:
        """Example should import PySpark."""
        content = example_file.read_text()
        assert "from pyspark" in content or "import pyspark" in content

    def test_example_has_iceberg_config(self, example_file: Path) -> None:
        """Example should configure Iceberg."""
        content = example_file.read_text().lower()
        assert "iceberg" in content
        assert "icebergsparksessionextensions" in content or "spark.sql.catalog" in content

    def test_example_has_time_travel(self, example_file: Path) -> None:
        """Example should demonstrate time travel."""
        content = example_file.read_text().lower()
        assert "time travel" in content or "snapshot" in content or "version as of" in content

    def test_example_has_schema_evolution(self, example_file: Path) -> None:
        """Example should demonstrate schema evolution."""
        content = example_file.read_text().lower()
        assert "schema evolution" in content or "alter table" in content

    def test_example_has_rollback(self, example_file: Path) -> None:
        """Example should demonstrate rollback."""
        content = example_file.read_text().lower()
        assert "rollback" in content or "rollback_to_snapshot" in content


class TestIcebergDocumentation:
    """Test Iceberg documentation."""

    def test_iceberg_guide_exists(self) -> None:
        """Iceberg guide should exist."""
        assert Path("docs/recipes/data-management/iceberg-guide.md").exists()

    def test_iceberg_guide_has_required_sections(self) -> None:
        """Guide should have required sections."""
        content = Path("docs/recipes/data-management/iceberg-guide.md").read_text()
        required = [
            "# Apache Iceberg Integration Guide", "## Quick Start",
            "## Time Travel", "## Schema Evolution", "## Rollback Procedures",
            "## Best Practices",
        ]
        for section in required:
            assert section in content

    def test_iceberg_guide_has_catalog_config(self) -> None:
        """Guide should explain catalog configuration."""
        content = Path("docs/recipes/data-management/iceberg-guide.md").read_text()
        assert "catalog" in content.lower() and "spark.sql.catalog" in content

    def test_iceberg_guide_has_examples(self) -> None:
        """Guide should have code examples."""
        content = Path("docs/recipes/data-management/iceberg-guide.md").read_text()
        assert "```" in content
        assert "spark.sql" in content or "INSERT INTO" in content

    def test_iceberg_guide_has_acid_operations(self) -> None:
        """Guide should cover ACID operations."""
        content = Path("docs/recipes/data-management/iceberg-guide.md").read_text()
        assert "ACID" in content or "INSERT" in content or "UPDATE" in content or "DELETE" in content
