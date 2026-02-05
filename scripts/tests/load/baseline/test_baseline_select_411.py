"""
Baseline load test: Spark 4.1.1 + SELECT + aggregation.

Scenario: Sustained load with SELECT and aggregation queries.
Duration: 30 minutes
Target: 1 query/second
"""

import time
import pytest

from helpers import run_sustained_load
from helpers_validation import validate_load_metrics


@pytest.mark.load
@pytest.mark.baseline
@pytest.mark.timeout(2400)  # 40 minutes max
def test_baseline_select_aggregation_411(spark_connect_client):
    """
    Baseline load test: SELECT + aggregation at 1 qps for 30 minutes.

    Spark 4.1.1, Airflow, connect-k8s mode.

    Validates:
    - Sustained throughput at 1 qps
    - Error rate < 1%
    - Stable latency percentiles
    """
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

    metrics = run_sustained_load(
        spark_connect_client,
        query,
        duration_sec=duration_sec,
        interval_sec=interval_sec,
        query_name="baseline_select_411",
    )

    # Validate metrics
    errors = validate_load_metrics(
        metrics,
        max_error_rate=0.01,
        min_throughput=0.9,
    )

    assert not errors, f"Load test failed: {'; '.join(errors)}"
    assert metrics["queries_success"] >= 1700, f"Too few successful queries: {metrics['queries_success']}"

    # Print summary
    print(f"\n=== Baseline Load Test Summary (4.1.1) ===")
    print(f"Duration: {metrics['actual_duration_sec']:.1f}s")
    print(f"Queries: {metrics['queries_success']} / {metrics['queries_total']}")
    print(f"Throughput: {metrics['throughput_qps']:.2f} qps")
    print(f"Error rate: {metrics['error_rate']:.2%}")
    print(f"Latency - Avg: {metrics['latency_avg_ms']:.1f}ms, "
          f"P50: {metrics['latency_p50_ms']:.1f}ms, "
          f"P95: {metrics['latency_p95_ms']:.1f}ms, "
          f"P99: {metrics['latency_p99_ms']:.1f}ms")
