"""Integration tests for Phase 2 GPU and Iceberg features."""

from pathlib import Path

import subprocess


class TestGPUIntegration:
    """Test GPU preset actual integration."""

    def test_gpu_preset_renders_successfully(self) -> None:
        """GPU preset should render without errors."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_gpu_resources_in_executor_pod(self) -> None:
        """GPU resources should appear in executor pod spec."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
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
        assert "nvidia.com/gpu" in result.stdout
        assert '"1"' in result.stdout

    def test_rapids_config_in_environment(self) -> None:
        """RAPIDS configuration should be passed to Spark."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/spark-connect-configmap.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "rapids" in result.stdout.lower()
        assert "spark.plugins" in result.stdout or "sqlplugin" in result.stdout.lower()

    def test_gpu_node_selector_applied(self) -> None:
        """GPU node selector should be applied."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
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
        assert "nodeSelector" in result.stdout
        assert "tolerations" in result.stdout


class TestIcebergIntegration:
    """Test Iceberg preset actual integration."""

    def test_iceberg_preset_renders_successfully(self) -> None:
        """Iceberg preset should render without errors."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_iceberg_catalog_configured(self) -> None:
        """Iceberg catalog should be configured."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only",
                "templates/spark-connect-configmap.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()
        assert "spark.sql.catalog" in result.stdout.lower()

    def test_iceberg_extensions_enabled(self) -> None:
        """Iceberg Spark extensions should be enabled."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only",
                "templates/spark-connect-configmap.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()
        assert "extensions" in result.stdout.lower()
