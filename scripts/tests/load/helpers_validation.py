"""
Validation and comparison helpers for load testing.
"""

from typing import Any, Dict, List, Optional


def validate_load_metrics(
    metrics: Dict[str, Any],
    max_error_rate: float = 0.01,
    min_throughput: float = 0.5,
    max_latency_p95_ms: Optional[float] = None,
) -> List[str]:
    """
    Validate load test metrics against thresholds.

    Args:
        metrics: Metrics dictionary from run_sustained_load
        max_error_rate: Maximum acceptable error rate
        min_throughput: Minimum acceptable throughput (qps)
        max_latency_p95_ms: Maximum acceptable p95 latency

    Returns:
        List of validation error messages (empty if all pass)
    """
    errors = []

    error_rate = metrics.get("error_rate", 1.0)
    if error_rate > max_error_rate:
        errors.append(
            f"Error rate too high: {error_rate:.2%} > {max_error_rate:.2%}"
        )

    throughput = metrics.get("throughput_qps", 0)
    if throughput < min_throughput:
        errors.append(
            f"Throughput too low: {throughput:.2f} qps < {min_throughput:.2f} qps"
        )

    if max_latency_p95_ms is not None:
        latency_p95 = metrics.get("latency_p95_ms", 0)
        if latency_p95 > max_latency_p95_ms:
            errors.append(
                f"P95 latency too high: {latency_p95:.1f}ms > {max_latency_p95_ms:.1f}ms"
            )

    return errors


def generate_comparison_report(
    metrics_a: Dict[str, Any],
    metrics_b: Dict[str, Any],
    label_a: str = "A",
    label_b: str = "B",
) -> Dict[str, Any]:
    """
    Generate a comparison report between two metric sets.

    Args:
        metrics_a: First set of metrics
        metrics_b: Second set of metrics
        label_a: Label for first set
        label_b: Label for second set

    Returns:
        Comparison report dictionary
    """
    throughput_a = metrics_a.get("throughput_qps", 0)
    throughput_b = metrics_b.get("throughput_qps", 0)

    latency_p95_a = metrics_a.get("latency_p95_ms", 0)
    latency_p95_b = metrics_b.get("latency_p95_ms", 0)

    error_rate_a = metrics_a.get("error_rate", 0)
    error_rate_b = metrics_b.get("error_rate", 0)

    return {
        "throughput": {
            label_a: throughput_a,
            label_b: throughput_b,
            "diff_pct": ((throughput_b - throughput_a) / throughput_a * 100) if throughput_a > 0 else 0,
            "regression": throughput_b < throughput_a * 0.8,  # > 20% slowdown
        },
        "latency_p95": {
            label_a: latency_p95_a,
            label_b: latency_p95_b,
            "diff_pct": ((latency_p95_b - latency_p95_a) / latency_p95_a * 100) if latency_p95_a > 0 else 0,
            "regression": latency_p95_b > latency_p95_a * 1.2,  # > 20% increase
        },
        "error_rate": {
            label_a: error_rate_a,
            label_b: error_rate_b,
        },
    }
