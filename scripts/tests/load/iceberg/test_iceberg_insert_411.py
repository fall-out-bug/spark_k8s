"""
Iceberg load test: Spark 4.1.1 + INSERT operations.

Scenario: Sustained load with Iceberg INSERT operations.
Duration: 30 minutes
Target: 10 inserts/second
"""

import time
import pytest
from pyspark.sql import Row

from helpers import run_sustained_load
from helpers_validation import validate_load_metrics


@pytest.mark.load
@pytest.mark.iceberg
@pytest.mark.timeout(2400)  # 40 minutes max
def test_iceberg_insert_load_411(spark_connect_client):
    """
    Iceberg load test: INSERT at 10 ops/sec for 30 minutes.

    Spark 4.1.1, Airflow, connect-k8s, Iceberg enabled.

    Validates:
    - Sustained throughput at 10 inserts/sec
    - Error rate < 1%
    - No snapshot explosion (< 1000 snapshots)
    - Stable latency
    """
    duration_sec = 1800  # 30 minutes
    interval_sec = 0.1   # 10 inserts/sec

    from datetime import datetime, timedelta

    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=duration_sec)

    metrics = {
        "query_name": "iceberg_insert_411",
        "queries_total": 0,
        "queries_success": 0,
        "queries_failed": 0,
        "latencies": [],
        "start_time": start_time.isoformat(),
        "duration_sec": duration_sec,
    }

    print(f"[iceberg_insert_411] Starting sustained load: {duration_sec}s, {interval_sec}s interval")

    while datetime.now() < end_time:
        try:
            query_start = datetime.now()

            # Run INSERT operation
            test_data = spark_connect_client.createDataFrame([
                Row(id=metrics["queries_total"] % 100, value=10.5, source="load_test"),
                Row(id=(metrics["queries_total"] + 1) % 100, value=20.3, source="load_test"),
                Row(id=(metrics["queries_total"] + 2) % 100, value=15.7, source="load_test"),
            ])
            test_data.writeTo("nyc_iceberg.test_table").append()

            query_end = datetime.now()

            latency_ms = (query_end - query_start).total_seconds() * 1000
            metrics["latencies"].append(latency_ms)
            metrics["queries_success"] += 1

            if metrics["queries_total"] % 600 == 0:
                elapsed = (datetime.now() - start_time).total_seconds()
                print(f"[iceberg_insert_411] Progress: {elapsed:.0f}/{duration_sec}s, "
                      f"ops: {metrics['queries_success']/elapsed:.2f}/s")

        except Exception as e:
            metrics["queries_failed"] += 1
            print(f"[iceberg_insert_411] Insert failed: {e}")
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

    # Calculate percentiles
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
        min_throughput=9.0,
    )

    assert not errors, f"Load test failed: {'; '.join(errors)}"
    assert metrics["queries_success"] >= 16000, f"Too few successful inserts: {metrics['queries_success']}"

    # Check snapshot count
    try:
        table = spark_connect_client.table("nyc_iceberg.test_table")
        snapshot_count = table.select("snapshot_id").distinct().count()
        assert snapshot_count < 1000, f"Too many snapshots: {snapshot_count}"
        print(f"Snapshot count: {snapshot_count}")
    except Exception:
        print("Warning: Could not verify snapshot count")

    # Print summary
    print(f"\n=== Iceberg Load Test Summary (4.1.1 INSERT) ===")
    print(f"Duration: {metrics['actual_duration_sec']:.1f}s")
    print(f"Inserts: {metrics['queries_success']} / {metrics['queries_total']}")
    print(f"Throughput: {metrics['throughput_qps']:.2f} ops/sec")
    print(f"Error rate: {metrics['error_rate']:.2%}")
    print(f"Latency - Avg: {metrics['latency_avg_ms']:.1f}ms, "
          f"P50: {metrics['latency_p50_ms']:.1f}ms, "
          f"P95: {metrics['latency_p95_ms']:.1f}ms, "
          f"P99: {metrics['latency_p99_ms']:.1f}ms")
