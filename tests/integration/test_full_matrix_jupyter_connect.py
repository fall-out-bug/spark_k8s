"""Integration tests for Jupyter and Spark Connect GPU/Iceberg matrix."""

import subprocess
from pathlib import Path

import pytest


class TestJupyterGPUMatrix:
    """Test Jupyter GPU integration across presets."""

    def test_jupyter_gpu_preset_renders(self) -> None:
        """Jupyter GPU preset should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/jupyter.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_jupyter_gpu_resources_render(self) -> None:
        """Jupyter should have GPU resources from preset."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/jupyter.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout
        assert '"1"' in result.stdout

    def test_jupyter_gpu_node_selector_renders(self) -> None:
        """Jupyter should have GPU node selector from preset."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/jupyter.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nodeSelector" in result.stdout
        assert "nvidia.com/gpu.present" in result.stdout

    def test_jupyter_gpu_tolerations_render(self) -> None:
        """Jupyter should have GPU tolerations from preset."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/jupyter.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "tolerations" in result.stdout
        assert "nvidia.com/gpu" in result.stdout


class TestJupyterIcebergMatrix:
    """Test Jupyter Iceberg integration across presets."""

    def test_jupyter_iceberg_env_vars_render(self) -> None:
        """Jupyter should have Iceberg environment variables from preset."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only",
                "templates/jupyter.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "PYSPARK_PYTHON" in result.stdout or "PYSPARK_DRIVER_PYTHON" in result.stdout


class TestSparkConnectGPUMatrix:
    """Test Spark Connect GPU integration."""

    def test_spark_connect_gpu_renders(self) -> None:
        """Spark Connect GPU preset should render."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/spark-connect.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_spark_connect_gpu_resources_in_pod(self) -> None:
        """Spark Connect pod should have GPU resources."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/spark-connect.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout
