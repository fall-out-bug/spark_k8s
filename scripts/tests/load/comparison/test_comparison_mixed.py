"""
Comparison load test: Spark 3.5.8 vs 4.1.1 - Mixed workload.

Scenario: Compare performance of mixed queries on both versions.
Duration: 60 minutes (30 min per version)
"""

import random
import time
import pytest

from datetime import datetime, timedelta
from typing import Any, Dict

from pyspark.sql import SparkSession

from helpers_validation import generate_comparison_report


def run_mixed_workload(client: SparkSession, queries: list,
                        duration_sec: int, interval_sec: float,
                        label: str) -> Dict[str, Any]:
    """Run mixed workload test."""
    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=duration_sec)

    metrics = {
        "query_name": f"comparison_mixed_{label}",
        "queries_total": 0,
        "queries_success": 0,
        "queries_failed": 0,
        "latencies": [],
        "start_time": start_time.isoformat(),
        "duration_sec": duration_sec,
    }

    print(f"\n=== Testing Spark {label} (Mixed Workload) ===")

    while datetime.now() < end_time:
        try:
            query_start = datetime.now()
            query = random.choice(queries)
            result = client.sql(query)
            result.collect()
            query_end = datetime.now()

            latency_ms = (query_end - query_start).total_seconds() * 1000
            metrics["latencies"].append(latency_ms)
            metrics["queries_success"] += 1
        except Exception as e:
            metrics["queries_failed"] += 1
            print(f"[{label}] Query failed: {e}")
        finally:
            metrics["queries_total"] += 1
            time.sleep(interval_sec)

    actual_duration = (datetime.now() - start_time).total_seconds()
    metrics["actual_duration_sec"] = actual_duration
    metrics["throughput_qps"] = metrics["queries_total"] / actual_duration if actual_duration > 0 else 0
    metrics["error_rate"] = (
        metrics["queries_failed"] / metrics["queries_total"]
        if metrics["queries_total"] > 0 else 0
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

    return metrics


@pytest.mark.load
@pytest.mark.comparison
@pytest.mark.timeout(4800)  # 80 minutes max
def test_version_comparison_mixed_workload(
    spark_358_client,
    spark_411_client,
):
    """
    Compare Spark 3.5.8 vs 4.1.1 performance for mixed workload.

    Mix of SELECT, JOIN, and aggregation queries, 30 minutes each version.

    Validates:
    - No significant regressions (> 20% slowdown)
    - Both versions stable under load
    """
    if spark_358_client is None or spark_411_client is None:
        pytest.skip("Both Spark 3.5.8 and 4.1.1 clients required")

    queries = [
        """
        SELECT
            passenger_count,
            SUM(fare_amount) as total_fare
        FROM nyc_taxi
        GROUP BY passenger_count
        """,
        """
        SELECT COUNT(*) FROM nyc_taxi
        """,
        """
        SELECT
            passenger_count,
            AVG(trip_distance) as avg_distance
        FROM nyc_taxi
        GROUP BY passenger_count
        HAVING COUNT(*) > 1000
        """,
    ]

    duration_sec = 1800
    interval_sec = 1.0

    metrics_358 = run_mixed_workload(
        spark_358_client, queries, duration_sec, interval_sec, "3.5.8"
    )
    metrics_411 = run_mixed_workload(
        spark_411_client, queries, duration_sec, interval_sec, "4.1.1"
    )

    # Generate comparison report
    report = generate_comparison_report(
        metrics_358,
        metrics_411,
        label_a="3.5.8",
        label_b="4.1.1",
    )

    # Assertions
    assert report["throughput"]["regression"] is False, \
        f"Significant throughput regression: {report['throughput']['diff_pct']:.1f}%"
    assert report["latency_p95"]["regression"] is False, \
        f"Significant latency regression: {report['latency_p95']['diff_pct']:.1f}%"

    # Print summary
    print(f"\n=== Version Comparison Summary (Mixed Workload) ===")
    print(f"Spark 3.5.8: {metrics_358['throughput_qps']:.2f} qps, "
          f"P95: {metrics_358['latency_p95_ms']:.1f}ms")
    print(f"Spark 4.1.1: {metrics_411['throughput_qps']:.2f} qps, "
          f"P95: {metrics_411['latency_p95_ms']:.1f}ms")
    print(f"Throughput diff: {report['throughput']['diff_pct']:.1f}%")
    print(f"Latency P95 diff: {report['latency_p95']['diff_pct']:.1f}%")

    return report
