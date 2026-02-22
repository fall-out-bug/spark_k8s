"""Spark Autotuning Tools.

A collection of tools for automatically tuning Spark configurations
based on runtime metrics and workload analysis.

Modules:
    collector: Metrics collection from Prometheus
    analyzer: Pattern detection and workload analysis
    recommender: Configuration recommendations
    applier: Helm values generation

Usage:
    from autotuning import collect_metrics, analyze_metrics

    metrics = collect_metrics(app_id="app-123")
    analysis = analyze_metrics(metrics_file="metrics.json")
    print(analysis.issues)
"""

from autotuning.analyzer import (
    AnalysisResult,
    DetectedIssue,
    WorkloadAnalyzer,
    analyze_metrics,
    classify_workload,
    load_rules_config,
)
from autotuning.collector import (
    MetricsCollector,
    MetricsResult,
    collect_metrics,
    load_metrics_config,
)

__version__ = "0.2.0"
__all__ = [
    # Collector
    "MetricsCollector",
    "MetricsResult",
    "collect_metrics",
    "load_metrics_config",
    # Analyzer
    "AnalysisResult",
    "DetectedIssue",
    "WorkloadAnalyzer",
    "analyze_metrics",
    "classify_workload",
    "load_rules_config",
]
