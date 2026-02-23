"""Parametrized complete matrix tests for Spark 3.5."""

import subprocess
from pathlib import Path

import pytest


class TestSpark35CompleteMatrix:
    """Test complete matrix for Spark 3.5 - PARITY with Spark 4.1."""

    @pytest.mark.parametrize("component", ["jupyter", "airflow"])
    @pytest.mark.parametrize("mode", ["connect-k8s", "connect-standalone", "k8s-submit", "operator"])
    @pytest.mark.parametrize("features", ["none", "gpu", "iceberg", "gpu-iceberg"])
    def test_all_combinations_render_35(
        self, component: str, mode: str, features: str
    ) -> None:
        """Test that all 3.5 combinations render successfully."""
        chart_dir = "charts/spark-3.5"
        if "connect" in mode:
            scenario_file = f"{chart_dir}/charts/spark-connect/values-scenario-{component}-{mode}.yaml"
        else:
            scenario_file = f"{chart_dir}/charts/spark-standalone/values-scenario-{component}-{mode}.yaml"

        if not Path(scenario_file).exists():
            pytest.skip(f"Scenario file {scenario_file} does not exist for Spark 3.5")

        values_files = ["-f", scenario_file]
        if "gpu" in features:
            values_files.extend(["-f", f"{chart_dir}/presets/gpu-values.yaml"])
        if "iceberg" in features:
            values_files.extend(["-f", f"{chart_dir}/presets/iceberg-values.yaml"])

        result = subprocess.run(
            [
                "helm",
                "template",
                f"spark-35-{component}-{mode}-{features}",
                chart_dir,
                "--namespace",
                "test",
            ]
            + values_files,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Failed for Spark 3.5 {component}/{mode}/{features}: {result.stderr}"

    def test_spark35_jupyter_connect_k8s_base_renders(self) -> None:
        """Base Jupyter + Connect + K8s scenario for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-jupyter-connect-k8s",
                "charts/spark-3.5",
                "-f",
                scenario,
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_spark35_jupyter_connect_k8s_with_gpu(self) -> None:
        """Jupyter + Connect + K8s + GPU for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-jupyter-connect-k8s-gpu",
                "charts/spark-3.5",
                "-f",
                scenario,
                "-f",
                "charts/spark-3.5/presets/gpu-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_spark35_jupyter_connect_k8s_with_iceberg(self) -> None:
        """Jupyter + Connect + K8s + Iceberg for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-jupyter-connect-k8s-iceberg",
                "charts/spark-3.5",
                "-f",
                scenario,
                "-f",
                "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()

    def test_spark35_jupyter_connect_k8s_with_gpu_and_iceberg(self) -> None:
        """Jupyter + Connect + K8s + GPU + Iceberg for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-jupyter-connect-k8s-gpu-iceberg",
                "charts/spark-3.5",
                "-f",
                scenario,
                "-f",
                "charts/spark-3.5/presets/gpu-values.yaml",
                "-f",
                "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()
