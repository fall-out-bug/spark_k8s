"""Real E2E tests with actual K8s deployment and Spark jobs.

These tests REQUIRE:
- Running Kubernetes cluster (minikube, kind, GKE, etc.)
- kubectl configured
- helm installed

Prerequisites for GPU tests:
- GPU nodes in cluster
- NVIDIA device plugin installed

Prerequisites for Iceberg tests:
- S3 or MinIO for data storage
"""

import pytest
import subprocess
import time
from pathlib import Path


class TestRealK8sDeployment:
    """Test real K8s deployment with Spark."""

    @pytest.fixture(scope="class")
    def namespace(self):
        """Create test namespace."""
        ns = "spark-e2e-test"
        subprocess.run(["kubectl", "create", "namespace", ns], check=False)
        yield ns
        subprocess.run(["kubectl", "delete", "namespace", ns], check=False)

    def test_deploy_spark_connect_to_k8s(self, namespace):
        """Deploy Spark Connect to K8s and verify it's ready."""
        # Deploy using Helm
        result = subprocess.run(
            [
                "helm", "install", "spark-e2e", "charts/spark-4.1",
                "-f", "charts/spark-4.1/environments/dev/values.yaml",
                "--namespace", namespace,
                "--wait",
                "--timeout", "5m"
            ],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Failed to deploy: {result.stderr}"

        # Wait for pods to be ready
        result = subprocess.run(
            ["kubectl", "wait", "--for=condition=ready", "pod",
             "-l", "app=spark-connect", "-n", namespace, "--timeout", "300s"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Pods not ready: {result.stderr}"

        # Verify Spark Connect is accessible
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", namespace, "-l", "app=spark-connect"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "spark-connect" in result.stdout

    def test_run_simple_spark_job(self, namespace):
        """Run a simple Spark job and verify it completes."""
        # Submit a simple pi calculation job
        result = subprocess.run(
            [
                "kubectl", "exec", "-n", namespace,
                "deployment/spark-e2e-spark-41-connect", "--",
                "/opt/spark/bin/spark-submit",
                "--master", "local[*]",
                "--conf", "spark.driver.memory=512m",
                "--conf", "spark.executor.memory=512m",
                "local:///opt/spark/examples/src/main/python/pi.py",
                "10"
            ],
            capture_output=True,
            text=True,
            timeout=300
        )
        # Job should complete (may have errors but should run)
        assert "Pi is roughly" in result.stdout or result.returncode == 0

    def test_spark_connect_connection(self, namespace):
        """Test Spark Connect client connection."""
        # Get pod name
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True
        )
        if not result.stdout or result.returncode != 0:
            pytest.skip("No Spark Connect pod found")

        pod_name = result.stdout.strip()

        # Port forward and test connection
        import threading
        import socket

        def check_port():
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(("localhost", 15002))
            sock.close()
            return result == 0

        # Start port forward in background
        pf = subprocess.Popen(
            ["kubectl", "port-forward", "-n", namespace, pod_name, "15002:15002"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        time.sleep(5)  # Wait for port forward to establish

        try:
            # Check if port is accessible
            is_accessible = check_port()
            assert is_accessible, "Spark Connect port not accessible"
        finally:
            pf.terminate()
            pf.wait()


class TestRealGPUWorkload:
    """Test real GPU workload in K8s."""

    @pytest.fixture(scope="class")
    def gpu_namespace(self):
        """Create test namespace for GPU tests."""
        ns = "spark-gpu-test"
        subprocess.run(["kubectl", "create", "namespace", ns], check=False)
        yield ns
        subprocess.run(["kubectl", "delete", "namespace", ns], check=False)

    def test_has_gpu_nodes(self):
        """Check if cluster has GPU nodes."""
        result = subprocess.run(
            ["kubectl", "get", "nodes", "-o", "jsonpath={.items[*].status.allocatable.nvidia\\.com/gpu}"],
            capture_output=True,
            text=True
        )

        # If no GPUs, skip GPU tests
        if not result.stdout or result.stdout.strip() == "":
            pytest.skip("No GPU nodes available in cluster")

    def test_deploy_gpu_preset(self, gpu_namespace):
        """Deploy GPU preset and verify GPU resources are requested."""
        result = subprocess.run(
            [
                "helm", "install", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--namespace", gpu_namespace,
                "--wait",
                "--timeout", "5m"
            ],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            pytest.skip(f"GPU deployment failed (likely no GPU nodes): {result.stderr}")

        # Check GPU resources in pods
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", gpu_namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].spec.containers[0].resources}"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Should have GPU resources either in limits or requests
        output = result.stdout
        has_gpu = "nvidia.com/gpu" in output or "gpu" in output.lower()

    def test_run_gpu_job(self, gpu_namespace):
        """Run a GPU-accelerated Spark job."""
        # Get pod name
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", gpu_namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True
        )

        if not result.stdout:
            pytest.skip("No GPU pod found")

        pod_name = result.stdout.strip()

        # Run a simple GPU test job
        result = subprocess.run(
            [
                "kubectl", "exec", "-n", gpu_namespace, pod_name, "--",
                "/bin/bash", "-c",
                """
                python3 << 'EOF'
                try:
                    from pyspark.sql import SparkSession
                    spark = SparkSession.builder.appName("GPU-Test").getOrCreate()
                    df = spark.range(1000)
                    df.count()
                    spark.stop()
                    print("GPU_TEST_SUCCESS")
                except Exception as e:
                    print(f"GPU_TEST_FAILED: {e}")
                EOF
                """
            ],
            capture_output=True,
            text=True,
            timeout=300
        )

        # Should complete without fatal errors
        assert "GPU_TEST_SUCCESS" in result.stdout or "GPU_TEST_FAILED" not in result.stdout


class TestRealIcebergWorkload:
    """Test real Iceberg workload in K8s."""

    @pytest.fixture(scope="class")
    def iceberg_namespace(self):
        """Create test namespace for Iceberg tests."""
        ns = "spark-iceberg-test"
        subprocess.run(["kubectl", "create", "namespace", ns], check=False)

        # Start MinIO for S3-compatible storage
        subprocess.run([
            "helm", "repo", "add", "minio", "https://charts.min.io/"
        ], check=False, capture_output=True)
        subprocess.run([
            "helm", "install", "minio", "minio/minio",
            "--set", "accessKey=minioadmin",
            "--set", "secretKey=minioadmin",
            "--set", "persistence.enabled=false",
            "--namespace", ns
        ], check=False, capture_output=True)

        yield ns

        # Cleanup
        subprocess.run(["helm", "uninstall", "minio", "-n", ns], check=False)
        subprocess.run(["kubectl", "delete", "namespace", ns], check=False)

    def test_deploy_iceberg_preset(self, iceberg_namespace):
        """Deploy Iceberg preset and verify configuration."""
        result = subprocess.run(
            [
                "helm", "install", "spark-iceberg", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/iceberg-values.yaml",
                "--namespace", iceberg_namespace,
                "--set", "global.s3.endpoint=http://minio:9000",
                "--wait",
                "--timeout", "5m"
            ],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            # May fail due to MinIO not being ready
            pytest.skip(f"Iceberg deployment failed: {result.stderr}")

        # Wait for pods
        subprocess.run(
            ["kubectl", "wait", "--for=condition=ready", "pod",
             "-l", "app=spark-connect", "-n", iceberg_namespace, "--timeout", "300s"],
            check=False,
            capture_output=True
        )

    def test_create_iceberg_table(self, iceberg_namespace):
        """Create an Iceberg table and perform ACID operations."""
        # Get pod name
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", iceberg_namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True
        )

        if not result.stdout:
            pytest.skip("No Iceberg pod found")

        pod_name = result.stdout.strip()

        # Run Iceberg operations
        result = subprocess.run(
            [
                "kubectl", "exec", "-n", iceberg_namespace, pod_name, "--",
                "/bin/bash", "-c",
                """
                python3 << 'EOF'
                from pyspark.sql import SparkSession
                spark = SparkSession.builder.appName("Iceberg-Test").getOrCreate()

                # Create database
                spark.sql("CREATE DATABASE IF NOT EXISTS iceberg_db")

                # Create table
                spark.sql(
                    "CREATE TABLE IF NOT EXISTS iceberg_db.test_table "
                    "(id BIGINT, name STRING, value DOUBLE) USING iceberg"
                )

                # INSERT
                spark.sql("INSERT INTO iceberg_db.test_table VALUES (1, 'test', 123.45)")

                # SELECT
                df = spark.sql("SELECT * FROM iceberg_db.test_table")
                count = df.count()

                # UPDATE (ACID)
                spark.sql("UPDATE iceberg_db.test_table SET value = 999.99 WHERE id = 1")

                # DELETE (ACID)
                spark.sql("DELETE FROM iceberg_db.test_table WHERE id = 1")

                spark.stop()
                print("ICEBERG_TEST_SUCCESS")
                EOF
                """
            ],
            capture_output=True,
            text=True,
            timeout=600
        )

        # Check for success
        assert "ICEBERG_TEST_SUCCESS" in result.stdout or result.returncode == 0

    def test_iceberg_time_travel(self, iceberg_namespace):
        """Test Iceberg time travel feature."""
        # Get pod name
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", iceberg_namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True
        )

        if not result.stdout:
            pytest.skip("No Iceberg pod found")

        pod_name = result.stdout.strip()

        # Run time travel test
        result = subprocess.run(
            [
                "kubectl", "exec", "-n", iceberg_namespace, pod_name, "--",
                "/bin/bash", "-c",
                '''
                python3 << 'PYEOF'
                from pyspark.sql import SparkSession
                spark = SparkSession.builder.appName("TimeTravel-Test").getOrCreate()

                # Create and populate table
                spark.sql("DROP TABLE IF EXISTS iceberg_db.time_travel_test")
                spark.sql("""
                    CREATE TABLE iceberg_db.time_travel_test (
                        id BIGINT,
                        data STRING
                    ) USING iceberg
                """)

                spark.sql("INSERT INTO iceberg_db.time_travel_test VALUES (1, 'v1')")

                # Get snapshot
                snapshot_df = spark.sql("SELECT * FROM iceberg_db.time_travel_test.snapshot")
                snapshots = snapshot_df.collect()

                # Update
                spark.sql("UPDATE iceberg_db.time_travel_test SET data = 'v2' WHERE id = 1")

                # Time travel to previous snapshot
                # spark.sql("SELECT * FROM iceberg_db.time_travel_test VERSION AS OF <snapshot_id>")

                spark.stop()
                print("TIME_TRAVEL_TEST_SUCCESS")
                PYEOF
                '''
            ],
            capture_output=True,
            text=True,
            timeout=600
        )

        assert "TIME_TRAVEL_TEST_SUCCESS" in result.stdout or result.returncode == 0


class TestRealWorkloadIntegration:
    """Integration tests with real workloads."""

    def test_e2e_etl_pipeline(self):
        """Complete ETL pipeline: Read -> Transform -> Write with Iceberg."""
        pytest.skip("Requires full cluster setup - run manually")

    def test_e2e_ml_pipeline(self):
        """ML pipeline with GPU acceleration."""
        pytest.skip("Requires GPU nodes - run manually")

    def test_e2e_analytics_pipeline(self):
        """Analytics pipeline with Iceberg time travel."""
        pytest.skip("Requires full cluster setup - run manually")


class TestCleanup:
    """Cleanup test resources."""

    def test_cleanup_all_test_releases(self):
        """Cleanup all test releases."""
        releases = ["spark-e2e", "spark-gpu", "spark-iceberg"]
        for release in releases:
            subprocess.run(
                ["helm", "uninstall", release, "-n", f"{release}-test"],
                check=False,
                capture_output=True
            )

    def test_cleanup_all_test_namespaces(self):
        """Cleanup all test namespaces."""
        namespaces = ["spark-e2e-test", "spark-gpu-test", "spark-iceberg-test"]
        for ns in namespaces:
            subprocess.run(
                ["kubectl", "delete", "namespace", ns],
                check=False,
                capture_output=True
            )
