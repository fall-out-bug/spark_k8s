"""Explicit Spark 3.5 matrix tests and parity verification."""

import subprocess
from pathlib import Path

import pytest


class TestSpark35ExplicitScenarios:
    """Explicit scenario tests for Spark 3.5."""

    def test_spark35_jupyter_connect_standalone_with_gpu(self) -> None:
        """Jupyter + Connect + Standalone + GPU for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-standalone.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-jupyter-connect-sa-gpu",
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

    def test_spark35_airflow_connect_k8s_with_gpu(self) -> None:
        """Airflow + Connect + K8s + GPU for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-connect.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-airflow-connect-gpu",
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

    def test_spark35_airflow_k8s_submit_with_iceberg(self) -> None:
        """Airflow + K8s Submit + Iceberg for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-k8s-submit.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-airflow-k8s-iceberg",
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

    def test_spark35_airflow_operator_with_gpu_and_iceberg(self) -> None:
        """Airflow + Operator + GPU + Iceberg for Spark 3.5."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-operator.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-airflow-operator-gpu-iceberg",
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


class TestSpark35Vs41Parity:
    """Test parity between Spark 3.5 and 4.1."""

    def test_both_versions_have_same_presets(self) -> None:
        """Both versions should have the same preset types."""
        presets_41 = set(p.name for p in Path("charts/spark-4.1/presets").glob("*-values.yaml"))
        presets_35 = set(p.name for p in Path("charts/spark-3.5/presets").glob("*-values.yaml"))
        assert "gpu-values.yaml" in presets_41
        assert "gpu-values.yaml" in presets_35
        assert "iceberg-values.yaml" in presets_41
        assert "iceberg-values.yaml" in presets_35

    def test_both_versions_render_with_gpu(self) -> None:
        """Both versions should render successfully with GPU."""
        for version in ["3.5", "4.1"]:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    f"spark-{version}-gpu",
                    f"charts/spark-{version}",
                    "-f",
                    f"charts/spark-{version}/presets/gpu-values.yaml",
                    "--namespace",
                    "test",
                ],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Spark {version} GPU preset failed"

    def test_both_versions_render_with_iceberg(self) -> None:
        """Both versions should render successfully with Iceberg."""
        for version in ["3.5", "4.1"]:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    f"spark-{version}-iceberg",
                    f"charts/spark-{version}",
                    "-f",
                    f"charts/spark-{version}/presets/iceberg-values.yaml",
                    "--namespace",
                    "test",
                ],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Spark {version} Iceberg preset failed"
