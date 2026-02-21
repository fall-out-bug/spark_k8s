"""Complete matrix tests for Airflow scenarios and Spark 3.5."""

import pytest
import subprocess
from pathlib import Path


class TestAirflowScenarios:
    """Test Airflow scenarios with GPU/Iceberg support."""

    def test_airflow_gpu_scenario_renders(self):
        """Airflow + GPU scenario should render successfully."""
        result = subprocess.run(
            [
                "helm", "template", "spark-airflow-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Airflow GPU scenario failed: {result.stderr}"

    def test_airflow_gpu_has_rapids_config(self):
        """Airflow + GPU should have RAPIDS configuration."""
        result = subprocess.run(
            [
                "helm", "template", "spark-airflow-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "com.nvidia.spark.SQLPlugin" in result.stdout
        assert "spark.rapids.sql.enabled" in result.stdout

    def test_airflow_iceberg_scenario_renders(self):
        """Airflow + Iceberg scenario should render successfully."""
        result = subprocess.run(
            [
                "helm", "template", "spark-airflow-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/values-scenario-airflow-iceberg-connect-k8s.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Airflow Iceberg scenario failed: {result.stderr}"

    def test_airflow_iceberg_has_catalog_config(self):
        """Airflow + Iceberg should have catalog configuration."""
        result = subprocess.run(
            [
                "helm", "template", "spark-airflow-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/values-scenario-airflow-iceberg-connect-k8s.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "org.apache.iceberg.spark.SparkCatalog" in result.stdout
        assert "spark.sql.catalog.iceberg" in result.stdout


class TestSpark35Presets:
    """Test Spark 3.5 presets."""

    def test_spark35_gpu_preset_exists(self):
        """Spark 3.5 GPU preset should exist."""
        preset = Path("charts/spark-3.5/presets/gpu-values.yaml")
        assert preset.exists(), "Spark 3.5 GPU preset not found"

    def test_spark35_iceberg_preset_exists(self):
        """Spark 3.5 Iceberg preset should exist."""
        preset = Path("charts/spark-3.5/presets/iceberg-values.yaml")
        assert preset.exists(), "Spark 3.5 Iceberg preset not found"

    def test_spark35_gpu_preset_renders(self):
        """Spark 3.5 GPU preset should render successfully."""
        result = subprocess.run(
            [
                "helm", "template", "spark-35-gpu", "charts/spark-3.5",
                "-f", "charts/spark-3.5/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Spark 3.5 GPU preset failed: {result.stderr}"

    def test_spark35_gpu_has_rapids_config(self):
        """Spark 3.5 GPU should have RAPIDS configuration."""
        preset = Path("charts/spark-3.5/presets/gpu-values.yaml")
        content = preset.read_text()
        assert "com.nvidia.spark.SQLPlugin" in content
        assert "spark.rapids.sql.enabled" in content

    def test_spark35_iceberg_preset_renders(self):
        """Spark 3.5 Iceberg preset should render successfully."""
        result = subprocess.run(
            [
                "helm", "template", "spark-35-iceberg", "charts/spark-3.5",
                "-f", "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Spark 3.5 Iceberg preset failed: {result.stderr}"

    def test_spark35_iceberg_has_catalog_config(self):
        """Spark 3.5 Iceberg should have catalog configuration."""
        preset = Path("charts/spark-3.5/presets/iceberg-values.yaml")
        content = preset.read_text()
        assert "org.apache.iceberg.spark.SparkCatalog" in content
        assert "spark.sql.catalog.iceberg" in content


class TestAllScenariosExist:
    """Test that all required scenarios exist."""

    def test_airflow_scenarios_exist(self):
        """All Airflow scenarios should exist."""
        scenarios = Path("charts/spark-4.1")
        required_scenarios = [
            "values-scenario-airflow-connect-k8s.yaml",
            "values-scenario-airflow-connect-standalone.yaml",
            "values-scenario-airflow-k8s-submit.yaml",
            "values-scenario-airflow-operator.yaml",
            "values-scenario-airflow-gpu-connect-k8s.yaml",  # NEW
            "values-scenario-airflow-iceberg-connect-k8s.yaml",  # NEW
        ]
        for scenario in required_scenarios:
            assert (scenarios / scenario).exists(), f"Scenario {scenario} not found"

    def test_jupyter_scenarios_exist(self):
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

    def test_complete_matrix_coverage(self):
        """Verify complete matrix is covered."""
        components = [
            # Spark 4.1
            "charts/spark-4.1/templates/spark-connect.yaml",
            "charts/spark-4.1/templates/jupyter.yaml",
            "charts/spark-4.1/templates/executor-pod-template-configmap.yaml",
            # Spark 3.5
            "charts/spark-3.5/templates/spark-connect.yaml",
            "charts/spark-3.5/templates/spark-standalone.yaml",
        ]

        for component in components:
            path = Path(component)
            assert path.exists(), f"Component {component} not found"

    def test_all_presets_exist(self):
        """All required presets should exist."""
        presets = [
            # Spark 4.1
            "charts/spark-4.1/presets/gpu-values.yaml",
            "charts/spark-4.1/presets/iceberg-values.yaml",
            "charts/spark-4.1/presets/cost-optimized-values.yaml",
            # Spark 3.5
            "charts/spark-3.5/presets/gpu-values.yaml",
            "charts/spark-3.5/presets/iceberg-values.yaml",
        ]

        for preset in presets:
            path = Path(preset)
            assert path.exists(), f"Preset {preset} not found"

    def test_all_scenarios_exist(self):
        """All required scenarios should exist."""
        scenarios = [
            # Airflow scenarios
            "charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml",
            "charts/spark-4.1/values-scenario-airflow-connect-standalone.yaml",
            "charts/spark-4.1/values-scenario-airflow-k8s-submit.yaml",
            "charts/spark-4.1/values-scenario-airflow-operator.yaml",
            "charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml",  # NEW
            "charts/spark-4.1/values-scenario-airflow-iceberg-connect-k8s.yaml",  # NEW
            # Jupyter scenarios
            "charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml",
            "charts/spark-4.1/values-scenario-jupyter-connect-standalone.yaml",
        ]

        for scenario in scenarios:
            path = Path(scenario)
            assert path.exists(), f"Scenario {scenario} not found"
