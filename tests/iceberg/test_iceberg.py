"""Tests for Apache Iceberg integration."""

import os
import pytest
from pathlib import Path


class TestIcebergPreset:
    """Test Iceberg preset configuration."""

    @pytest.fixture
    def preset_file(self):
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_iceberg_preset_exists(self, preset_file):
        """Iceberg preset should exist."""
        assert preset_file.exists()

    def test_iceberg_preset_valid_yaml(self, preset_file):
        """Preset should be valid YAML."""
        import yaml
        with open(preset_file) as f:
            yaml.safe_load(f)

    def test_iceberg_preset_has_catalog_config(self, preset_file):
        """Preset should have Iceberg catalog configuration."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        assert "spark.sql.extensions" in spark_conf
        assert "iceberg" in spark_conf.get("spark.sql.extensions", "").lower()

    def test_iceberg_preset_has_warehouse_config(self, preset_file):
        """Preset should have warehouse configuration."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        assert any("warehouse" in k.lower() or "warehouse" in str(v).lower()
                   for k, v in spark_conf.items())

    def test_iceberg_preset_has_catalog_type(self, preset_file):
        """Preset should specify catalog type."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        assert any("catalog" in k.lower() and "type" in k.lower()
                   for k in spark_conf.keys())


class TestIcebergExamples:
    """Test Iceberg example notebook."""

    @pytest.fixture
    def example_file(self):
        """Path to Iceberg examples."""
        return Path("examples/iceberg/iceberg_examples.py")

    def test_example_exists(self, example_file):
        """Iceberg example should exist."""
        assert example_file.exists()

    def test_example_valid_python(self, example_file):
        """Example should be valid Python."""
        import ast
        with open(example_file) as f:
            ast.parse(f.read())

    def test_example_imports_pyspark(self, example_file):
        """Example should import PySpark."""
        content = example_file.read_text()
        assert "from pyspark" in content or "import pyspark" in content

    def test_example_has_iceberg_config(self, example_file):
        """Example should configure Iceberg."""
        content = example_file.read_text()
        assert "iceberg" in content.lower()
        assert "IcebergSparkSessionExtensions" in content or "spark.sql.catalog" in content

    def test_example_has_time_travel(self, example_file):
        """Example should demonstrate time travel."""
        content = example_file.read_text()
        assert "time travel" in content.lower() or "snapshot" in content.lower() or "VERSION AS OF" in content

    def test_example_has_schema_evolution(self, example_file):
        """Example should demonstrate schema evolution."""
        content = example_file.read_text()
        assert "schema evolution" in content.lower() or "ALTER TABLE" in content

    def test_example_has_rollback(self, example_file):
        """Example should demonstrate rollback."""
        content = example_file.read_text()
        assert "rollback" in content.lower() or "rollback_to_snapshot" in content


class TestIcebergDocumentation:
    """Test Iceberg documentation."""

    def test_iceberg_guide_exists(self):
        """Iceberg guide should exist."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        assert guide.exists()

    def test_iceberg_guide_has_required_sections(self):
        """Guide should have required sections."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()

        required_sections = [
            "# Apache Iceberg Integration Guide",
            "## Quick Start",
            "## Time Travel",
            "## Schema Evolution",
            "## Rollback Procedures",
            "## Best Practices",
        ]

        for section in required_sections:
            assert section in content

    def test_iceberg_guide_has_catalog_config(self):
        """Guide should explain catalog configuration."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()
        assert "catalog" in content.lower()
        assert "spark.sql.catalog" in content

    def test_iceberg_guide_has_examples(self):
        """Guide should have code examples."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()
        assert "```" in content
        assert "spark.sql" in content or "INSERT INTO" in content

    def test_iceberg_guide_has_acid_operations(self):
        """Guide should cover ACID operations."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()
        assert "ACID" in content or "INSERT" in content or "UPDATE" in content or "DELETE" in content


class TestIcebergConfiguration:
    """Test Iceberg configuration in preset."""

    @pytest.fixture
    def preset_file(self):
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_extensions_enabled(self, preset_file):
        """Iceberg extensions should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        extensions = spark_conf.get("spark.sql.extensions", "")
        assert "IcebergSparkSessionExtensions" in extensions

    def test_catalog_configured(self, preset_file):
        """Iceberg catalog should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        assert any("spark.sql.catalog" in k and "iceberg" in k.lower()
                   for k in spark_conf.keys())

    def test_warehouse_configured(self, preset_file):
        """Warehouse location should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        warehouse_keys = [k for k in spark_conf.keys() if "warehouse" in k.lower()]
        assert len(warehouse_keys) > 0

    def test_s3_configured_for_iceberg(self, preset_file):
        """S3 should be configured for Iceberg storage."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        assert any("fs.s3a" in k for k in spark_conf.keys())

    def test_vectorization_enabled(self, preset_file):
        """Vectorization should be enabled for performance."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        vectorization = spark_conf.get("spark.sql.iceberg.vectorization.enabled", "false")
        assert vectorization == "true"

    def test_v2_enabled(self, preset_file):
        """V2 should be enabled for row-level operations."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        v2_enabled = spark_conf.get("spark.sql.iceberg.v2.enabled", "false")
        assert v2_enabled == "true"


class TestHelmRenderIceberg:
    """Test Helm rendering with Iceberg preset."""

    def test_render_with_iceberg_preset(self):
        """Should render Iceberg configuration."""
        import subprocess

        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/spark-connect.yaml"
            ],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        assert "spark-connect" in result.stdout


class TestIcebergExamplesContent:
    """Test Iceberg examples content."""

    @pytest.fixture
    def example_file(self):
        """Path to Iceberg examples."""
        return Path("examples/iceberg/iceberg_examples.py")

    def test_has_create_table(self, example_file):
        """Example should create Iceberg table."""
        content = example_file.read_text()
        assert "CREATE TABLE" in content
        assert "USING iceberg" in content

    def test_has_insert_data(self, example_file):
        """Example should insert data."""
        content = example_file.read_text()
        assert "INSERT" in content or "append" in content or "writeTo" in content

    def test_has_snapshot_operations(self, example_file):
        """Example should work with snapshots."""
        content = example_file.read_text()
        assert "snapshot" in content.lower()

    def test_has_alter_table(self, example_file):
        """Example should alter table schema."""
        content = example_file.read_text()
        assert "ALTER TABLE" in content

    def test_has_operations_list(self, example_file):
        """Example should demonstrate various operations."""
        content = example_file.read_text()
        operations = ["create", "insert", "select", "update", "delete", "alter"]
        found = [op for op in operations if op.lower() in content.lower()]
        assert len(found) >= 4  # At least 4 operations


class TestIcebergFeatures:
    """Test Iceberg feature coverage."""

    @pytest.fixture
    def example_file(self):
        """Path to Iceberg examples."""
        return Path("examples/iceberg/iceberg_examples.py")

    def test_time_travel_covered(self, example_file):
        """Time travel should be covered."""
        content = example_file.read_text()
        assert "VERSION AS OF" in content or "TIMESTAMP AS OF" in content

    def test_schema_evolution_covered(self, example_file):
        """Schema evolution should be covered."""
        content = example_file.read_text()
        assert "ADD COLUMN" in content or "ALTER COLUMN" in content

    def test_partition_evolution_covered(self, example_file):
        """Partition evolution should be covered."""
        content = example_file.read_text()
        assert "PARTITION" in content

    def test_rollback_covered(self, example_file):
        """Rollback should be covered."""
        content = example_file.read_text()
        assert "rollback" in content.lower()

    def test_delete_operations_covered(self, example_file):
        """Delete operations should be covered."""
        content = example_file.read_text()
        assert "DELETE" in content


class TestIcebergCatalogTypes:
    """Test Iceberg catalog types documentation."""

    def test_guide_mentions_hadoop_catalog(self):
        """Guide should mention Hadoop catalog."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()
        assert "hadoop" in content.lower()

    def test_guide_mentions_hive_catalog(self):
        """Guide should mention Hive catalog."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()
        assert "hive" in content.lower()

    def test_guide_mentions_rest_catalog(self):
        """Guide should mention REST catalog."""
        guide = Path("docs/recipes/data-management/iceberg-guide.md")
        content = guide.read_text()
        assert "rest" in content.lower() or "cloud-native" in content.lower()


class TestIcebergPerformance:
    """Test Iceberg performance tuning."""

    @pytest.fixture
    def preset_file(self):
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_performance_properties_configured(self, preset_file):
        """Performance properties should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        spark_conf = values["connect"]["sparkConf"]
        performance_keys = [k for k in spark_conf.keys()
                           if "vectorization" in k.lower() or "v2" in k.lower()
                           or "delete-planning" in k.lower()]
        assert len(performance_keys) > 0


class TestIcebergIntegration:
    """Test Iceberg integration points."""

    @pytest.fixture
    def preset_file(self):
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_hive_metastore_enabled(self, preset_file):
        """Hive Metastore should be enabled for Iceberg."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert values["hiveMetastore"]["enabled"] is True

    def test_jupyter_has_iceberg_env(self, preset_file):
        """Jupyter should have Iceberg environment variables."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        jupyter = values["jupyter"]
        assert "env" in jupyter
