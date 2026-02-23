"""Tests for Spark 3.5 Full Pipeline Demo with Airflow integration."""

from pathlib import Path
import subprocess

# Common helm command for demo tests
DEMO_VALUES = "charts/spark-3.5/values-demo-full-pipeline.yaml"


def helm_template_demo() -> str:
    """Run helm template for demo and return output."""
    result = subprocess.run(
        ["helm", "template", "full-demo", "charts/spark-3.5",
         "-f", DEMO_VALUES, "--namespace", "demo"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, f"Template failed: {result.stderr}"
    return result.stdout


class TestDemoFullPipeline:
    """Test Full Pipeline Demo scenario for Spark 3.5."""

    def test_demo_full_pipeline_renders(self) -> None:
        """Full pipeline demo should render successfully."""
        helm_template_demo()  # Will raise if fails

    def test_demo_has_spark_master(self) -> None:
        """Full pipeline demo should include Spark Master deployment."""
        output = helm_template_demo()
        assert "kind: Deployment" in output
        assert "spark-master" in output or "standalone-master" in output

    def test_demo_has_spark_workers(self) -> None:
        """Full pipeline demo should include Spark Worker deployment."""
        output = helm_template_demo()
        assert "standalone-worker" in output or "spark-worker" in output

    def test_demo_has_airflow_webserver(self) -> None:
        """Full pipeline demo should include Airflow Webserver."""
        assert "airflow-webserver" in helm_template_demo()

    def test_demo_has_airflow_scheduler(self) -> None:
        """Full pipeline demo should include Airflow Scheduler."""
        assert "airflow-scheduler" in helm_template_demo()

    def test_demo_has_airflow_postgresql(self) -> None:
        """Full pipeline demo should include Airflow PostgreSQL."""
        assert "airflow-postgresql" in helm_template_demo()

    def test_demo_has_jupyter(self) -> None:
        """Full pipeline demo should include Jupyter."""
        assert "jupyter" in helm_template_demo().lower()

    def test_demo_has_spark_connect(self) -> None:
        """Full pipeline demo should include Spark Connect."""
        assert "connect" in helm_template_demo().lower()

    def test_demo_has_history_server(self) -> None:
        """Full pipeline demo should include History Server."""
        assert "history" in helm_template_demo().lower()

    def test_demo_has_minio(self) -> None:
        """Full pipeline demo should include MinIO S3 storage."""
        assert "minio" in helm_template_demo().lower()

    def test_demo_has_monitoring(self) -> None:
        """Full pipeline demo should include monitoring resources."""
        output = helm_template_demo()
        assert "ServiceMonitor" in output or "PodMonitor" in output

    def test_demo_has_airflow_dags(self) -> None:
        """Full pipeline demo should include Airflow DAGs ConfigMap."""
        assert "airflow-dags" in helm_template_demo()

    def test_demo_has_airflow_config(self) -> None:
        """Full pipeline demo should include Airflow config ConfigMap."""
        assert "airflow-config" in helm_template_demo()

    def test_demo_counts_deployments(self) -> None:
        """Full pipeline demo should have expected number of Deployments."""
        output = helm_template_demo()
        deployment_count = output.count("kind: Deployment")
        assert deployment_count >= 8, f"Expected at least 8 Deployments, got {deployment_count}"

    def test_demo_counts_services(self) -> None:
        """Full pipeline demo should have expected number of Services."""
        output = helm_template_demo()
        service_count = output.count("kind: Service")
        assert service_count >= 7, f"Expected at least 7 Services, got {service_count}"

    def test_demo_values_file_exists(self) -> None:
        """Demo values file should exist."""
        assert Path(DEMO_VALUES).exists(), "Demo values file not found"

    def test_demo_readme_exists(self) -> None:
        """Demo README file should exist."""
        readme = Path("charts/spark-3.5/README-demo-full-pipeline.md")
        assert readme.exists(), "Demo README not found"
