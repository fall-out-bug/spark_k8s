#!/usr/bin/env python3
"""
Observability logging tests for Loki.

Tests Loki deployment, log aggregation, and log querying.
"""

import subprocess
import sys
from pathlib import Path


def run_command(cmd: list, description: str) -> dict:
    """Run a command and return result."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": "Command timed out after 30s",
            "returncode": -1
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }


def test_loki_deployment() -> dict:
    """Test if Loki is deployed and accessible."""
    print("Testing Loki deployment...")

    # Check if loki pod is running
    result = run_command([
        "kubectl", "get", "pods",
        "-n", "observability",
        "-l", "app=loki"
    ], "Loki pod check")

    if not result["success"]:
        return {
            "name": "Loki Deployment",
            "status": "failed",
            "message": f"Failed to get pods: {result['stderr']}"
        }

    pods = result["stdout"]
    if "loki" not in pods.lower():
        return {
            "name": "Loki Deployment",
            "status": "failed",
            "message": "No loki pod found"
        }

    # Check if Loki service is accessible
    result = run_command([
        "kubectl", "get", "svc",
        "-n", "observability",
        "loki"
    ], "Loki service check")

    if not result["success"]:
        return {
            "name": "Loki Service",
            "status": "failed",
            "message": f"Failed to get service: {result['stderr']}"
        }

    return {
        "name": "Loki Deployment",
        "status": "passed",
        "message": "Loki is deployed and accessible"
    }


def test_log_aggregation() -> dict:
    """Test if logs are being aggregated to Loki."""
    print("Testing log aggregation...")

    # Check if Promtail is deployed (for log aggregation)
    result = run_command([
        "kubectl", "get", "pods",
        "-n", "observability",
        "-l", "app=promtail"
    ], "Promtail pod check")

    if not result["success"]:
        return {
            "name": "Log Aggregation (Promtail)",
            "status": "error",
            "message": f"Failed to get pods: {result['stderr']}"
        }

    pods = result["stdout"]
    if "promtail" not in pods.lower():
        return {
            "name": "Log Aggregation (Promtail)",
            "status": "failed",
            "message": "No promtail pod found"
        }

    return {
        "name": "Log Aggregation (Promtail)",
        "status": "passed",
        "message": "Promtail is deployed"
    }


def test_log_query() -> dict:
    """Test log querying via Loki API."""
    print("Testing log querying...")

    # Check if Loki API is accessible
    result = run_command([
        "kubectl", "exec",
        "-n", "observability",
        "loki-0",
        "--", "curl",
        "-s", "http://localhost:3100/loki/api/v1/label",
        "--max-time", "10s"
    ], "Loki API label query")

    if not result["success"]:
        return {
            "name": "Loki API",
            "status": "error",
            "message": f"Failed to query Loki API: {result['stderr']}"
        }

    labels = result["stdout"].strip()
    if labels:
        return {
            "name": "Loki API",
            "status": "passed",
            "message": f"Loki API accessible, labels: {labels[:100]}"
        }

    return {
        "name": "Loki API",
        "status": "failed",
        "message": "No labels returned from Loki API"
    }


def main() -> int:
    """Run all observability logging tests."""
    results = []

    # Test Loki deployment
    results.append(test_loki_deployment())

    # Test log aggregation
    results.append(test_log_aggregation())

    # Test log querying
    results.append(test_log_query())

    # Print summary
    passed = sum(1 for r in results if r["status"] == "passed")
    failed = sum(1 for r in results if r["status"] in ["failed", "error"])

    print("\n" + "=" * 60)
    print("Observability Logging Tests Summary")
    print("=" * 60)
    print(f"Total tests: {len(results)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print("=" * 60 + "\n")

    # Print details
    for result in results:
        status_icon = "✅" if result["status"] == "passed" else "❌"
        print(f"{status_icon} {result['name']}: {result['message']}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
