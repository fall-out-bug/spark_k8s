"""Tests for Spark Standalone subchart."""

import subprocess
from pathlib import Path


class TestSparkStandaloneSubchart:
    """Test Spark Standalone subchart templates."""

    def test_subchart_lint(self) -> None:
        """Subchart should pass helm lint."""
        result = subprocess.run(
            ["helm", "lint", "charts/spark-3.5/charts/spark-standalone"],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Lint failed: {result.stderr}"

    def test_subchart_template_renders(self) -> None:
        """Subchart should render without errors."""
        result = subprocess.run(
            ["helm", "template", "test",
             "charts/spark-3.5/charts/spark-standalone", "--namespace", "test"],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Template failed: {result.stderr}"

    def test_subchart_has_master_template(self) -> None:
        """Subchart should have master template."""
        master_template = Path("charts/spark-3.5/charts/spark-standalone/templates/master.yaml")
        assert master_template.exists(), "Master template not found"

    def test_subchart_has_worker_template(self) -> None:
        """Subchart should have worker template."""
        worker_template = Path("charts/spark-3.5/charts/spark-standalone/templates/worker.yaml")
        assert worker_template.exists(), "Worker template not found"

    def test_subchart_has_airflow_templates(self) -> None:
        """Subchart should have Airflow templates."""
        airflow_dir = Path("charts/spark-3.5/charts/spark-standalone/templates/airflow")
        assert airflow_dir.exists(), "Airflow templates directory not found"

        expected_templates = ["webserver.yaml", "scheduler.yaml", "postgresql.yaml", "configmap.yaml"]
        for template in expected_templates:
            template_path = airflow_dir / template
            assert template_path.exists(), f"Template {template} not found"

    def test_subchart_values_exist(self) -> None:
        """Subchart should have values file."""
        values_file = Path("charts/spark-3.5/charts/spark-standalone/values.yaml")
        assert values_file.exists(), "Subchart values.yaml not found"

    def test_symlink_exists(self) -> None:
        """Spark-standalone symlink should exist and be valid."""
        symlink = Path("charts/spark-standalone")
        assert symlink.exists(), "Symlink does not exist or is broken"
        assert symlink.is_symlink(), "Not a symlink"
