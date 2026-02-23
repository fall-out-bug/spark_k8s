#!/usr/bin/env python3
"""
Baseline Manager for Load Testing
Part of WS-013-10: Metrics Collection & Regression Detection

Manages baseline metrics for regression detection.

Usage:
    python baseline_manager.py create --test-name p0_350_connect_kubernetes_none_read_1gb
    python baseline_manager.py update --test-name p0_350_connect_kubernetes_none_read_1gb
    python baseline_manager.py compare --test-name p0_350_connect_kubernetes_none_read_1gb
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml


# Baseline storage
BASELINE_FILE = Path("/home/fall_out_bug/work/s7/spark_k8s/config/baselines/load-test-baselines.yaml")
RESULTS_DIR = Path("/tmp/load-test-results")


class BaselineManager:
    """Manages baseline metrics for load tests."""

    def __init__(self, baseline_file: Optional[Path] = None):
        """
        Initialize baseline manager.

        Args:
            baseline_file: Path to baseline YAML file
        """
        self.baseline_file = baseline_file or BASELINE_FILE
        self.baselines = self._load_baselines()

    def _load_baselines(self) -> Dict[str, Any]:
        """Load baselines from file."""
        if self.baseline_file.exists():
            with open(self.baseline_file) as f:
                return yaml.safe_load(f) or {}
        return {"baselines": {}}

    def _save_baselines(self) -> None:
        """Save baselines to file."""
        self.baseline_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.baseline_file, 'w') as f:
            yaml.dump(self.baselines, f, default_flow_style=False)

    def create_baseline(
        self,
        test_name: str,
        metrics: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None,
    ) -> None:
        """
        Create a new baseline from multiple runs.

        Args:
            test_name: Name of the test
            metrics: List of metric dictionaries
            metadata: Optional metadata (spark version, orchestrator, etc.)
        """
        if not metrics:
            raise ValueError("Cannot create baseline with empty metrics")

        # Calculate baseline statistics
        baseline_metrics = self._calculate_baseline_stats(metrics)

        # Store baseline
        self.baselines["baselines"][test_name] = {
            "metadata": metadata or {},
            "sample_size": len(metrics),
            "created_at": metrics[0].get("timestamp", ""),
            "metrics": baseline_metrics,
        }

        self._save_baselines()
        print(f"Baseline created for {test_name} from {len(metrics)} runs")

    def _calculate_baseline_stats(self, metrics: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Calculate baseline statistics from metrics.

        Args:
            metrics: List of metric dictionaries

        Returns:
            Dictionary with baseline statistics
        """
        # Extract performance metrics
        durations = [m.get("tier3_performance", {}).get("duration_sec", 0) for m in metrics]
        throughputs = [m.get("tier3_performance", {}).get("throughput", 0) for m in metrics]

        # Calculate statistics
        def stats(values: List[float]) -> Dict[str, float]:
            if not values or all(v == 0 for v in values):
                return {"mean": 0, "median": 0, "min": 0, "max": 0, "stddev": 0}

            sorted_values = sorted([v for v in values if v > 0])
            if not sorted_values:
                return {"mean": 0, "median": 0, "min": 0, "max": 0, "stddev": 0}

            n = len(sorted_values)
            mean = sum(sorted_values) / n
            median = sorted_values[n // 2]

            return {
                "mean": mean,
                "median": median,
                "min": min(sorted_values),
                "max": max(sorted_values),
                "stddev": (sum((x - mean) ** 2 for x in sorted_values) / n) ** 0.5,
            }

        return {
            "duration_sec": stats(durations),
            "throughput": stats(throughputs),
        }

    def get_baseline(self, test_name: str) -> Optional[Dict[str, Any]]:
        """
        Get baseline for a test.

        Args:
            test_name: Name of the test

        Returns:
            Baseline dictionary or None if not found
        """
        return self.baselines["baselines"].get(test_name)

    def compare_to_baseline(
        self,
        test_name: str,
        current_metrics: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Compare current metrics to baseline.

        Args:
            test_name: Name of the test
            current_metrics: Current metrics to compare

        Returns:
            Comparison dictionary
        """
        baseline = self.get_baseline(test_name)

        if not baseline:
            return {"error": f"No baseline found for {test_name}"}

        baseline_metrics = baseline["metrics"]
        current_perf = current_metrics.get("tier3_performance", {})

        # Compare duration
        duration_baseline = baseline_metrics.get("duration_sec", {}).get("mean", 0)
        duration_current = current_perf.get("duration_sec", 0)

        duration_diff_pct = 0
        if duration_baseline > 0:
            duration_diff_pct = ((duration_current - duration_baseline) / duration_baseline) * 100

        # Compare throughput
        throughput_baseline = baseline_metrics.get("throughput", {}).get("mean", 0)
        throughput_current = current_perf.get("throughput", 0)

        throughput_diff_pct = 0
        if throughput_baseline > 0:
            throughput_diff_pct = ((throughput_current - throughput_baseline) / throughput_baseline) * 100

        return {
            "test_name": test_name,
            "duration": {
                "baseline": duration_baseline,
                "current": duration_current,
                "diff_pct": duration_diff_pct,
                "regression": duration_diff_pct > 20,  # > 20% degradation
            },
            "throughput": {
                "baseline": throughput_baseline,
                "current": throughput_current,
                "diff_pct": throughput_diff_pct,
                "regression": throughput_diff_pct < -20,  # < -20% degradation
            },
        }

    def list_baselines(self) -> List[str]:
        """
        List all available baselines.

        Returns:
            List of test names with baselines
        """
        return list(self.baselines["baselines"].keys())


def main():
    parser = argparse.ArgumentParser(
        description="Manage load test baselines"
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # Create command
    create_parser = subparsers.add_parser('create', help='Create baseline')
    create_parser.add_argument(
        '--test-name', type=str, required=True,
        help='Name of the test'
    )
    create_parser.add_argument(
        '--results-dir', type=str,
        default=str(RESULTS_DIR),
        help='Directory containing result files'
    )
    create_parser.add_argument(
        '--sample-size', type=int, default=5,
        help='Number of runs to use for baseline'
    )

    # Update command
    update_parser = subparsers.add_parser('update', help='Update baseline')
    update_parser.add_argument(
        '--test-name', type=str, required=True,
        help='Name of the test'
    )
    update_parser.add_argument(
        '--results-dir', type=str,
        default=str(RESULTS_DIR),
        help='Directory containing result files'
    )

    # Compare command
    compare_parser = subparsers.add_parser('compare', help='Compare to baseline')
    compare_parser.add_argument(
        '--test-name', type=str, required=True,
        help='Name of the test'
    )
    compare_parser.add_argument(
        '--metrics', type=str,
        help='Current metrics as JSON string'
    )
    compare_parser.add_argument(
        '--metrics-file', type=str,
        help='File containing current metrics'
    )

    # List command
    subparsers.add_parser('list', help='List baselines')

    args = parser.parse_args()

    manager = BaselineManager()

    if args.command == 'create':
        results_dir = Path(args.results_dir)
        metrics_files = list(results_dir.glob(f"{args.test_name}.jsonl"))

        if len(metrics_files) < args.sample_size:
            print(f"Error: Need {args.sample_size} result files, found {len(metrics_files)}")
            return 1

        # Read metrics
        all_metrics = []
        for metrics_file in metrics_files[:args.sample_size]:
            with open(metrics_file) as f:
                for line in f:
                    all_metrics.append(json.loads(line))

        manager.create_baseline(args.test_name, all_metrics)
        return 0

    elif args.command == 'update':
        results_dir = Path(args.results_dir)
        metrics_files = list(results_dir.glob(f"{args.test_name}.jsonl"))

        # Read metrics
        all_metrics = []
        for metrics_file in metrics_files:
            with open(metrics_file) as f:
                for line in f:
                    all_metrics.append(json.loads(line))

        manager.create_baseline(args.test_name, all_metrics)
        return 0

    elif args.command == 'compare':
        current_metrics = {}

        if args.metrics:
            current_metrics = json.loads(args.metrics)
        elif args.metrics_file:
            with open(args.metrics_file) as f:
                current_metrics = json.load(f)
        else:
            print("Error: Must provide --metrics or --metrics-file")
            return 1

        comparison = manager.compare_to_baseline(args.test_name, current_metrics)
        print(json.dumps(comparison, indent=2))

        # Check for regression
        if comparison.get("duration", {}).get("regression") or comparison.get("throughput", {}).get("regression"):
            print("\nRegression detected!")
            return 1

        return 0

    elif args.command == 'list':
        baselines = manager.list_baselines()
        print(f"Available baselines ({len(baselines)}):")
        for name in sorted(baselines):
            print(f"  - {name}")
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == '__main__':
    sys.exit(main())
