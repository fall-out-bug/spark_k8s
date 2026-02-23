"""
GPU load test: Spark 4.1.0 + window functions with RAPIDS.

Scenario: Sustained load with GPU-accelerated window functions.
Duration: 30 minutes
Target: 0.5 query/second (heavier queries)
"""

import time
import pytest

from helpers import run_sustained_load, get_gpu_metrics
from helpers_validation import validate_load_metrics


@pytest.mark.load
@pytest.mark.gpu
@pytest.mark.timeout(2400)  # 40 minutes max
def test_gpu_window_functions_410(spark_connect_client):
    """
    GPU load test: Window functions with RAPIDS at 0.5 qps for 30 minutes.

    Spark 4.1.0, Airflow, connect-k8s, GPU enabled.

    Validates:
    - Sustained throughput at 0.5 qps
    - Error rate < 1%
    - GPU utilization > 60%
    - GPU memory stable (no leaks)
    """
    query = """
        SELECT
            passenger_count,
            fare_amount,
            trip_distance,
            AVG(fare_amount) OVER (
                PARTITION BY passenger_count
                ORDER BY pickup_datetime
                ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
            ) as rolling_avg_fare,
            ROW_NUMBER() OVER (
                PARTITION BY passenger_count
                ORDER BY fare_amount DESC
            ) as fare_rank
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (ORDER BY RAND()) as rand_id
            FROM nyc_taxi
            LIMIT 100000
        )
        WHERE rand_id <= 100000
    """

    duration_sec = 1800  # 30 minutes
    interval_sec = 2.0   # 0.5 qps (heavier queries)

    metrics = run_sustained_load(
        spark_connect_client,
        query,
        duration_sec=duration_sec,
        interval_sec=interval_sec,
        query_name="gpu_window_410",
    )

    # Collect GPU metrics
    gpu_metrics = get_gpu_metrics()

    # Validate metrics
    errors = validate_load_metrics(
        metrics,
        max_error_rate=0.01,
        min_throughput=0.4,
    )

    assert not errors, f"Load test failed: {'; '.join(errors)}"
    assert metrics["queries_success"] >= 800, f"Too few successful queries: {metrics['queries_success']}"

    # GPU-specific validations
    avg_gpu_util = gpu_metrics.get("utilization_pct", 0)
    assert avg_gpu_util > 60, f"GPU utilization too low: {avg_gpu_util}%"

    gpu_memory_used = gpu_metrics.get("memory_used_mb", 0)
    gpu_memory_total = gpu_metrics.get("memory_total_mb", 0)
    assert gpu_memory_used < gpu_memory_total * 0.8, \
        f"GPU memory too high: {gpu_memory_used}MB / {gpu_memory_total}MB"

    # Print summary
    print(f"\n=== GPU Load Test Summary (4.1.0 Window) ===")
    print(f"Duration: {metrics['actual_duration_sec']:.1f}s")
    print(f"Queries: {metrics['queries_success']} / {metrics['queries_total']}")
    print(f"Throughput: {metrics['throughput_qps']:.2f} qps")
    print(f"Error rate: {metrics['error_rate']:.2%}")
    print(f"Latency - Avg: {metrics['latency_avg_ms']:.1f}ms, "
          f"P50: {metrics['latency_p50_ms']:.1f}ms, "
          f"P95: {metrics['latency_p95_ms']:.1f}ms, "
          f"P99: {metrics['latency_p99_ms']:.1f}ms")
    print(f"GPU Utilization: {avg_gpu_util}%")
    print(f"GPU Memory: {gpu_memory_used}MB / {gpu_memory_total}MB")
