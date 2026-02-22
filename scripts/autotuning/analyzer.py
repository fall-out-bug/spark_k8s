"""Pattern analyzer for Spark autotuning.

Analyzes collected metrics to detect performance issues and classify workloads.

Usage:
    python -m autotuning.analyzer --metrics-file metrics.json --output analysis.json
"""

from __future__ import annotations

import argparse
import json
import logging
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

# Default config path relative to this module
DEFAULT_RULES_PATH = Path(__file__).parent / "config" / "rules.yaml"


@dataclass
class DetectedIssue:
    """Represents a detected performance issue."""

    issue_type: str
    severity: str  # ok, warning, critical
    metric_value: float
    threshold: float
    recommendation: str
    rationale: str = ""

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "issue_type": self.issue_type,
            "severity": self.severity,
            "metric_value": self.metric_value,
            "threshold": self.threshold,
            "recommendation": self.recommendation,
            "rationale": self.rationale,
        }


@dataclass
class AnalysisResult:
    """Result of metrics analysis."""

    app_id: str
    timestamp: datetime
    workload_type: str  # etl_batch, interactive, ml_training, streaming
    issues: list[DetectedIssue]
    metrics_summary: dict[str, float]
    duration_seconds: float = 0.0
    confidence: float = 0.0

    @property
    def has_issues(self) -> bool:
        """Check if any issues were detected."""
        return len(self.issues) > 0

    @property
    def critical_issues(self) -> list[DetectedIssue]:
        """Get only critical issues."""
        return [i for i in self.issues if i.severity == "critical"]

    @property
    def warning_issues(self) -> list[DetectedIssue]:
        """Get only warning issues."""
        return [i for i in self.issues if i.severity == "warning"]

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "app_id": self.app_id,
            "timestamp": self.timestamp.isoformat(),
            "workload_type": self.workload_type,
            "issues": [i.to_dict() for i in self.issues],
            "metrics_summary": self.metrics_summary,
            "duration_seconds": self.duration_seconds,
            "confidence": self.confidence,
            "has_issues": self.has_issues,
            "critical_count": len(self.critical_issues),
            "warning_count": len(self.warning_issues),
        }

    def to_json(self) -> str:
        """Serialize to JSON string."""
        return json.dumps(self.to_dict(), indent=2, default=str)

    def save(self, path: Path) -> None:
        """Save result to file."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.to_json())
        logger.info(f"Saved analysis to {path}")


def load_rules_config(config_path: Path | None = None) -> dict[str, Any]:
    """Load detection rules configuration from YAML file.

    Args:
        config_path: Path to config file. Uses default if None.

    Returns:
        Configuration dictionary.

    Raises:
        FileNotFoundError: If config file doesn't exist.
    """
    if config_path is None:
        config_path = DEFAULT_RULES_PATH

    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(f"Rules config file not found: {config_path}")

    with open(config_path) as f:
        return yaml.safe_load(f)


class WorkloadAnalyzer:
    """Analyzes Spark metrics to detect performance issues and classify workloads.

    Attributes:
        rules: Detection rules configuration.
    """

    def __init__(self, rules_path: Path | None = None):
        """Initialize analyzer.

        Args:
            rules_path: Path to detection rules YAML file.
        """
        self._rules = None
        self._rules_path = rules_path

    @property
    def rules(self) -> dict[str, Any]:
        """Lazy load rules configuration."""
        if self._rules is None:
            self._rules = load_rules_config(self._rules_path)
        return self._rules

    def analyze(
        self,
        app_id: str,
        metrics: dict[str, float],
        duration_seconds: float = 0.0,
        timestamp: datetime | None = None,
    ) -> AnalysisResult:
        """Analyze metrics and detect issues.

        Args:
            app_id: Spark application ID.
            metrics: Dictionary of metric name to value.
            duration_seconds: Application duration in seconds.
            timestamp: Analysis timestamp.

        Returns:
            AnalysisResult with detected issues and workload classification.
        """
        if timestamp is None:
            timestamp = datetime.now()

        logger.info(f"Analyzing metrics for app_id={app_id}")

        # Detect issues
        issues = self.detect_issues(metrics)

        # Classify workload
        workload_type = self.classify_workload(metrics)

        # Create summary
        metrics_summary = {k: v for k, v in metrics.items() if v is not None}

        # Calculate confidence based on metrics completeness
        confidence = self._calculate_confidence(metrics)

        result = AnalysisResult(
            app_id=app_id,
            timestamp=timestamp,
            workload_type=workload_type,
            issues=issues,
            metrics_summary=metrics_summary,
            duration_seconds=duration_seconds,
            confidence=confidence,
        )

        logger.info(
            f"Analysis complete: {len(issues)} issues detected, "
            f"workload_type={workload_type}, confidence={confidence:.2f}"
        )

        return result

    def detect_issues(self, metrics: dict[str, float]) -> list[DetectedIssue]:
        """Detect performance issues based on rules.

        Args:
            metrics: Dictionary of metric name to value.

        Returns:
            List of DetectedIssue objects.
        """
        issues = []
        detection_rules = self.rules.get("detection_rules", {})

        for rule_name, rule_config in detection_rules.items():
            metric_name = rule_config.get("metric")
            if not metric_name:
                continue

            metric_value = metrics.get(metric_name)
            if metric_value is None:
                continue

            # Get thresholds
            thresholds = rule_config.get("thresholds", {})
            warning_threshold = thresholds.get("warning", 0)
            critical_threshold = thresholds.get("critical", 0)
            condition = rule_config.get("condition", "gt")

            # Determine severity
            severity = self.determine_severity(
                value=metric_value,
                warning_threshold=warning_threshold,
                critical_threshold=critical_threshold,
                condition=condition,
            )

            if severity != "ok":
                # Build rationale
                rationale_template = rule_config.get("rationale", "")
                rationale = rationale_template.replace(
                    "{{value}}", str(metric_value)
                )

                issue = DetectedIssue(
                    issue_type=rule_name,
                    severity=severity,
                    metric_value=metric_value,
                    threshold=(
                        critical_threshold
                        if severity == "critical"
                        else warning_threshold
                    ),
                    recommendation=rule_config.get("recommendation", ""),
                    rationale=rationale,
                )
                issues.append(issue)
                logger.debug(
                    f"Detected {rule_name}: {severity} "
                    f"(value={metric_value}, threshold={issue.threshold})"
                )

        return issues

    def determine_severity(
        self,
        value: float,
        warning_threshold: float,
        critical_threshold: float,
        condition: str,
    ) -> str:
        """Determine severity level based on value and thresholds.

        Args:
            value: Metric value.
            warning_threshold: Warning threshold.
            critical_threshold: Critical threshold.
            condition: Comparison condition ("gt" or "lt").

        Returns:
            Severity level: "ok", "warning", or "critical".
        """
        if value is None:
            return "ok"

        if condition == "gt":
            # Greater than: critical > warning > ok
            if value >= critical_threshold:
                return "critical"
            elif value >= warning_threshold:
                return "warning"
        elif condition == "lt":
            # Less than: critical < warning < ok
            if value <= critical_threshold:
                return "critical"
            elif value <= warning_threshold:
                return "warning"

        return "ok"

    def classify_workload(self, metrics: dict[str, float]) -> str:
        """Classify workload type based on metrics patterns.

        Args:
            metrics: Dictionary of metric name to value.

        Returns:
            Workload type string: "etl_batch", "interactive", "ml_training", or "streaming".
        """
        classification_rules = self.rules.get("workload_classification", {})

        # Score each workload type
        scores = {}
        for workload_type, config in classification_rules.items():
            score = 0
            indicators = config.get("indicators", [])

            for indicator in indicators:
                metric_name = indicator.get("metric")
                condition = indicator.get("condition")
                expected_value = indicator.get("value")

                actual_value = metrics.get(metric_name)
                if actual_value is None:
                    continue

                if self._check_condition(actual_value, condition, expected_value):
                    score += 1

            scores[workload_type] = score

        # Return type with highest score
        if not scores or max(scores.values()) == 0:
            return "etl_batch"  # Default

        return max(scores, key=scores.get)

    def _check_condition(
        self, actual: float, condition: str, expected: float
    ) -> bool:
        """Check if condition is met.

        Args:
            actual: Actual metric value.
            condition: Condition type (gt, lt, eq).
            expected: Expected value.

        Returns:
            True if condition is met.
        """
        if actual is None:
            return False

        condition_ops = {
            "gt": lambda a, e: a > e,
            "lt": lambda a, e: a < e,
            "eq": lambda a, e: a == e,
        }
        op = condition_ops.get(condition)
        return op(actual, expected) if op else False

    def _calculate_confidence(self, metrics: dict[str, float]) -> float:
        """Calculate confidence score based on metrics completeness.

        Args:
            metrics: Dictionary of metric name to value.

        Returns:
            Confidence score between 0 and 1.
        """
        # Key metrics for analysis
        key_metrics = [
            "gc_ratio",
            "memory_spill",
            "task_skew_ratio",
            "cpu_utilization",
            "shuffle_write",
            "task_duration_avg",
        ]

        present_count = sum(1 for m in key_metrics if metrics.get(m) is not None)
        return present_count / len(key_metrics)


def classify_workload(metrics: dict[str, float]) -> str:
    """Classify workload type (convenience function).

    Args:
        metrics: Dictionary of metric name to value.

    Returns:
        Workload type string.
    """
    analyzer = WorkloadAnalyzer()
    return analyzer.classify_workload(metrics)


def analyze_metrics(
    metrics_file: Path,
    output_path: Path | None = None,
    rules_path: Path | None = None,
) -> AnalysisResult:
    """Analyze metrics from file.

    Convenience function for CLI and programmatic use.

    Args:
        metrics_file: Path to metrics JSON file.
        output_path: Optional path to save results.
        rules_path: Path to rules config file.

    Returns:
        AnalysisResult with analysis.
    """
    metrics_file = Path(metrics_file)
    if not metrics_file.exists():
        raise FileNotFoundError(f"Metrics file not found: {metrics_file}")

    with open(metrics_file) as f:
        data = json.load(f)

    analyzer = WorkloadAnalyzer(rules_path=rules_path)
    result = analyzer.analyze(
        app_id=data.get("app_id", "unknown"),
        metrics=data.get("metrics", {}),
        duration_seconds=data.get("duration_seconds", 0),
        timestamp=(
            datetime.fromisoformat(data["timestamp"])
            if "timestamp" in data
            else None
        ),
    )

    if output_path:
        result.save(output_path)

    return result


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Analyze Spark metrics for autotuning recommendations"
    )
    parser.add_argument(
        "--metrics-file", "-m",
        required=True,
        type=Path,
        help="Path to metrics JSON file from collector",
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        help="Output file path for analysis JSON",
    )
    parser.add_argument(
        "--rules",
        type=Path,
        help="Path to detection rules YAML",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging",
    )

    args = parser.parse_args()

    # Configure logging
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    # Analyze metrics
    result = analyze_metrics(
        metrics_file=args.metrics_file,
        output_path=args.output,
        rules_path=args.rules,
    )

    # Print summary
    print(f"\nAnalysis for {result.app_id}")
    print(f"Workload type: {result.workload_type}")
    print(f"Confidence: {result.confidence:.0%}")
    print(f"Issues detected: {len(result.issues)}")

    if result.issues:
        print("\nDetected Issues:")
        severity_config = load_rules_config(args.rules).get("severity_levels", {})
        for issue in result.issues:
            sev_config = severity_config.get(issue.severity, {})
            icon = sev_config.get("icon", "•")
            print(f"  {icon} [{issue.severity.upper()}] {issue.issue_type}")
            print(f"      Value: {issue.metric_value:.4g}, Threshold: {issue.threshold}")
            print(f"      Recommendation: {issue.recommendation}")

    if args.output:
        print(f"\nSaved to: {args.output}")
    else:
        print("\nFull analysis:")
        print(result.to_json())


if __name__ == "__main__":
    main()
