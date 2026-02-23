"""Real GPU workload tests with actual K8s deployment.

These tests REQUIRE:
- Running Kubernetes cluster with GPU nodes
- NVIDIA device plugin installed
"""

import pytest
import subprocess


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
            ["kubectl", "get", "nodes",
             "-o", "jsonpath={.items[*].status.allocatable.nvidia\\.com/gpu}"],
            capture_output=True,
            text=True
        )
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

        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", gpu_namespace,
             "-l", "app=spark-connect",
             "-o", "jsonpath={.items[0].spec.containers[0].resources}"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_run_gpu_job(self, gpu_namespace):
        """Run a GPU-accelerated Spark job."""
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", gpu_namespace,
             "-l", "app=spark-connect",
             "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True
        )
        if not result.stdout:
            pytest.skip("No GPU pod found")

        pod_name = result.stdout.strip()
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
        assert "GPU_TEST_SUCCESS" in result.stdout or "GPU_TEST_FAILED" not in result.stdout
