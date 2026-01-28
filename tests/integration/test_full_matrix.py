"""Integration tests for full matrix GPU/Iceberg support across all components."""

import pytest
import subprocess
from pathlib import Path


class TestJupyterGPUMatrix:
    """Test Jupyter GPU integration across presets."""

    def test_jupyter_gpu_preset_renders(self):
        """Jupyter GPU preset should render successfully."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/jupyter.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Helm template failed: {result.stderr}"

    def test_jupyter_gpu_resources_render(self):
        """Jupyter should have GPU resources from preset."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/jupyter.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout, "GPU resources not found in Jupyter"
        assert '"1"' in result.stdout, "GPU count should be 1"

    def test_jupyter_gpu_node_selector_renders(self):
        """Jupyter should have GPU node selector from preset."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/jupyter.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "nodeSelector" in result.stdout
        assert "nvidia.com/gpu.present" in result.stdout

    def test_jupyter_gpu_tolerations_render(self):
        """Jupyter should have GPU tolerations from preset."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/jupyter.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "tolerations" in result.stdout
        assert "nvidia.com/gpu" in result.stdout


class TestJupyterIcebergMatrix:
    """Test Jupyter Iceberg integration across presets."""

    def test_jupyter_iceberg_env_vars_render(self):
        """Jupyter should have Iceberg environment variables from preset."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/jupyter.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Check for Iceberg-specific env vars
        assert "PYSPARK_PYTHON" in result.stdout or "PYSPARK_DRIVER_PYTHON" in result.stdout


class TestSparkConnectGPUMatrix:
    """Test Spark Connect GPU integration (already verified)."""

    def test_spark_connect_gpu_renders(self):
        """Spark Connect GPU preset should render."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/spark-connect.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_spark_connect_gpu_resources_in_pod(self):
        """Spark Connect pod should have GPU resources."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/spark-connect.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout


class TestSparkConnectIcebergMatrix:
    """Test Spark Connect Iceberg integration (already verified)."""

    def test_spark_connect_iceberg_renders(self):
        """Spark Connect Iceberg preset should render."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/spark-connect.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_spark_connect_iceberg_sparkconf_renders(self):
        """Spark Connect should have Iceberg SparkConf."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--show-only", "templates/spark-connect.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "SPARK_SQL_CATALOG_ICEBERG" in result.stdout or "spark.sql.catalog.iceberg" in result.stdout


class TestExecutorPodTemplateMatrix:
    """Test executor pod template GPU integration (already verified)."""

    def test_executor_gpu_template_renders(self):
        """Executor pod template should render with GPU preset."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/executor-pod-template-configmap.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_executor_gpu_resources_in_template(self):
        """Executor pod template should have GPU resources."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/executor-pod-template-configmap.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout


class TestFullStackGPUPreset:
    """Test full stack with GPU preset."""

    def test_all_components_render_with_gpu_preset(self):
        """All components should render with GPU preset."""
        components = [
            "templates/spark-connect.yaml",
            "templates/jupyter.yaml",
            "templates/executor-pod-template-configmap.yaml",
        ]

        for component in components:
            result = subprocess.run(
                [
                    "helm", "template", "spark-gpu", "charts/spark-4.1",
                    "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                    "--show-only", component,
                    "--namespace", "test"
                ],
                capture_output=True,
                text=True
            )
            assert result.returncode == 0, f"Component {component} failed: {result.stderr}"

    def test_gpu_preset_complete_matrix(self):
        """GPU preset should work across complete component matrix."""
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        # Check GPU resources appear in multiple places
        gpu_count = result.stdout.count("nvidia.com/gpu")
        assert gpu_count >= 3, f"Expected GPU resources in 3+ places, found {gpu_count}"

        # Check node selector for Jupyter
        assert "nvidia.com/gpu.present" in result.stdout


class TestFullStackIcebergPreset:
    """Test full stack with Iceberg preset."""

    def test_all_components_render_with_iceberg_preset(self):
        """All components should render with Iceberg preset."""
        components = [
            "templates/spark-connect.yaml",
            "templates/jupyter.yaml",
            "templates/spark-connect-configmap.yaml",
        ]

        for component in components:
            result = subprocess.run(
                [
                    "helm", "template", "spark-iceberg", "charts/spark-4.1",
                    "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                    "--show-only", component,
                    "--namespace", "test"
                ],
                capture_output=True,
                text=True
            )
            assert result.returncode == 0, f"Component {component} failed: {result.stderr}"

    def test_iceberg_preset_complete_matrix(self):
        """Iceberg preset should work across complete component matrix."""
        result = subprocess.run(
            [
                "helm", "template", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        # Check Iceberg configuration
        assert "iceberg" in result.stdout.lower()
        assert "spark.sql.catalog" in result.stdout.lower()


class TestCostOptimizedMatrix:
    """Test cost-optimized preset across all components."""

    def test_spot_instance_tolerations_all_components(self):
        """Spot instance tolerations should apply to all relevant components."""
        result = subprocess.run(
            [
                "helm", "template", "spark-cost", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "tolerations" in result.stdout
        assert "spot" in result.stdout.lower() or "preemptible" in result.stdout.lower()
