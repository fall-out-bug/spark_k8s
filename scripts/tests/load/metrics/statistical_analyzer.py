#!/usr/bin/env python3
"""
Statistical Analyzer for Load Testing
Part of WS-013-10: Metrics Collection & Regression Detection

Provides statistical analysis functions for metrics data.

Usage:
    python statistical_analyzer.py confidence-interval --values '[1.0, 1.1, 1.2, ...]'
    python statistical_analyzer.py trend --file metrics.jsonl --metric duration_sec
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np
from scipy import stats


class StatisticalAnalyzer:
    """Provides statistical analysis for load test metrics."""

    @staticmethod
    def calculate_confidence_interval(
        values: List[float],
        confidence: float = 0.95,
    ) -> Tuple[float, float, float]:
        """
        Calculate confidence interval for a sample.

        Args:
            values: Sample values
            confidence: Confidence level (default: 0.95 for 95% CI)

        Returns:
            Tuple of (mean, lower_bound, upper_bound)
        """
        if not values:
            return (0, 0, 0)

        n = len(values)
        mean = np.mean(values)

        if n < 2:
            return (mean, mean, mean)

        # Calculate standard error
        std_error = stats.sem(values)

        # Calculate t-value for confidence interval
        t_value = stats.t.ppf((1 + confidence) / 2, n - 1)

        # Calculate margin of error
        margin = t_value * std_error

        return (
            float(mean),
            float(mean - margin),
            float(mean + margin),
        )

    @staticmethod
    def paired_t_test(
        sample_a: List[float],
        sample_b: List[float],
    ) -> Tuple[float, float]:
        """
        Perform paired t-test between two samples.

        Args:
            sample_a: First sample
            sample_b: Second sample

        Returns:
            Tuple of (t_statistic, p_value)
        """
        if len(sample_a) != len(sample_b) or len(sample_a) < 2:
            return (0, 1)

        t_statistic, p_value = stats.ttest_rel(sample_a, sample_b)
        return (float(t_statistic), float(p_value))

    @staticmethod
    def detect_outliers_iqr(values: List[float]) -> List[int]:
        """
        Detect outliers using IQR (Interquartile Range) method.

        Args:
            values: List of values

        Returns:
            List of outlier indices
        """
        if len(values) < 4:
            return []

        q1 = np.percentile(values, 25)
        q3 = np.percentile(values, 75)
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

    @staticmethod
    def detect_outliers_zscore(
        values: List[float],
        threshold: float = 3.0,
    ) -> List[int]:
        """
        Detect outliers using z-score method.

        Args:
            values: List of values
            threshold: Z-score threshold (default: 3.0)

        Returns:
            List of outlier indices
        """
        if len(values) < 3:
            return []

        mean = np.mean(values)
        std = np.std(values)

        if std == 0:
            return []

        outliers = []
        for i, v in enumerate(values):
            z_score = abs((v - mean) / std)
            if z_score > threshold:
                outliers.append(i)

        return outliers

    @staticmethod
    def analyze_trend(
        values: List[float],
        window_size: int = 5,
    ) -> Dict[str, Any]:
        """
        Analyze trend in time-series data.

        Args:
            values: Time-series values
            window_size: Window size for moving average

        Returns:
            Trend analysis dictionary
        """
        if len(values) < window_size:
            return {"trend": "insufficient_data"}

        # Calculate moving average
        moving_avg = []
        for i in range(len(values) - window_size + 1):
            window = values[i:i + window_size]
            moving_avg.append(np.mean(window))

        # Calculate linear regression
        x = np.arange(len(moving_avg))
        y = np.array(moving_avg)

        if len(x) < 2:
            return {"trend": "insufficient_data"}

        slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)

        # Determine trend direction
        if p_value > 0.05:
            trend = "no_significant_trend"
        elif slope > 0:
            trend = "increasing"
        else:
            trend = "decreasing"

        return {
            "trend": trend,
            "slope": float(slope),
            "r_squared": float(r_value ** 2),
            "p_value": float(p_value),
            "moving_average": [float(v) for v in moving_avg],
        }

    @staticmethod
    def calculate_percentiles(values: List[float]) -> Dict[str, float]:
        """
        Calculate percentiles for a dataset.

        Args:
            values: List of values

        Returns:
            Dictionary with percentile values
        """
        if not values:
            return {
                "p50": 0,
                "p75": 0,
                "p90": 0,
                "p95": 0,
                "p99": 0,
            }

        return {
            "p50": float(np.percentile(values, 50)),
            "p75": float(np.percentile(values, 75)),
            "p90": float(np.percentile(values, 90)),
            "p95": float(np.percentile(values, 95)),
            "p99": float(np.percentile(values, 99)),
        }


def main():
    parser = argparse.ArgumentParser(
        description="Statistical analysis for load test metrics"
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # Confidence interval command
    ci_parser = subparsers.add_parser('confidence-interval', help='Calculate confidence interval')
    ci_parser.add_argument(
        '--values', type=str, required=True,
        help='Values as JSON array'
    )
    ci_parser.add_argument(
        '--confidence', type=float, default=0.95,
        help='Confidence level (default: 0.95)'
    )

    # T-test command
    tt_parser = subparsers.add_parser('t-test', help='Perform paired t-test')
    tt_parser.add_argument(
        '--sample-a', type=str, required=True,
        help='Sample A as JSON array'
    )
    tt_parser.add_argument(
        '--sample-b', type=str, required=True,
        help='Sample B as JSON array'
    )

    # Outliers command
    outliers_parser = subparsers.add_parser('outliers', help='Detect outliers')
    outliers_parser.add_argument(
        '--values', type=str, required=True,
        help='Values as JSON array'
    )
    outliers_parser.add_argument(
        '--method', type=str, default='iqr',
        choices=['iqr', 'zscore'],
        help='Outlier detection method'
    )

    # Trend command
    trend_parser = subparsers.add_parser('trend', help='Analyze trend')
    trend_parser.add_argument(
        '--values', type=str, required=True,
        help='Time-series values as JSON array'
    )
    trend_parser.add_argument(
        '--window-size', type=int, default=5,
        help='Window size for moving average'
    )

    # Percentiles command
    perc_parser = subparsers.add_parser('percentiles', help='Calculate percentiles')
    perc_parser.add_argument(
        '--values', type=str, required=True,
        help='Values as JSON array'
    )

    args = parser.parse_args()

    analyzer = StatisticalAnalyzer()

    if args.command == 'confidence-interval':
        values = json.loads(args.values)
        mean, lower, upper = analyzer.calculate_confidence_interval(
            values,
            args.confidence,
        )

        result = {
            "mean": mean,
            "confidence": args.confidence,
            "lower_bound": lower,
            "upper_bound": upper,
            "margin": upper - mean,
        }
        print(json.dumps(result, indent=2))
        return 0

    elif args.command == 't-test':
        sample_a = json.loads(args.sample_a)
        sample_b = json.loads(args.sample_b)

        t_stat, p_value = analyzer.paired_t_test(sample_a, sample_b)

        result = {
            "t_statistic": t_stat,
            "p_value": p_value,
            "significant": p_value < 0.05,
        }
        print(json.dumps(result, indent=2))
        return 0

    elif args.command == 'outliers':
        values = json.loads(args.values)

        if args.method == 'iqr':
            outliers = analyzer.detect_outliers_iqr(values)
        else:
            outliers = analyzer.detect_outliers_zscore(values)

        result = {
            "outlier_indices": outliers,
            "outlier_values": [values[i] for i in outliers] if outliers else [],
            "count": len(outliers),
        }
        print(json.dumps(result, indent=2))
        return 0

    elif args.command == 'trend':
        values = json.loads(args.values)
        result = analyzer.analyze_trend(values, args.window_size)
        print(json.dumps(result, indent=2))
        return 0

    elif args.command == 'percentiles':
        values = json.loads(args.values)
        result = analyzer.calculate_percentiles(values)
        print(json.dumps(result, indent=2))
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == '__main__':
    sys.exit(main())
