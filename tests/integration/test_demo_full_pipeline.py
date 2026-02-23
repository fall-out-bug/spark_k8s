"""Tests for Spark 3.5 Full Pipeline Demo with Airflow integration."""

from pathlib import Path
import subprocess


class TestDemoFullPipeline:
    """Test Full Pipeline Demo scenario for Spark 3.5."""

    def test_demo_full_pipeline_renders(self) -> None:
        """Full pipeline demo should render successfully."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Full pipeline demo failed: {result.stderr}"

    def test_demo_has_spark_master(self) -> None:
        """Full pipeline demo should include Spark Master deployment."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "kind: Deployment" in result.stdout
        assert "spark-master" in result.stdout or "standalone-master" in result.stdout

    def test_demo_has_spark_workers(self) -> None:
        """Full pipeline demo should include Spark Worker deployment."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "standalone-worker" in result.stdout or "spark-worker" in result.stdout

    def test_demo_has_airflow_webserver(self) -> None:
        """Full pipeline demo should include Airflow Webserver."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "airflow-webserver" in result.stdout

    def test_demo_has_airflow_scheduler(self) -> None:
        """Full pipeline demo should include Airflow Scheduler."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "airflow-scheduler" in result.stdout

    def test_demo_has_airflow_postgresql(self) -> None:
        """Full pipeline demo should include Airflow PostgreSQL."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "airflow-postgresql" in result.stdout

    def test_demo_has_jupyter(self) -> None:
        """Full pipeline demo should include Jupyter."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "jupyter" in result.stdout.lower()

    def test_demo_has_spark_connect(self) -> None:
        """Full pipeline demo should include Spark Connect."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "connect" in result.stdout.lower()

    def test_demo_has_history_server(self) -> None:
        """Full pipeline demo should include History Server."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "history" in result.stdout.lower()

    def test_demo_has_minio(self) -> None:
        """Full pipeline demo should include MinIO S3 storage."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "minio" in result.stdout.lower()

    def test_demo_has_monitoring(self) -> None:
        """Full pipeline demo should include monitoring resources."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "ServiceMonitor" in result.stdout or "PodMonitor" in result.stdout

    def test_demo_has_airflow_dags(self) -> None:
        """Full pipeline demo should include Airflow DAGs ConfigMap."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "airflow-dags" in result.stdout

    def test_demo_has_airflow_config(self) -> None:
        """Full pipeline demo should include Airflow config ConfigMap."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "airflow-config" in result.stdout

    def test_demo_counts_deployments(self) -> None:
        """Full pipeline demo should have expected number of Deployments."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        deployment_count = result.stdout.count("kind: Deployment")
        # Expected: spark-master, spark-worker, airflow-webserver, airflow-scheduler,
        # jupyter, spark-connect, history-server, minio, hive-metastore = 9
        assert deployment_count >= 8, f"Expected at least 8 Deployments, got {deployment_count}"

    def test_demo_counts_services(self) -> None:
        """Full pipeline demo should have expected number of Services."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "full-demo",
                "charts/spark-3.5",
                "-f",
                "charts/spark-3.5/values-demo-full-pipeline.yaml",
                "--namespace",
                "demo",
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        service_count = result.stdout.count("kind: Service")
        assert service_count >= 7, f"Expected at least 7 Services, got {service_count}"

    def test_demo_values_file_exists(self) -> None:
        """Demo values file should exist."""
        values_file = Path("charts/spark-3.5/values-demo-full-pipeline.yaml")
        assert values_file.exists(), "Demo values file not found"

    def test_demo_readme_exists(self) -> None:
        """Demo README file should exist."""
        readme = Path("charts/spark-3.5/README-demo-full-pipeline.md")
        assert readme.exists(), "Demo README not found"


class TestSparkStandaloneSubchart:
    """Test Spark Standalone subchart templates."""

    def test_subchart_lint(self) -> None:
        """Subchart should pass helm lint."""
        result = subprocess.run(
            ["helm", "lint", "charts/spark-3.5/charts/spark-standalone"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Lint failed: {result.stderr}"

    def test_subchart_template_renders(self) -> None:
        """Subchart should render without errors."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "test",
                "charts/spark-3.5/charts/spark-standalone",
                "--namespace",
                "test",
            ],
            capture_output=True,
            text=True,
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
            assert template_path.exists(), f"Airflow template {template} not found"

    def test_subchart_has_dags(self) -> None:
        """Subchart should have DAG files."""
        dags_dir = Path("charts/spark-3.5/charts/spark-standalone/dags")
        assert dags_dir.exists(), "DAGs directory not found"

        dag_files = list(dags_dir.glob("*.py"))
        assert len(dag_files) >= 1, "No DAG files found"

    def test_symlink_exists(self) -> None:
        """Spark-standalone symlink should exist and be valid."""
        symlink = Path("charts/spark-standalone")
        assert symlink.exists(), "Symlink does not exist or is broken"
        assert symlink.is_symlink(), "Not a symlink"


class TestAirflowDAGs:
    """Test Airflow DAG files."""

    def test_etl_dag_exists(self) -> None:
        """ETL example DAG should exist."""
        dag_file = Path("docker/optional/airflow/dags/spark_etl_example.py")
        assert dag_file.exists(), "ETL DAG file not found"

    def test_streaming_dag_exists(self) -> None:
        """Streaming example DAG should exist."""
        dag_file = Path("docker/optional/airflow/dags/spark_streaming_example.py")
        assert dag_file.exists(), "Streaming DAG file not found"

    def test_etl_dag_syntax(self) -> None:
        """ETL DAG should have valid Python syntax."""
        dag_file = Path("docker/optional/airflow/dags/spark_etl_example.py")
        content = dag_file.read_text()
        compile(content, dag_file, "exec")  # Will raise SyntaxError if invalid

    def test_streaming_dag_syntax(self) -> None:
        """Streaming DAG should have valid Python syntax."""
        dag_file = Path("docker/optional/airflow/dags/spark_streaming_example.py")
        content = dag_file.read_text()
        compile(content, dag_file, "exec")  # Will raise SyntaxError if invalid

    def test_etl_dag_has_spark_kubernetes_operator(self) -> None:
        """ETL DAG should use SparkKubernetesOperator."""
        dag_file = Path("docker/optional/airflow/dags/spark_etl_example.py")
        content = dag_file.read_text()
        assert "SparkKubernetesOperator" in content

    def test_etl_dag_has_s3_config(self) -> None:
        """ETL DAG should have S3 configuration."""
        dag_file = Path("docker/optional/airflow/dags/spark_etl_example.py")
        content = dag_file.read_text()
        assert "fs.s3a" in content or "s3_endpoint" in content
