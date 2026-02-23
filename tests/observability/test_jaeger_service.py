"""
Runtime tests for Jaeger distributed tracing from Spark applications.

Tests:
1. Jaeger service is accessible
2. Spark traces are being collected
"""

import pytest
import subprocess


class TestJaegerService:
    """Tests for Jaeger service accessibility"""
    skip_pod = False

    @pytest.fixture(scope="class")
    def jaeger_pod(self, request):
        """Get Jaeger pod (collector or query)"""
        import os
        kube_namespace = os.getenv("KUBE_NAMESPACE", "spark-operations")
        # Try collector first
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app=jaeger",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            # Try all-in-one
            cmd = [
                "kubectl", "get", "pods", "-n", kube_namespace,
                "-l", "app=jaeger-all-in-one",
                "-o", "jsonpath={.items[0].metadata.name}"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0 or not result.stdout.strip():
            request.cls.skip_pod = True
            pytest.skip("Jaeger pod not found")
        return result.stdout.strip()

    def test_jaeger_pod_running(self, jaeger_pod, kube_namespace):
        """Test that Jaeger pod is running"""
        cmd = [
            "kubectl", "get", "pod", "-n", kube_namespace, jaeger_pod,
            "-o", "jsonpath={.status.phase}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.stdout.strip() == "Running"

    def test_jaeger_ui_service(self, kube_namespace):
        """Test that Jaeger UI service exists"""
        # Check for Jaeger UI service
        cmd = [
            "kubectl", "get", "svc", "-n", kube_namespace,
            "-o", "jsonpath={.items[*].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("No services found in namespace (cluster not running)")
        services = result.stdout.split()

        jaeger_services = [s for s in services if "jaeger" in s.lower()]
        assert len(jaeger_services) > 0, f"Jaeger service should exist, got services: {services}"


class TestTraceCollection:
    """Tests for trace collection from Spark applications"""
    skip_pod = False

    @pytest.fixture(scope="class")
    def jaeger_query_pod(self, request):
        """Get Jaeger Query pod for API access"""
        import os
        kube_namespace = os.getenv("KUBE_NAMESPACE", "spark-operations")
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app=jaeger-query",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            request.cls.skip_pod = True
            pytest.skip("Jaeger Query pod not found")
        return result.stdout.strip()

    def test_jaeger_api_services(self, jaeger_query_pod, kube_namespace):
        """Test that Jaeger API endpoints are accessible"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, jaeger_query_pod,
            "--", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "http://localhost:16686/api/services"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        # May return 200 or 401 depending on auth
        assert result.stdout.strip() in ["200", "401"]

    def test_spark_tracing_config(self, charts_dir):
        """Test that Spark tracing configuration exists"""
        # Check for OpenTelemetry or Jaeger config in charts
        config_files = []

        # Look for Jaeger agent configuration
        for chart_path in charts_dir.rglob("*.yaml"):
            content = chart_path.read_text()
            if "jaeger" in content.lower() and ("agent" in content.lower() or "tracer" in content.lower()):
                config_files.append(chart_path)

        # Also check for OpenTelemetry config
        for chart_path in charts_dir.rglob("*.yaml"):
            content = chart_path.read_text()
            if "opentelemetry" in content.lower() or "otel" in content.lower():
                config_files.append(chart_path)

        assert len(config_files) > 0, "Tracing configuration should exist"


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")


@pytest.fixture
def charts_dir():
    """Get charts directory"""
    from pathlib import Path
    return Path(__file__).parent.parent.parent / "charts"
