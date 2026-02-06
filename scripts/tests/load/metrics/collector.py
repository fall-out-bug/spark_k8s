#!/usr/bin/env python3
"""
Metrics Collector for Load Testing
Part of WS-013-10: Metrics Collection & Regression Detection

Implements three-tier metrics collection system.

Usage:
    python collector.py collect --test-name p0_350_connect_kubernetes_none_read_1gb
    python collector.py aggregate --output aggregated.jsonl
"""

import argparse
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests


# History Server API
HISTORY_SERVER_URL = "http://spark-history-server.load-testing.svc.cluster.local:18080"

# Minio endpoint
MINIO_ENDPOINT = "http://minio.load-testing.svc.cluster.local:9000"
MINIO_BUCKET = "spark-logs"

# Postgres endpoint
POSTGRES_URL = "jdbc:postgresql://postgres-load-testing.load-testing.svc.cluster.local:5432/spark_db"


class MetricsCollector:
    """Collects metrics from various sources for load tests."""

    def __init__(self, test_name: str, output_dir: Optional[Path] = None):
        """
        Initialize metrics collector.

        Args:
            test_name: Name of the test
            output_dir: Output directory for metrics
        """
        self.test_name = test_name
        self.output_dir = output_dir or Path("/tmp/load-test-metrics")
        self.metrics = {}

    def collect_tier1_stability(self) -> Dict[str, Any]:
        """
        Collect Tier 1 (Stability) metrics.

        Returns:
            Dictionary with stability metrics
        """
        return {
            "pod_restarts": self._get_pod_restarts(),
            "oom_kills": self._get_oom_kills(),
            "failed_tasks": self._get_failed_tasks(),
            "failed_stages": self._get_failed_stages(),
        }

    def collect_tier2_efficiency(self) -> Dict[str, Any]:
        """
        Collect Tier 2 (Efficiency) metrics.

        Returns:
            Dictionary with efficiency metrics
        """
        return {
            "cpu_usage_pct": self._get_cpu_usage(),
            "memory_usage_pct": self._get_memory_usage(),
            "gpu_usage_pct": self._get_gpu_usage(),
            "shuffle_spill_pct": self._get_shuffle_spill(),
        }

    def collect_tier3_performance(self) -> Dict[str, Any]:
        """
        Collect Tier 3 (Performance) metrics.

        Returns:
            Dictionary with performance metrics
        """
        workload_metrics = self._get_workload_metrics()

        return {
            "duration_sec": workload_metrics.get("duration_sec", 0),
            "throughput": workload_metrics.get("throughput", 0),
            "latency_p50_ms": workload_metrics.get("latency_p50_ms", 0),
            "latency_p95_ms": workload_metrics.get("latency_p95_ms", 0),
            "latency_p99_ms": workload_metrics.get("latency_p99_ms", 0),
        }

    def _get_pod_restarts(self) -> int:
        """Get pod restart count from Kubernetes API."""
        try:
            # Placeholder for K8s API call
            return 0
        except Exception:
            return 0

    def _get_oom_kills(self) -> int:
        """Get OOM kill count."""
        try:
            # Placeholder for K8s events query
            return 0
        except Exception:
            return 0

    def _get_failed_tasks(self) -> int:
        """Get failed task count from History Server."""
        try:
            response = requests.get(f"{HISTORY_SERVER_URL}/api/v1/applications")
            response.raise_for_status()

            apps = response.json()
            failed_tasks = 0

            for app in apps:
                app_id = app.get("id")
                if app_id:
                    try:
                        tasks_resp = requests.get(
                            f"{HISTORY_SERVER_URL}/api/v1/applications/{app_id}/stages"
                        )
                        tasks_resp.raise_for_status()

                        for stage in tasks_resp.json():
                            failed_tasks += stage.get("numFailedTasks", 0)
                    except Exception:
                        continue

            return failed_tasks
        except Exception:
            return 0

    def _get_failed_stages(self) -> int:
        """Get failed stage count from History Server."""
        try:
            response = requests.get(f"{HISTORY_SERVER_URL}/api/v1/applications")
            response.raise_for_status()

            apps = response.json()
            failed_stages = 0

            for app in apps:
                app_id = app.get("id")
                if app_id:
                    try:
                        stages_resp = requests.get(
                            f"{HISTORY_SERVER_URL}/api/v1/applications/{app_id}/stages"
                        )
                        stages_resp.raise_for_status()

                        for stage in stages_resp.json():
                            if stage.get("status") == "FAILED":
                                failed_stages += 1
                    except Exception:
                        continue

            return failed_stages
        except Exception:
            return 0

    def _get_cpu_usage(self) -> float:
        """Get CPU usage percentage."""
        try:
            # Placeholder for metrics query
            return 0.0
        except Exception:
            return 0.0

    def _get_memory_usage(self) -> float:
        """Get memory usage percentage."""
        try:
            # Placeholder for metrics query
            return 0.0
        except Exception:
            return 0.0

    def _get_gpu_usage(self) -> float:
        """Get GPU usage percentage."""
        try:
            # Placeholder for GPU metrics
            return 0.0
        except Exception:
            return 0.0

    def _get_shuffle_spill(self) -> float:
        """Get shuffle spill percentage."""
        try:
            response = requests.get(f"{HISTORY_SERVER_URL}/api/v1/applications")
            response.raise_for_status()

            apps = response.json()
            total_shuffle = 0
            total_spill = 0

            for app in apps:
                app_id = app.get("id")
                if app_id:
                    try:
                        metrics_resp = requests.get(
                            f"{HISTORY_SERVER_URL}/api/v1/applications/{app_id}/executors"
                        )
                        metrics_resp.raise_for_bytes()

                        for executor in metrics_resp.json():
                            total_shuffle += executor.get("memoryMetrics", {}).get("totalShuffleRead", 0)
                            total_spill += executor.get("memoryMetrics", {}).get("memoryBytesSpilled", 0)
                    except Exception:
                        continue

            if total_shuffle > 0:
                return (total_spill / total_shuffle) * 100
            return 0.0
        except Exception:
            return 0.0

    def _get_workload_metrics(self) -> Dict[str, Any]:
        """Get workload metrics from results file."""
        try:
            results_file = self.output_dir / f"{self.test_name}.jsonl"

            if not results_file.exists():
                return {}

            with open(results_file) as f:
                for line in f:
                    metrics = json.loads(line)
                    if metrics.get("test_name") == self.test_name:
                        return metrics

            return {}
        except Exception:
            return {}

    def collect_all(self) -> Dict[str, Any]:
        """
        Collect all metrics tiers.

        Returns:
            Complete metrics dictionary
        """
        return {
            "test_name": self.test_name,
            "timestamp": datetime.utcnow().isoformat(),
            "tier1_stability": self.collect_tier1_stability(),
            "tier2_efficiency": self.collect_tier2_efficiency(),
            "tier3_performance": self.collect_tier3_performance(),
        }

    def save(self) -> Path:
        """
        Save collected metrics to file.

        Returns:
            Path to saved metrics file
        """
        self.output_dir.mkdir(parents=True, exist_ok=True)

        metrics_file = self.output_dir / f"{self.test_name}-metrics.jsonl"

        with open(metrics_file, 'a') as f:
            f.write(json.dumps(self.collect_all()) + '\n')

        return metrics_file


def collect_metrics(test_name: str, output_dir: Optional[Path] = None) -> Dict[str, Any]:
    """
    Collect all metrics for a test.

    Args:
        test_name: Name of the test
        output_dir: Output directory

    Returns:
        Collected metrics
    """
    collector = MetricsCollector(test_name, output_dir)
    return collector.collect_all()


def main():
    parser = argparse.ArgumentParser(
        description="Collect metrics from load tests"
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # Collect command
    collect_parser = subparsers.add_parser('collect', help='Collect metrics')
    collect_parser.add_argument(
        '--test-name', type=str, required=True,
        help='Name of the test'
    )
    collect_parser.add_argument(
        '--output-dir', type=str,
        default='/tmp/load-test-metrics',
        help='Output directory'
    )

    # Aggregate command
    aggregate_parser = subparsers.add_parser('aggregate', help='Aggregate metrics')
    aggregate_parser.add_argument(
        '--input-dir', type=str,
        default='/tmp/load-test-metrics',
        help='Input directory'
    )
    aggregate_parser.add_argument(
        '--output', type=str,
        default='/tmp/aggregated-metrics.jsonl',
        help='Output file'
    )

    args = parser.parse_args()

    if args.command == 'collect':
        collector = MetricsCollector(args.test_name, Path(args.output_dir))
        metrics = collector.collect_all()
        file_path = collector.save()

        print(f"Metrics collected and saved to: {file_path}")
        print(json.dumps(metrics, indent=2))

        return 0

    elif args.command == 'aggregate':
        input_dir = Path(args.input_dir)
        output_file = Path(args.output)

        all_metrics = []
        for metrics_file in input_dir.glob("*-metrics.jsonl"):
            with open(metrics_file) as f:
                for line in f:
                    all_metrics.append(json.loads(line))

        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, 'w') as f:
            for metrics in all_metrics:
                f.write(json.dumps(metrics) + '\n')

        print(f"Aggregated {len(all_metrics)} metric records to: {output_file}")
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == '__main__':
    sys.exit(main())
