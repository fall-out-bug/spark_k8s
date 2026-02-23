"""Integration tests for full stack GPU/Iceberg/Cost preset matrix."""

import subprocess
from pathlib import Path

import pytest


class TestExecutorPodTemplateMatrix:
    """Test executor pod template GPU integration."""

    def test_executor_gpu_template_renders(self) -> None:
        """Executor pod template should render with GPU preset."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/executor-pod-template-configmap.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_executor_gpu_resources_in_template(self) -> None:
        """Executor pod template should have GPU resources."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only",
                "templates/executor-pod-template-configmap.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout


class TestFullStackGPUPreset:
    """Test full stack with GPU preset."""

    def test_all_components_render_with_gpu_preset(self) -> None:
        """All components should render with GPU preset."""
        components = [
            "templates/spark-connect.yaml",
            "templates/jupyter.yaml",
            "templates/executor-pod-template-configmap.yaml",
        ]
        for component in components:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    "spark-gpu",
                    "charts/spark-4.1",
                    "-f",
                    "charts/spark-4.1/presets/gpu-values.yaml",
                    "--show-only",
                    component,
                    "--namespace",
                    "test",
                ],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Component {component} failed: {result.stderr}"

    def test_gpu_preset_complete_matrix(self) -> None:
        """GPU preset should work across complete component matrix."""
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
        gpu_count = result.stdout.count("nvidia.com/gpu")
        assert gpu_count >= 3
        assert "nvidia.com/gpu.present" in result.stdout


class TestFullStackIcebergPreset:
    """Test full stack with Iceberg preset."""

    def test_all_components_render_with_iceberg_preset(self) -> None:
        """All components should render with Iceberg preset."""
        components = [
            "templates/spark-connect.yaml",
            "templates/jupyter.yaml",
            "templates/spark-connect-configmap.yaml",
        ]
        for component in components:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    "spark-iceberg",
                    "charts/spark-4.1",
                    "-f",
                    "charts/spark-4.1/presets/iceberg-values.yaml",
                    "--show-only",
                    component,
                    "--namespace",
                    "test",
                ],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Component {component} failed: {result.stderr}"

    def test_iceberg_preset_complete_matrix(self) -> None:
        """Iceberg preset should work across complete component matrix."""
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
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()
        assert "spark.sql.catalog" in result.stdout.lower()


class TestCostOptimizedMatrix:
    """Test cost-optimized preset across all components."""

    def test_spot_instance_tolerations_all_components(self) -> None:
        """Spot instance tolerations should apply to all relevant components."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-cost",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/presets/cost-optimized-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "tolerations" in result.stdout
        assert "spot" in result.stdout.lower() or "preemptible" in result.stdout.lower()
