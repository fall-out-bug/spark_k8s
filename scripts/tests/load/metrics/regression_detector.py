#!/usr/bin/env python3
"""
Regression Detector for Load Testing
Part of WS-013-10: Metrics Collection & Regression Detection

Detects performance regressions using statistical analysis.

Usage:
    python regression_detector.py detect --test-name p0_350_connect_kubernetes_none_read_1gb
    python regression_detector.py analyze --results-dir /tmp/load-test-results
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

from scipy import stats


# Regression thresholds
REGRESSION_THRESHOLD_PCT = 20.0  # > 20% degradation
P_VALUE_THRESHOLD = 0.05  # Statistical significance


class RegressionDetector:
    """Detects performance regressions in load test results."""

    def __init__(self, threshold_pct: float = REGRESSION_THRESHOLD_PCT):
        """
        Initialize regression detector.

        Args:
            threshold_pct: Regression threshold percentage
        """
        self.threshold_pct = threshold_pct

    def detect_regression(
        self,
        baseline: List[float],
        current: List[float],
        metric_name: str,
    ) -> Dict[str, Any]:
        """
        Detect regression in a single metric.

        Args:
            baseline: Baseline measurements
            current: Current measurements
            metric_name: Name of the metric

        Returns:
            Regression detection result
        """
        if not baseline or not current:
            return {
                "metric": metric_name,
                "status": "insufficient_data",
                "regression": False,
            }

        # Calculate statistics
        baseline_mean = sum(baseline) / len(baseline)
        current_mean = sum(current) / len(current)

        # Calculate percentage change
        if baseline_mean > 0:
            change_pct = ((current_mean - baseline_mean) / baseline_mean) * 100
        else:
            change_pct = 0

        # Perform paired t-test if sample sizes match
        p_value = None
        is_significant = False

        if len(baseline) == len(current) and len(baseline) > 1:
            _, p_value = stats.ttest_rel(baseline, current)
            is_significant = p_value < P_VALUE_THRESHOLD

        # Determine regression
        is_regression = (
            change_pct > self.threshold_pct and
            (is_significant or p_value is None)
        )

        return {
            "metric": metric_name,
            "baseline_mean": baseline_mean,
            "current_mean": current_mean,
            "change_pct": change_pct,
            "regression": is_regression,
            "p_value": p_value,
            "significant": is_significant,
        }

    def detect_resource_tradeoff(
        self,
        primary_metric: Dict[str, Any],
        resource_metric: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Detect if performance degradation is offset by resource improvement.

        Args:
            primary_metric: Primary performance metric result
            resource_metric: Resource efficiency metric result

        Returns:
            Trade-off analysis result
        """
        # If primary has regression but resource improved significantly
        if primary_metric.get("regression") and resource_metric.get("change_pct", 0) < -10:
            return {
                "trade_off": True,
                "message": f"Primary metric degraded by {primary_metric['change_pct']:.1f}% but resource usage improved by {abs(resource_metric['change_pct']):.1f}%",
            }

        return {"trade_off": False}

    def analyze_test_result(
        self,
        test_name: str,
        baseline_metrics: Dict[str, List[float]],
        current_metrics: Dict[str, List[float]],
    ) -> Dict[str, Any]:
        """
        Analyze a complete test result for regressions.

        Args:
            test_name: Name of the test
            baseline_metrics: Baseline metrics (dict of metric name to list of values)
            current_metrics: Current metrics (dict of metric name to list of values)

        Returns:
            Complete regression analysis
        """
        results = {}
        regressions = []
        trade_offs = []

        # Analyze each metric
        for metric_name in baseline_metrics.keys():
            if metric_name not in current_metrics:
                continue

            result = self.detect_regression(
                baseline_metrics[metric_name],
                current_metrics[metric_name],
                metric_name,
            )
            results[metric_name] = result

            if result["regression"]:
                regressions.append(metric_name)

        # Check for resource trade-offs
        primary_metrics = ["duration_sec", "throughput"]
        resource_metrics = ["cpu_usage_pct", "memory_usage_pct"]

        for pm in primary_metrics:
            if pm in results and results[pm]["regression"]:
                for rm in resource_metrics:
                    if rm in results:
                        trade_off = self.detect_resource_tradeoff(results[pm], results[rm])
                        if trade_off.get("trade_off"):
                            trade_offs.append(trade_off["message"])

        return {
            "test_name": test_name,
            "has_regression": len(regressions) > 0,
            "regressions": regressions,
            "trade_offs": trade_offs,
            "metrics": results,
        }

    def detect_outliers(self, values: List[float]) -> List[int]:
        """
        Detect outliers using IQR method.

        Args:
            values: List of values

        Returns:
            List of outlier indices
        """
        if len(values) < 4:
            return []

        sorted_values = sorted(values)
        n = len(sorted_values)
        q1 = sorted_values[n // 4]
        q3 = sorted_values[3 * n // 4]
        iqr = q3 - q1

        if iqr == 0:
            return []

        lower_bound = q1 - 1.5 * iqr
        upper_bound = q3 + 1.5 * iqr

        outliers = []
        for i, v in enumerate(values):
            if v < lower_bound or v > upper_bound:
                outliers.append(i)

        return outliers


def main():
    parser = argparse.ArgumentParser(
        description="Detect performance regressions"
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # Detect command
    detect_parser = subparsers.add_parser('detect', help='Detect regression')
    detect_parser.add_argument(
        '--test-name', type=str, required=True,
        help='Name of the test'
    )
    detect_parser.add_argument(
        '--baseline', type=str,
        help='Baseline values as JSON array'
    )
    detect_parser.add_argument(
        '--current', type=str,
        help='Current values as JSON array'
    )

    # Analyze command
    analyze_parser = subparsers.add_parser('analyze', help='Analyze test results')
    analyze_parser.add_argument(
        '--test-name', type=str, required=True,
        help='Name of the test'
    )
    analyze_parser.add_argument(
        '--results-dir', type=str,
        default='/tmp/load-test-results',
        help='Directory containing result files'
    )

    # Outliers command
    outliers_parser = subparsers.add_parser('outliers', help='Detect outliers')
    outliers_parser.add_argument(
        '--values', type=str, required=True,
        help='Values as JSON array'
    )

    args = parser.parse_args()

    detector = RegressionDetector()

    if args.command == 'detect':
        if not args.baseline or not args.current:
            print("Error: Must provide --baseline and --current")
            return 1

        baseline = json.loads(args.baseline)
        current = json.loads(args.current)

        result = detector.detect_regression(baseline, current, args.test_name)
        print(json.dumps(result, indent=2))

        if result.get("regression"):
            print("\nRegression detected!")
            return 1

        return 0

    elif args.command == 'analyze':
        # Load results from files
        results_dir = Path(args.results_dir)
        baseline_file = results_dir / f"{args.test_name}-baseline.jsonl"
        current_file = results_dir / f"{args.test_name}-current.jsonl"

        if not baseline_file.exists() or not current_file.exists():
            print(f"Error: Result files not found for {args.test_name}")
            return 1

        # Load metrics
        baseline_metrics = {}
        current_metrics = {}

        with open(baseline_file) as f:
            for line in f:
                data = json.loads(line)
                perf = data.get("tier3_performance", {})
                for key, value in perf.items():
                    if key not in baseline_metrics:
                        baseline_metrics[key] = []
                    baseline_metrics[key].append(value)

        with open(current_file) as f:
            for line in f:
                data = json.loads(line)
                perf = data.get("tier3_performance", {})
                for key, value in perf.items():
                    if key not in current_metrics:
                        current_metrics[key] = []
                    current_metrics[key].append(value)

        # Analyze
        result = detector.analyze_test_result(
            args.test_name,
            baseline_metrics,
            current_metrics,
        )
        print(json.dumps(result, indent=2))

        if result.get("has_regression"):
            print("\nRegression detected!")
            return 1

        return 0

    elif args.command == 'outliers':
        values = json.loads(args.values)
        outliers = detector.detect_outliers(values)

        print(f"Outlier indices: {outliers}")

        if outliers:
            print(f"Outlier values: {[values[i] for i in outliers]}")

        return 0

    else:
        parser.print_help()
        return 1


if __name__ == '__main__':
    sys.exit(main())
