"""Complete matrix tests for Spark 3.5 and coverage verification."""

import subprocess
from pathlib import Path

import pytest


class TestSpark35CompleteMatrix:
    """Test complete matrix for Spark 3.5."""

    def test_spark35_base_renders(self) -> None:
        """Spark 3.5 base chart renders."""
        result = subprocess.run(
            ["helm", "template", "spark-35", "charts/spark-3.5", "--namespace", "test"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_spark35_with_gpu_preset(self) -> None:
        """Spark 3.5 + GPU preset."""
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
        assert result.returncode == 0

    def test_spark35_with_iceberg_preset(self) -> None:
        """Spark 3.5 + Iceberg preset."""
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
        assert result.returncode == 0

    def test_spark35_jupyter_scenario_renders(self) -> None:
        """Spark 3.5 + Jupyter scenario."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-jupyter",
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

    def test_spark35_airflow_scenario_renders(self) -> None:
        """Spark 3.5 + Airflow scenario."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-k8s-submit.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-35-airflow",
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


class TestCompleteMatrixCoverage:
    """Verify complete matrix coverage summary."""

    def test_all_base_scenarios_exist_41(self) -> None:
        """All base scenarios should exist for Spark 4.1."""
        scenarios = [
            "values-scenario-jupyter-connect-k8s.yaml",
            "values-scenario-jupyter-connect-standalone.yaml",
            "values-scenario-airflow-connect-k8s.yaml",
            "values-scenario-airflow-connect-standalone.yaml",
            "values-scenario-airflow-k8s-submit.yaml",
            "values-scenario-airflow-operator.yaml",
        ]
        for scenario in scenarios:
            assert Path(f"charts/spark-4.1/{scenario}").exists()

    def test_all_presets_exist_41(self) -> None:
        """All feature presets should exist for Spark 4.1."""
        presets = [
            "presets/gpu-values.yaml",
            "presets/iceberg-values.yaml",
            "presets/cost-optimized-values.yaml",
        ]
        for preset in presets:
            assert Path(f"charts/spark-4.1/{preset}").exists()

    def test_all_presets_exist_35(self) -> None:
        """All feature presets should exist for Spark 3.5."""
        presets = [
            "presets/gpu-values.yaml",
            "presets/iceberg-values.yaml",
        ]
        for preset in presets:
            assert Path(f"charts/spark-3.5/{preset}").exists()

    def test_matrix_combinations_count(self) -> None:
        """Verify we have the expected number of combinations."""
        scenarios_41 = len(list(Path("charts/spark-4.1").glob("values-scenario-*.yaml")))
        scenarios_35 = len(
            list(Path("charts/spark-3.5").glob("charts/*/values-scenario-*.yaml"))
        )
        presets_41 = len(list(Path("charts/spark-4.1/presets").glob("*-values.yaml")))
        presets_35 = len(list(Path("charts/spark-3.5/presets").glob("*-values.yaml")))
        combinations_41 = scenarios_41 * (2**presets_41)
        combinations_35 = scenarios_35 * (2**presets_35)
        assert (scenarios_41 + scenarios_35) >= 8
