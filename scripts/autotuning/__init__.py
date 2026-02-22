"""Spark Autotuning Tools.

A collection of tools for automatically tuning Spark configurations
based on runtime metrics and workload analysis.

Modules:
    collector: Metrics collection from Prometheus
    analyzer: Pattern detection and workload analysis
    recommender: Configuration recommendations
    applier: Helm values generation

Usage:
    from autotuning import collect_metrics

    result = collect_metrics(app_id="app-123")
    print(result.metrics)
"""

from autotuning.collector import (
    MetricsCollector,
    MetricsResult,
    collect_metrics,
    load_metrics_config,
)

__version__ = "0.1.0"
__all__ = [
    "MetricsCollector",
    "MetricsResult",
    "collect_metrics",
    "load_metrics_config",
]
