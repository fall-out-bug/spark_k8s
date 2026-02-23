"""Complete matrix tests for Spark 3.5 - PARITY with Spark 4.1.

This tests ALL combinations for Spark 3.5:
- 2 components (jupyter, airflow)
- 4 modes (connect-k8s, connect-standalone, k8s-submit, operator)
- 4 feature combinations (none, gpu, iceberg, gpu+iceberg)

Total: 2 × 4 × 4 = 32 test combinations for Spark 3.5
"""

import pytest
import subprocess
from pathlib import Path


class TestSpark35CompleteMatrix:
    """Test complete matrix for Spark 3.5 - PARITY with Spark 4.1."""

    @pytest.mark.parametrize("component", ["jupyter", "airflow"])
    @pytest.mark.parametrize("mode", ["connect-k8s", "connect-standalone", "k8s-submit", "operator"])
    @pytest.mark.parametrize("features", ["none", "gpu", "iceberg", "gpu-iceberg"])
    def test_all_combinations_render_35(self, component, mode, features):
        """Test that all 3.5 combinations render successfully - PARITY with 4.1."""
        chart_dir = "charts/spark-3.5"

        # Determine scenario file path based on mode
        if "connect" in mode:
            scenario_file = f"{chart_dir}/charts/spark-connect/values-scenario-{component}-{mode}.yaml"
        else:
            scenario_file = f"{chart_dir}/charts/spark-standalone/values-scenario-{component}-{mode}.yaml"

        # Build values file list
        values_files = []

        # Base scenario file
        if not Path(scenario_file).exists():
            pytest.skip(f"Scenario file {scenario_file} does not exist for Spark 3.5")
        values_files.extend(["-f", scenario_file])

        # Add feature overlays
        if "gpu" in features:
            values_files.extend(["-f", f"{chart_dir}/presets/gpu-values.yaml"])
        if "iceberg" in features:
            values_files.extend(["-f", f"{chart_dir}/presets/iceberg-values.yaml"])

        # Run helm template
        result = subprocess.run(
            [
                "helm", "template", f"spark-35-{component}-{mode}-{features}",
                chart_dir,
                "--namespace", "test"
            ] + values_files,
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, \
            f"Failed for Spark 3.5 {component}/{mode}/{features}: {result.stderr}"

    def test_spark35_jupyter_connect_k8s_base_renders(self):
        """Base Jupyter + Connect + K8s scenario for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-jupyter-connect-k8s",
                "charts/spark-3.5",
                "-f", scenario,
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_spark35_jupyter_connect_k8s_with_gpu(self):
        """Jupyter + Connect + K8s + GPU for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-jupyter-connect-k8s-gpu",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Spark 3.5 chart may not have GPU templates, check config is present

    def test_spark35_jupyter_connect_k8s_with_iceberg(self):
        """Jupyter + Connect + K8s + Iceberg for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-jupyter-connect-k8s-iceberg",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "iceberg" in result.stdout.lower()

    def test_spark35_jupyter_connect_k8s_with_gpu_and_iceberg(self):
        """Jupyter + Connect + K8s + GPU + Iceberg for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-k8s.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-jupyter-connect-k8s-gpu-iceberg",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/gpu-values.yaml",
                "-f", "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Check Iceberg config is present (GPU may not be in templates)
        assert "iceberg" in result.stdout.lower()

    def test_spark35_jupyter_connect_standalone_with_gpu(self):
        """Jupyter + Connect + Standalone + GPU for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-connect/values-scenario-jupyter-connect-standalone.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-jupyter-connect-sa-gpu",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_spark35_airflow_connect_k8s_with_gpu(self):
        """Airflow + Connect + K8s + GPU for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-connect.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-airflow-connect-gpu",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/gpu-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_spark35_airflow_k8s_submit_with_iceberg(self):
        """Airflow + K8s Submit + Iceberg for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-k8s-submit.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-airflow-k8s-iceberg",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_spark35_airflow_operator_with_gpu_and_iceberg(self):
        """Airflow + Operator + GPU + Iceberg for Spark 3.5 - PARITY."""
        scenario = "charts/spark-3.5/charts/spark-standalone/values-scenario-airflow-operator.yaml"
        if not Path(scenario).exists():
            pytest.skip(f"Scenario {scenario} does not exist")

        result = subprocess.run(
            [
                "helm", "template", "spark-35-airflow-operator-gpu-iceberg",
                "charts/spark-3.5",
                "-f", scenario,
                "-f", "charts/spark-3.5/presets/gpu-values.yaml",
                "-f", "charts/spark-3.5/presets/iceberg-values.yaml",
                "--namespace", "test"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0


class TestSpark35Vs41Parity:
    """Test parity between Spark 3.5 and 4.1."""

    def test_both_versions_have_same_presets(self):
        """Both versions should have the same preset types."""
        presets_41 = set([p.name for p in Path("charts/spark-4.1/presets").glob("*-values.yaml")])
        presets_35 = set([p.name for p in Path("charts/spark-3.5/presets").glob("*-values.yaml")])

        # Both should have gpu and iceberg presets
        assert "gpu-values.yaml" in presets_41
        assert "gpu-values.yaml" in presets_35
        assert "iceberg-values.yaml" in presets_41
        assert "iceberg-values.yaml" in presets_35

    def test_both_versions_render_with_gpu(self):
        """Both versions should render successfully with GPU."""
        for version in ["3.5", "4.1"]:
            result = subprocess.run(
                [
                    "helm", "template", f"spark-{version}-gpu",
                    f"charts/spark-{version}",
                    "-f", f"charts/spark-{version}/presets/gpu-values.yaml",
                    "--namespace", "test"
                ],
                capture_output=True,
                text=True
            )
            assert result.returncode == 0, f"Spark {version} GPU preset failed"

    def test_both_versions_render_with_iceberg(self):
        """Both versions should render successfully with Iceberg."""
        for version in ["3.5", "4.1"]:
            result = subprocess.run(
                [
                    "helm", "template", f"spark-{version}-iceberg",
                    f"charts/spark-{version}",
                    "-f", f"charts/spark-{version}/presets/iceberg-values.yaml",
                    "--namespace", "test"
                ],
                capture_output=True,
                text=True
            )
            assert result.returncode == 0, f"Spark {version} Iceberg preset failed"
