"""
Runtime tests for querying Jaeger traces.

Tests:
1. Services list retrieval
2. Trace search functionality
"""

import pytest
import subprocess


class TestTraceQueries:
    """Tests for querying traces through Jaeger"""

    @pytest.fixture(scope="class")
    def jaeger_query_pod(self, kube_namespace):
        """Get Jaeger Query pod for API access"""
        cmd = [
            "kubectl", "get", "pods", "-n", kube_namespace,
            "-l", "app=jaeger-query",
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not result.stdout.strip():
            pytest.skip("Jaeger Query pod not found")
        return result.stdout.strip()

    def test_get_services(self, jaeger_query_pod, kube_namespace):
        """Test that services list can be retrieved"""
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, jaeger_query_pod,
            "--", "curl", "-s",
            "http://localhost:16686/api/services"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Check response is valid JSON or empty array
        data = result.stdout
        assert "[" in data or "{" in data or "null" in data

    def test_search_traces(self, jaeger_query_pod, kube_namespace):
        """Test that traces can be searched"""
        # Search for traces from Spark services
        cmd = [
            "kubectl", "exec", "-n", kube_namespace, jaeger_query_pod,
            "--", "curl", "-s",
            "http://localhost:16686/api/traces?service=spark&limit=10"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0

        # Query should succeed - actual traces depend on running apps
        data = result.stdout
        # Check for valid response (empty or with data)
        assert "data" in data or "null" in data or "[]" in data


@pytest.fixture
def kube_namespace():
    """Get Kubernetes namespace for tests"""
    import os
    return os.getenv("KUBE_NAMESPACE", "spark-operations")
