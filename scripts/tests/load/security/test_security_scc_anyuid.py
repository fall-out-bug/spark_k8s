"""
Security stability load test: SCC anyuid mode under load.

Scenario: Validate SCC anyuid policies remain stable under sustained load.
Duration: 30 minutes
"""

import os
import time
import pytest

try:
    from kubernetes import client, config
    K8S_AVAILABLE = True
except ImportError:
    K8S_AVAILABLE = False

from helpers import run_sustained_load
from helpers_validation import validate_load_metrics


@pytest.mark.load
@pytest.mark.security
@pytest.mark.timeout(2400)  # 40 minutes max
@pytest.mark.skipif(not K8S_AVAILABLE, reason="kubernetes library not available")
def test_scc_anyuid_stability(spark_connect_client):
    """
    Security stability test: SCC anyuid mode at 1 qps for 30 minutes.

    Validates:
    - Sustained throughput at 1 qps
    - Error rate < 1%
    - Container permissions stable
    - No escalation beyond allowed scope
    """
    query = """
        SELECT COUNT(*) FROM nyc_taxi
    """

    duration_sec = 1800  # 30 minutes
    interval_sec = 1.0   # 1 qps

    # Load kubeconfig
    try:
        config.load_kube_config()
    except Exception:
        config.load_incluster_config()

    k8s_core_api = client.CoreV1Api()
    namespace = os.getenv("TEST_NAMESPACE", "spark-load-test")

    from datetime import datetime, timedelta

    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=duration_sec)

    metrics = {
        "query_name": "scc_anyuid_stability",
        "queries_total": 0,
        "queries_success": 0,
        "queries_failed": 0,
        "latencies": [],
        "permission_violations": 0,
        "start_time": start_time.isoformat(),
        "duration_sec": duration_sec,
    }

    print(f"[scc_anyuid] Starting sustained load: {duration_sec}s, {interval_sec}s interval")

    while datetime.now() < end_time:
        try:
            # Run query
            query_start = datetime.now()
            result = spark_connect_client.sql(query)
            result.collect()
            query_end = datetime.now()

            latency_ms = (query_end - query_start).total_seconds() * 1000
            metrics["latencies"].append(latency_ms)
            metrics["queries_success"] += 1

            # Check container permissions every 60 seconds
            if metrics["queries_total"] % 60 == 0:
                try:
                    pods = k8s_core_api.list_namespaced_pod(
                        namespace=namespace,
                        label_selector="app.kubernetes.io/component=executor"
                    )

                    for pod in pods.items:
                        # Check for unexpected privilege escalation
                        for container in pod.spec.containers:
                            # anyuid should not require privileged mode
                            if container.security_context and container.security_context.privileged:
                                metrics["permission_violations"] += 1
                                print(f"WARNING: Unexpected privileged container: {pod.metadata.name}")

                except Exception as e:
                    print(f"WARNING: Could not check container permissions: {e}")

        except Exception as e:
            metrics["queries_failed"] += 1
            print(f"[scc_anyuid] Query failed: {e}")
        finally:
            metrics["queries_total"] += 1

            query_duration = (datetime.now() - query_start).total_seconds() if 'query_start' in locals() else 0
            sleep_time = max(0, interval_sec - query_duration)
            if sleep_time > 0 and datetime.now() < end_time:
                time.sleep(sleep_time)

    # Calculate derived metrics
    actual_duration = (datetime.now() - start_time).total_seconds()
    metrics["actual_duration_sec"] = actual_duration
    metrics["throughput_qps"] = metrics["queries_total"] / actual_duration if actual_duration > 0 else 0
    metrics["error_rate"] = (
        metrics["queries_failed"] / metrics["queries_total"]
        if metrics["queries_total"] > 0
        else 0
    )

    if metrics["latencies"]:
        sorted_latencies = sorted(metrics["latencies"])
        n = len(sorted_latencies)
        metrics["latency_p50_ms"] = sorted_latencies[n // 2]
        metrics["latency_p95_ms"] = sorted_latencies[int(n * 0.95)]
        metrics["latency_p99_ms"] = sorted_latencies[int(n * 0.99)]
        metrics["latency_avg_ms"] = sum(metrics["latencies"]) / len(metrics["latencies"])
    else:
        metrics["latency_p50_ms"] = 0
        metrics["latency_p95_ms"] = 0
        metrics["latency_p99_ms"] = 0
        metrics["latency_avg_ms"] = 0

    # Validate metrics
    errors = validate_load_metrics(
        metrics,
        max_error_rate=0.01,
        min_throughput=0.9,
    )

    assert not errors, f"Load test failed: {'; '.join(errors)}"
    assert metrics["permission_violations"] == 0, \
        f"Permission violations detected: {metrics['permission_violations']}"

    # Print summary
    print(f"\n=== Security Stability Summary (SCC AnyUID) ===")
    print(f"Duration: {metrics['actual_duration_sec']:.1f}s")
    print(f"Queries: {metrics['queries_success']} / {metrics['queries_total']}")
    print(f"Throughput: {metrics['throughput_qps']:.2f} qps")
    print(f"Error rate: {metrics['error_rate']:.2%}")
    print(f"Permission violations: {metrics['permission_violations']}")
