"""Complete matrix tests for Spark 4.1."""

import subprocess
from pathlib import Path

import pytest


class TestSpark41CompleteMatrix:
    """Test complete matrix for Spark 4.1."""

    @pytest.mark.parametrize("component", ["jupyter", "airflow"])
    @pytest.mark.parametrize("mode", ["connect-k8s", "connect-standalone", "k8s-submit", "operator"])
    @pytest.mark.parametrize("features", ["none", "gpu", "iceberg", "gpu-iceberg"])
    def test_all_combinations_render(
        self, component: str, mode: str, features: str
    ) -> None:
        """Test that all 4.1 combinations render successfully."""
        chart_dir = "charts/spark-4.1"
        scenario_file = f"{chart_dir}/values-scenario-{component}-{mode}.yaml"
        if not Path(scenario_file).exists():
            pytest.skip(f"Scenario file {scenario_file} does not exist")

        values_files = ["-f", scenario_file]
        if "gpu" in features:
            values_files.extend(["-f", f"{chart_dir}/presets/gpu-values.yaml"])
        if "iceberg" in features:
            values_files.extend(["-f", f"{chart_dir}/presets/iceberg-values.yaml"])

        result = subprocess.run(
            [
                "helm",
                "template",
                f"spark-41-{component}-{mode}-{features}",
                chart_dir,
                "--namespace",
                "test",
            ]
            + values_files,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Failed for {component}/{mode}/{features}: {result.stderr}"

    def test_jupyter_connect_k8s_base_renders(self) -> None:
        """Base Jupyter + Connect + K8s scenario."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-jupyter-connect-k8s",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_jupyter_connect_k8s_with_gpu(self) -> None:
        """Jupyter + Connect + K8s + GPU."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-jupyter-connect-k8s-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml",
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

    def test_jupyter_connect_k8s_with_iceberg(self) -> None:
        """Jupyter + Connect + K8s + Iceberg."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-jupyter-connect-k8s-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml",
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

    def test_jupyter_connect_k8s_with_gpu_and_iceberg(self) -> None:
        """Jupyter + Connect + K8s + GPU + Iceberg."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-jupyter-connect-k8s-gpu-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout
        assert "iceberg" in result.stdout.lower()

    def test_jupyter_connect_standalone_with_gpu(self) -> None:
        """Jupyter + Connect + Standalone + GPU."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-jupyter-connect-sa-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-jupyter-connect-standalone.yaml",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_airflow_connect_k8s_with_gpu(self) -> None:
        """Airflow + Connect + K8s + GPU."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-airflow-connect-k8s-gpu",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml",
                "-f",
                "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_airflow_k8s_submit_with_iceberg(self) -> None:
        """Airflow + K8s Submit + Iceberg."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-airflow-k8s-iceberg",
                "charts/spark-4.1",
                "-f",
                "charts/spark-4.1/values-scenario-airflow-k8s-submit.yaml",
                "-f",
                "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
