#!/usr/bin/env python3
"""Observability monitoring tests for Prometheus."""

import subprocess
import sys


def run_command(cmd: list, description: str) -> dict:
    """Run a command and return result."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return {"success": result.returncode == 0, "stdout": result.stdout.strip(), "stderr": result.stderr.strip(), "returncode": result.returncode}
    except subprocess.TimeoutExpired:
        return {"success": False, "stdout": "", "stderr": "Command timed out after 30s", "returncode": -1}
    except Exception as e:
        return {"success": False, "stdout": "", "stderr": str(e), "returncode": -1}


def test_prometheus_deployment() -> dict:
    """Test if Prometheus is deployed and accessible."""
    print("Testing Prometheus deployment...")
    result = run_command(["kubectl", "get", "pods", "-n", "observability", "-l", "app=prometheus-operator"], "Prometheus pod check")

    if not result["success"]:
        return {"name": "Prometheus Deployment", "status": "failed", "message": f"Failed to get pods: {result['stderr']}"}

    pods = result["stdout"]
    if "prometheus-operator" not in pods:
        return {"name": "Prometheus Deployment", "status": "failed", "message": "No prometheus-operator pod found"}

    result = run_command(["kubectl", "get", "svc", "-n", "observability", "prometheus-operator"], "Prometheus service check")

    if not result["success"]:
        return {"name": "Prometheus Service", "status": "failed", "message": f"Failed to get service: {result['stderr']}"}

    return {"name": "Prometheus Deployment", "status": "passed", "message": "Prometheus is deployed and accessible"}


def test_service_monitors() -> dict:
    """Test if Spark ServiceMonitors are deployed."""
    print("Testing ServiceMonitors...")
    result = run_command(["kubectl", "get", "servicemonitors", "-n", "observability", "-o", "json"], "List ServiceMonitors")

    if not result["success"]:
        return {"name": "ServiceMonitors", "status": "failed", "message": f"Failed to list ServiceMonitors: {result['stderr']}"}

    import json
    try:
        monitors = json.loads(result["stdout"])
    except json.JSONDecodeError:
        return {"name": "ServiceMonitors", "status": "error", "message": f"Failed to parse ServiceMonitors JSON: {result['stdout']}"}

    expected_monitors = ["spark-driver", "spark-executor", "spark-3.5-driver", "spark-4.1-driver", "spark-4.1-executor"]

    missing = []
    for monitor in expected_monitors:
        found = any(m.get("metadata", {}).get("labels", {}).get("spark-app", "") == monitor for m in monitors)
        if not found:
            missing.append(monitor)

    if missing:
        return {"name": "ServiceMonitors", "status": "failed", "message": f"Missing ServiceMonitors: {', '.join(missing)}"}

    return {"name": "ServiceMonitors", "status": "passed", "message": f"Found {len(monitors)} ServiceMonitors"}


def test_prometheus_metrics() -> dict:
    """Test if Prometheus is scraping metrics."""
    print("Testing Prometheus metrics scraping...")
    result = run_command([
        "kubectl", "exec", "-n", "observability", "prometheus-operator-0", "--wget", "-q", "-O", "-",
        "http://localhost:9090/api/v1/targets", "--timeout=10"
    ], "Prometheus targets query")

    if not result["success"]:
        return {"name": "Prometheus Targets", "status": "error", "message": f"Failed to query targets: {result['stderr']}"}

    import json
    try:
        data = json.loads(result["stdout"])
    except json.JSONDecodeError:
        return {"name": "Prometheus Targets", "status": "error", "message": "Failed to parse targets response"}

    active_targets = [t for t in data.get("data", {}).get("activeTargets", []) if t.get("health", "") == "up"]
    total_targets = len(data.get("data", {}).get("activeTargets", []))

    if total_targets == 0:
        return {"name": "Prometheus Targets", "status": "failed", "message": "No active targets found"}

    if len(active_targets) < total_targets:
        return {"name": "Prometheus Targets", "status": "failed", "message": f"Only {len(active_targets)}/{total_targets} targets are up"}

    return {"name": "Prometheus Targets", "status": "passed", "message": f"All {total_targets} targets are up"}


def main() -> int:
    """Run all observability monitoring tests."""
    results = []

    results.append(test_prometheus_deployment())
    results.append(test_service_monitors())
    results.append(test_prometheus_metrics())

    passed = sum(1 for r in results if r["status"] == "passed")
    failed = sum(1 for r in results if r["status"] in ["failed", "error"])

    print("\n" + "=" * 60)
    print("Observability Monitoring Tests Summary")
    print("=" * 60)
    print(f"Total tests: {len(results)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print("=" * 60 + "\n")

    for result in results:
        status_icon = "✅" if result["status"] == "passed" else "❌"
        print(f"{status_icon} {result['name']}: {result['message']}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
