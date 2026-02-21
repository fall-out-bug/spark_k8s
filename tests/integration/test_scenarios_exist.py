"""Tests that all required scenarios and components exist."""

from pathlib import Path


class TestAllScenariosExist:
    """Test that all required scenarios exist."""

    def test_airflow_scenarios_exist(self) -> None:
        """All Airflow scenarios should exist."""
        scenarios = Path("charts/spark-4.1")
        required_scenarios = [
            "values-scenario-airflow-connect-k8s.yaml",
            "values-scenario-airflow-connect-standalone.yaml",
            "values-scenario-airflow-k8s-submit.yaml",
            "values-scenario-airflow-operator.yaml",
            "values-scenario-airflow-gpu-connect-k8s.yaml",
            "values-scenario-airflow-iceberg-connect-k8s.yaml",
        ]
        for scenario in required_scenarios:
            assert (scenarios / scenario).exists(), f"Scenario {scenario} not found"

    def test_jupyter_scenarios_exist(self) -> None:
        """All Jupyter scenarios should exist."""
        scenarios = Path("charts/spark-4.1")
        required_scenarios = [
            "values-scenario-jupyter-connect-k8s.yaml",
            "values-scenario-jupyter-connect-standalone.yaml",
        ]
        for scenario in required_scenarios:
            assert (scenarios / scenario).exists(), f"Scenario {scenario} not found"


class TestCompleteMatrixSummary:
    """Summary test for complete matrix coverage."""

    def test_complete_matrix_coverage(self) -> None:
        """Verify complete matrix is covered."""
        components = [
            "charts/spark-4.1/templates/spark-connect.yaml",
            "charts/spark-4.1/templates/jupyter.yaml",
            "charts/spark-4.1/templates/executor-pod-template-configmap.yaml",
            "charts/spark-3.5/templates/spark-connect.yaml",
            "charts/spark-3.5/templates/spark-standalone.yaml",
        ]
        for component in components:
            path = Path(component)
            assert path.exists(), f"Component {component} not found"

    def test_all_presets_exist(self) -> None:
        """All required presets should exist."""
        presets = [
            "charts/spark-4.1/presets/gpu-values.yaml",
            "charts/spark-4.1/presets/iceberg-values.yaml",
            "charts/spark-4.1/presets/cost-optimized-values.yaml",
            "charts/spark-3.5/presets/gpu-values.yaml",
            "charts/spark-3.5/presets/iceberg-values.yaml",
        ]
        for preset in presets:
            path = Path(preset)
            assert path.exists(), f"Preset {preset} not found"

    def test_all_scenarios_exist(self) -> None:
        """All required scenarios should exist."""
        scenarios = [
            "charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml",
            "charts/spark-4.1/values-scenario-airflow-connect-standalone.yaml",
            "charts/spark-4.1/values-scenario-airflow-k8s-submit.yaml",
            "charts/spark-4.1/values-scenario-airflow-operator.yaml",
            "charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml",
            "charts/spark-4.1/values-scenario-airflow-iceberg-connect-k8s.yaml",
            "charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml",
            "charts/spark-4.1/values-scenario-jupyter-connect-standalone.yaml",
        ]
        for scenario in scenarios:
            path = Path(scenario)
            assert path.exists(), f"Scenario {scenario} not found"
