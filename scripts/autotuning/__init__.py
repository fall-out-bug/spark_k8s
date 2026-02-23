"""Spark Autotuning Tools.

A collection of tools for automatically tuning Spark configurations
based on runtime metrics and workload analysis.

Modules:
    collector: Metrics collection from Prometheus
    analyzer: Pattern detection and workload analysis
    recommender: Configuration recommendations
    applier: Helm values generation

Usage:
    from autotuning import collect_metrics, analyze_metrics, generate_recommendations, apply_recommendations

    metrics = collect_metrics(app_id="app-123")
    analysis = analyze_metrics(metrics_file="metrics.json")
    recs = generate_recommendations(analysis_file="analysis.json")
    apply_recommendations(recommendations_file="recs.json", output_path="values.yaml")
"""

from autotuning.analyzer import (
    AnalysisResult,
    DetectedIssue,
    WorkloadAnalyzer,
    analyze_metrics,
    classify_workload,
    load_rules_config,
)
from autotuning.applier import (
    HelmValuesGenerator,
    ValidationResult,
    apply_recommendations,
    generate_helm_overlay,
    validate_helm_values,
)
from autotuning.collector import (
    MetricsCollector,
    MetricsResult,
    collect_metrics,
    load_metrics_config,
)
from autotuning.recommender import (
    ConfigRecommender,
    Recommendation,
    RecommendationSet,
    generate_recommendations,
    load_bounds_config,
    load_profiles_config,
)

__version__ = "0.4.0"
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
    # Recommender
    "ConfigRecommender",
    "Recommendation",
    "RecommendationSet",
    "generate_recommendations",
    "load_bounds_config",
    "load_profiles_config",
    # Applier
    "HelmValuesGenerator",
    "ValidationResult",
    "apply_recommendations",
    "generate_helm_overlay",
    "validate_helm_values",
]
