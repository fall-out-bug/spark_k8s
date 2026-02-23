"""
Comparison load test: Spark 3.5.8 vs 4.1.1 - SELECT + aggregation.

Scenario: Compare performance of same query on both versions.
Duration: 60 minutes (30 min per version)
"""

import pytest

from helpers import run_sustained_load
from helpers_validation import generate_comparison_report


@pytest.mark.load
@pytest.mark.comparison
@pytest.mark.timeout(4800)  # 80 minutes max
def test_version_comparison_select_aggregation(
    spark_358_client,
    spark_411_client,
):
    """
    Compare Spark 3.5.8 vs 4.1.1 performance for SELECT + aggregation.

    Same query, 30 minutes each version.

    Validates:
    - No significant regressions (> 20% slowdown)
    - Both versions stable under load
    """
    if spark_358_client is None or spark_411_client is None:
        pytest.skip("Both Spark 3.5.8 and 4.1.1 clients required")

    query = """
        SELECT
            passenger_count,
            SUM(fare_amount) as total_fare,
            AVG(trip_distance) as avg_distance,
            COUNT(*) as trip_count
        FROM nyc_taxi
        GROUP BY passenger_count
    """

    duration_sec = 1800  # 30 minutes
    interval_sec = 1.0   # 1 qps

    # Test 3.5.8
    print("\n=== Testing Spark 3.5.8 ===")
    metrics_358 = run_sustained_load(
        spark_358_client,
        query,
        duration_sec=duration_sec,
        interval_sec=interval_sec,
        query_name="comparison_select_358",
    )

    # Test 4.1.1
    print("\n=== Testing Spark 4.1.1 ===")
    metrics_411 = run_sustained_load(
        spark_411_client,
        query,
        duration_sec=duration_sec,
        interval_sec=interval_sec,
        query_name="comparison_select_411",
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
    print(f"\n=== Version Comparison Summary (SELECT + Aggregation) ===")
    print(f"Spark 3.5.8: {metrics_358['throughput_qps']:.2f} qps, "
          f"P95: {metrics_358['latency_p95_ms']:.1f}ms")
    print(f"Spark 4.1.1: {metrics_411['throughput_qps']:.2f} qps, "
          f"P95: {metrics_411['latency_p95_ms']:.1f}ms")
    print(f"Throughput diff: {report['throughput']['diff_pct']:.1f}%")
    print(f"Latency P95 diff: {report['latency_p95']['diff_pct']:.1f}%")

    return report
