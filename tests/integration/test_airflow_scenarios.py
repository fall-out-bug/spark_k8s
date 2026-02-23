"""Complete matrix tests for Airflow scenarios with GPU/Iceberg."""

from pathlib import Path

import subprocess


class TestAirflowScenarios:
    """Test Airflow scenarios with GPU/Iceberg support."""

    def test_airflow_gpu_scenario_renders(self) -> None:
        """Airflow + GPU scenario should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-airflow-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Airflow GPU scenario failed: {result.stderr}"

    def test_airflow_gpu_has_rapids_config(self) -> None:
        """Airflow + GPU should have RAPIDS configuration."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-airflow-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "com.nvidia.spark.SQLPlugin" in result.stdout
        assert "spark.rapids.sql.enabled" in result.stdout

    def test_airflow_iceberg_scenario_renders(self) -> None:
        """Airflow + Iceberg scenario should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-airflow-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-airflow-iceberg-connect-k8s.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Airflow Iceberg scenario failed: {result.stderr}"

    def test_airflow_iceberg_has_catalog_config(self) -> None:
        """Airflow + Iceberg should have catalog configuration."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-airflow-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-airflow-iceberg-connect-k8s.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "org.apache.iceberg.spark.SparkCatalog" in result.stdout
        assert "spark.sql.catalog.iceberg" in result.stdout


class TestSpark35Presets:
    """Test Spark 3.5 presets."""

    def test_spark35_gpu_preset_exists(self) -> None:
        """Spark 3.5 GPU preset should exist."""
        preset = Path("charts/spark-3.5/presets/gpu-values.yaml")
        assert preset.exists(), "Spark 3.5 GPU preset not found"

    def test_spark35_iceberg_preset_exists(self) -> None:
        """Spark 3.5 Iceberg preset should exist."""
        preset = Path("charts/spark-3.5/presets/iceberg-values.yaml")
        assert preset.exists(), "Spark 3.5 Iceberg preset not found"

    def test_spark35_gpu_preset_renders(self) -> None:
        """Spark 3.5 GPU preset should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-gpu",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Spark 3.5 GPU preset failed: {result.stderr}"

    def test_spark35_gpu_has_rapids_config(self) -> None:
        """Spark 3.5 GPU should have RAPIDS configuration."""
        preset = Path("charts/spark-3.5/presets/gpu-values.yaml")
        content = preset.read_text()
        assert "com.nvidia.spark.SQLPlugin" in content
        assert "spark.rapids.sql.enabled" in content

    def test_spark35_iceberg_preset_renders(self) -> None:
        """Spark 3.5 Iceberg preset should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-iceberg",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Spark 3.5 Iceberg preset failed: {result.stderr}"

    def test_spark35_iceberg_has_catalog_config(self) -> None:
        """Spark 3.5 Iceberg should have catalog configuration."""
        preset = Path("charts/spark-3.5/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "org.apache.iceberg.spark.SparkCatalog" in content
        assert "spark.sql.catalog.iceberg" in content
