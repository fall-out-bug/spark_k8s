"""Integration tests for Spark Connect Iceberg matrix."""

import subprocess


class TestSparkConnectIcebergMatrix:
    """Test Spark Connect Iceberg integration."""

    def test_spark_connect_iceberg_renders(self) -> None:
        """Spark Connect Iceberg preset should render."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only",
                "templates/spark-connect.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_spark_connect_iceberg_sparkconf_renders(self) -> None:
        """Spark Connect should have Iceberg SparkConf."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only",
                "templates/spark-connect.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "SPARK_SQL_CATALOG_ICEBERG" in result.stdout or "spark.sql.catalog.iceberg" in result.stdout
