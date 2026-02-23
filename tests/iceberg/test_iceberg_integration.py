"""Iceberg catalog types, performance, and integration tests."""

from pathlib import Path

import pytest


class TestIcebergCatalogTypes:
    """Test Iceberg catalog types documentation."""

    def test_guide_mentions_hadoop_catalog(self) -> None:
        """Guide should mention Hadoop catalog."""
        assert "hadoop" in Path("docs/recipes/data-management/iceberg-guide.md").read_text().lower()

    def test_guide_mentions_hive_catalog(self) -> None:
        """Guide should mention Hive catalog."""
        assert "hive" in Path("docs/recipes/data-management/iceberg-guide.md").read_text().lower()

    def test_guide_mentions_rest_catalog(self) -> None:
        """Guide should mention REST catalog."""
        content = Path("docs/recipes/data-management/iceberg-guide.md").read_text().lower()
        assert "rest" in content or "cloud-native" in content


class TestIcebergPerformance:
    """Test Iceberg performance tuning."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_performance_properties_configured(self, preset_file: Path) -> None:
        """Performance properties should be configured."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        keys = [
            k
            for k in values["connect"]["sparkConf"]
            if "vectorization" in k.lower() or "v2" in k.lower() or "delete-planning" in k.lower()
        ]
        assert len(keys) > 0


class TestIcebergIntegration:
    """Test Iceberg integration points."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to Iceberg preset."""
        return Path("charts/spark-4.1/presets/iceberg-values.yaml")

    def test_hive_metastore_enabled(self, preset_file: Path) -> None:
        """Hive Metastore should be enabled for Iceberg."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert values["hiveMetastore"]["enabled"] is True

    def test_jupyter_has_iceberg_env(self, preset_file: Path) -> None:
        """Jupyter should have Iceberg environment variables."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "env" in values["jupyter"]
