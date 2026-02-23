"""Real E2E: Spark Connect deployment to K8s."""

import subprocess
import time

import pytest


class TestRealK8sDeployment:
    """Test real K8s deployment with Spark."""

    @pytest.fixture(scope="class")
    def namespace(self) -> str:
        """Create test namespace."""
        ns = "spark-e2e-test"
        subprocess.run(["kubectl", "create", "namespace", ns], check=False, capture_output=True)
        yield ns
        subprocess.run(["kubectl", "delete", "namespace", ns], check=False, capture_output=True)

    def test_deploy_spark_connect_to_k8s(self, namespace: str) -> None:
        """Deploy Spark Connect to K8s and verify it's ready."""
        result = subprocess.run(
            [
                "helm", "install", "spark-e2e", "charts/spark-4.1",
                "-f", "charts/spark-4.1/environments/dev/values.yaml",
                "--namespace", namespace,
                "--wait", "--timeout", "5m"
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Failed to deploy: {result.stderr}"

        result = subprocess.run(
            ["kubectl", "wait", "--for=condition=ready", "pod",
             "-l", "app=spark-connect", "-n", namespace, "--timeout", "300s"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Pods not ready: {result.stderr}"

        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", namespace, "-l", "app=spark-connect"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "spark-connect" in result.stdout

    def test_run_simple_spark_job(self, namespace: str) -> None:
        """Run a simple Spark job and verify it completes."""
        result = subprocess.run(
            [
                "kubectl", "exec", "-n", namespace,
                "deployment/spark-e2e-spark-41-connect", "--",
                "/opt/spark/bin/spark-submit",
                "--master", "local[*]",
                "--conf", "spark.driver.memory=512m",
                "--conf", "spark.executor.memory=512m",
                "local:///opt/spark/examples/src/main/python/pi.py", "10"
            ],
            capture_output=True,
            text=True,
            timeout=300,
        )
        assert "Pi is roughly" in result.stdout or result.returncode == 0

    def test_spark_connect_connection(self, namespace: str) -> None:
        """Test Spark Connect client connection."""
        import socket

        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", namespace,
             "-l", "app=spark-connect", "-o", "jsonpath={.items[0].metadata.name}"],
            capture_output=True,
            text=True,
        )
        if not result.stdout or result.returncode != 0:
            pytest.skip("No Spark Connect pod found")

        pod_name = result.stdout.strip()
        pf = subprocess.Popen(
            ["kubectl", "port-forward", "-n", namespace, pod_name, "15002:15002"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(5)
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            ok = sock.connect_ex(("localhost", 15002)) == 0
            sock.close()
            assert ok, "Spark Connect port not accessible"
        finally:
            pf.terminate()
            pf.wait()
