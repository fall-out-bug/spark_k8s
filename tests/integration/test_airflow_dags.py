"""Tests for Airflow DAG files."""

from pathlib import Path


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
        compile(content, dag_file, "exec")

    def test_streaming_dag_syntax(self) -> None:
        """Streaming DAG should have valid Python syntax."""
        dag_file = Path("docker/optional/airflow/dags/spark_streaming_example.py")
        content = dag_file.read_text()
        compile(content, dag_file, "exec")

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
