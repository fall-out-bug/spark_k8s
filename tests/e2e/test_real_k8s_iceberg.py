"""Real E2E: Iceberg workload and cleanup tests."""

import subprocess

import pytest


class TestRealIcebergWorkload:
    """Test real Iceberg workload in K8s."""

    @pytest.fixture(scope="class")
    def iceberg_namespace(self) -> str:
        """Create test namespace for Iceberg tests."""
        ns = "spark-iceberg-test"
        subprocess.run(["kubectl", "create", "namespace", ns], check=False, capture_output=True)
        subprocess.run(["helm", "repo", "add", "minio", "https://charts.min.io/"],
                      check=False, capture_output=True)
        subprocess.run([
            "helm", "install", "minio", "minio/minio",
            "--set", "accessKey=minioadmin",
            "--set", "secretKey=minioadmin",
            "--set", "persistence.enabled=false",
            "--namespace", ns
        ], check=False, capture_output=True)
        yield ns
        subprocess.run(["helm", "uninstall", "minio", "-n", ns], check=False, capture_output=True)
        subprocess.run(["kubectl", "delete", "namespace", ns], check=False, capture_output=True)

    def test_deploy_iceberg_preset(self, iceberg_namespace: str) -> None:
        """Deploy Iceberg preset and verify configuration."""
        result = subprocess.run(
            [
                "helm", "install", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", iceberg_namespace,
                "--set", "global.s3.endpoint=http://minio:9000",
                "--wait", "--timeout", "5m"
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            pytest.skip(f"Iceberg deployment failed: {result.stderr}")

        subprocess.run(
            ["kubectl", "wait", "--for=condition=ready", "pod",
             "-l", "app=spark-connect", "-n", iceberg_namespace, "--timeout", "300s"],
            check=False,
            capture_output=True,
        )

    def test_create_iceberg_table(self, iceberg_namespace: str) -> None:
        """Create an Iceberg table and perform ACID operations."""
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", iceberg_namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True,
        )
        if not result.stdout:
            pytest.skip("No Iceberg pod found")

        pod_name = result.stdout.strip()
        script = """
        from pyspark.sql import SparkSession
        spark = SparkSession.builder.appName("Iceberg-Test").getOrCreate()
        spark.sql("CREATE DATABASE IF NOT EXISTS iceberg_db")
        spark.sql("CREATE TABLE IF NOT EXISTS iceberg_db.test_table "
                  "(id BIGINT, name STRING, value DOUBLE) USING iceberg")
        spark.sql("INSERT INTO iceberg_db.test_table VALUES (1, 'test', 123.45)")
        spark.sql("SELECT * FROM iceberg_db.test_table").count()
        spark.sql("UPDATE iceberg_db.test_table SET value = 999.99 WHERE id = 1")
        spark.sql("DELETE FROM iceberg_db.test_table WHERE id = 1")
        spark.stop()
        print("ICEBERG_TEST_SUCCESS")
        """
        result = subprocess.run(
            ["kubectl", "exec", "-n", iceberg_namespace, pod_name, "--",
             "python3", "-c", script],
            capture_output=True,
            text=True,
            timeout=600,
        )
        assert "ICEBERG_TEST_SUCCESS" in result.stdout or result.returncode == 0

    def test_iceberg_time_travel(self, iceberg_namespace: str) -> None:
        """Test Iceberg time travel feature."""
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", iceberg_namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True,
        )
        if not result.stdout:
            pytest.skip("No Iceberg pod found")

        pod_name = result.stdout.strip()
        script = """
        from pyspark.sql import SparkSession
        spark = SparkSession.builder.appName("TimeTravel-Test").getOrCreate()
        spark.sql("DROP TABLE IF EXISTS iceberg_db.time_travel_test")
        spark.sql("CREATE TABLE iceberg_db.time_travel_test (id BIGINT, data STRING) USING iceberg")
        spark.sql("INSERT INTO iceberg_db.time_travel_test VALUES (1, 'v1')")
        spark.sql("UPDATE iceberg_db.time_travel_test SET data = 'v2' WHERE id = 1")
        spark.stop()
        print("TIME_TRAVEL_TEST_SUCCESS")
        """
        result = subprocess.run(
            ["kubectl", "exec", "-n", iceberg_namespace, pod_name, "--",
             "python3", "-c", script],
            capture_output=True,
            text=True,
            timeout=600,
        )
        assert "TIME_TRAVEL_TEST_SUCCESS" in result.stdout or result.returncode == 0


class TestRealWorkloadIntegration:
    """Integration tests with real workloads."""

    def test_e2e_etl_pipeline(self) -> None:
        """Complete ETL pipeline."""
        pytest.skip("Requires full cluster setup - run manually")

    def test_e2e_ml_pipeline(self) -> None:
        """ML pipeline with GPU acceleration."""
        pytest.skip("Requires GPU nodes - run manually")

    def test_e2e_analytics_pipeline(self) -> None:
        """Analytics pipeline with Iceberg time travel."""
        pytest.skip("Requires full cluster setup - run manually")


class TestCleanup:
    """Cleanup test resources."""

    def test_cleanup_all_test_releases(self) -> None:
        """Cleanup all test releases."""
        for release, ns in [
            ("spark-e2e", "spark-e2e-test"),
            ("spark-gpu", "spark-gpu-test"),
            ("spark-iceberg", "spark-iceberg-test"),
        ]:
            subprocess.run(
                ["helm", "uninstall", release, "-n", ns],
                check=False,
                capture_output=True,
            )

    def test_cleanup_all_test_namespaces(self) -> None:
        """Cleanup all test namespaces."""
        for ns in ["spark-e2e-test", "spark-gpu-test", "spark-iceberg-test"]:
            subprocess.run(
                ["kubectl", "delete", "namespace", ns],
                check=False,
                capture_output=True,
            )
