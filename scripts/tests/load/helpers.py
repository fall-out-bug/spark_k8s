"""
Helper functions for load testing.

Provides common utilities for running sustained load tests,
collecting metrics, and validating results.
"""

import subprocess
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from pyspark.sql import SparkSession


def run_sustained_load(
    client: SparkSession,
    query: str,
    duration_sec: int,
    interval_sec: float = 1.0,
    query_name: str = "query",
) -> Dict[str, Any]:
    """
    Run a sustained load test.

    Args:
        client: Spark Connect client
        query: SQL query to execute
        duration_sec: Test duration in seconds
        interval_sec: Interval between queries
        query_name: Name for the query (for logging)

    Returns:
        Dictionary with metrics (throughput, latencies, error rate)
    """
    import time

    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=duration_sec)

    metrics = {
        "query_name": query_name,
        "queries_total": 0,
        "queries_success": 0,
        "queries_failed": 0,
        "latencies": [],
        "start_time": start_time.isoformat(),
        "duration_sec": duration_sec,
    }

    print(f"[{query_name}] Starting sustained load: {duration_sec}s, {interval_sec}s interval")

    while datetime.now() < end_time:
        try:
            query_start = datetime.now()
            result = client.sql(query)
            result.collect()
            query_end = datetime.now()

            latency_ms = (query_end - query_start).total_seconds() * 1000
            metrics["latencies"].append(latency_ms)
            metrics["queries_success"] += 1

            if metrics["queries_total"] % 60 == 0:
                elapsed = (datetime.now() - start_time).total_seconds()
                print(f"[{query_name}] Progress: {elapsed:.0f}/{duration_sec}s, "
                      f"qps: {metrics['queries_success']/elapsed:.2f}")

        except Exception as e:
            metrics["queries_failed"] += 1
            print(f"[{query_name}] Query failed: {e}")
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

    return metrics


def get_gpu_metrics() -> Dict[str, Any]:
    """
    Collect GPU metrics using nvidia-smi.

    Returns:
        Dictionary with GPU utilization and memory usage
    """
    try:
        output = subprocess.check_output([
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"
        ]).decode().strip()

        if not output:
            return {"utilization_pct": 0, "memory_used_mb": 0, "memory_total_mb": 0}

        parts = output.split(", ")
        return {
            "utilization_pct": int(parts[0]) if len(parts) > 0 else 0,
            "memory_used_mb": int(parts[1]) if len(parts) > 1 else 0,
            "memory_total_mb": int(parts[2]) if len(parts) > 2 else 0,
        }
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
        return {"utilization_pct": 0, "memory_used_mb": 0, "memory_total_mb": 0}
