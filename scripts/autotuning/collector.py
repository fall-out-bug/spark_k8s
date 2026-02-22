"""Metrics collector for Spark autotuning.

Collects metrics from Prometheus API for analysis and tuning recommendations.

Usage:
    python -m autotuning.collector --app-id app-123 --output metrics.json
"""

from __future__ import annotations

import argparse
import json
import logging
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import requests
import yaml

logger = logging.getLogger(__name__)

# Default config path relative to this module
DEFAULT_CONFIG_PATH = Path(__file__).parent / "config" / "metrics.yaml"


@dataclass
class MetricsResult:
    """Result of metrics collection."""

    app_id: str
    timestamp: datetime
    metrics: dict[str, float]
    duration_seconds: float = 0.0
    raw_response: dict[str, Any] = field(default_factory=dict)

    def to_json(self) -> str:
        """Serialize result to JSON string."""
        return json.dumps(self.to_dict(), indent=2, default=str)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "app_id": self.app_id,
            "timestamp": self.timestamp.isoformat(),
            "metrics": self.metrics,
            "duration_seconds": self.duration_seconds,
            "collected_at": datetime.now().isoformat(),
        }

    def save(self, path: Path) -> None:
        """Save result to file."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.to_json())
        logger.info(f"Saved metrics to {path}")


def load_metrics_config(config_path: Path | None = None) -> dict[str, Any]:
    """Load metrics configuration from YAML file.

    Args:
        config_path: Path to config file. Uses default if None.

    Returns:
        Configuration dictionary.

    Raises:
        FileNotFoundError: If config file doesn't exist.
    """
    if config_path is None:
        config_path = DEFAULT_CONFIG_PATH

    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path) as f:
        return yaml.safe_load(f)


class MetricsCollector:
    """Collects Spark metrics from Prometheus.

    Attributes:
        prometheus_url: Base URL for Prometheus API.
        timeout: Request timeout in seconds.
        retry_count: Number of retries on failure.
        retry_delay: Delay between retries in seconds.
    """

    def __init__(
        self,
        prometheus_url: str = "http://localhost:9090",
        timeout: int = 30,
        retry_count: int = 3,
        retry_delay: float = 1.0,
        config_path: Path | None = None,
    ):
        """Initialize collector.

        Args:
            prometheus_url: Prometheus API URL.
            timeout: Request timeout in seconds.
            retry_count: Number of retries on failure.
            retry_delay: Delay between retries in seconds.
            config_path: Path to metrics config file.
        """
        self.prometheus_url = prometheus_url.rstrip("/")
        self.timeout = timeout
        self.retry_count = retry_count
        self.retry_delay = retry_delay
        self._config = None
        self._config_path = config_path

    @property
    def config(self) -> dict[str, Any]:
        """Lazy load metrics configuration."""
        if self._config is None:
            self._config = load_metrics_config(self._config_path)
        return self._config

    def get_config_path(self) -> Path:
        """Get the config file path being used."""
        return self._config_path or DEFAULT_CONFIG_PATH

    def fetch_metric(
        self,
        query: str,
        aggregation: str = "value",
        start_time: datetime | None = None,
        end_time: datetime | None = None,
        step: str = "15s",
    ) -> float:
        """Fetch a single metric from Prometheus.

        Args:
            query: PromQL query string.
            aggregation: Aggregation type (sum, avg, max, min, value).
            start_time: Start time for range query.
            end_time: End time for range query.
            step: Query step for range queries.

        Returns:
            Aggregated metric value.

        Raises:
            ValueError: If Prometheus query fails.
        """
        url = f"{self.prometheus_url}/api/v1/query"

        if start_time and end_time:
            # Range query
            url = f"{self.prometheus_url}/api/v1/query_range"
            params = {
                "query": query,
                "start": int(start_time.timestamp()),
                "end": int(end_time.timestamp()),
                "step": step,
            }
        else:
            # Instant query
            params = {"query": query}

        last_error = None
        for attempt in range(self.retry_count):
            try:
                response = requests.get(url, params=params, timeout=self.timeout)
                response.raise_for_status()
                data = response.json()

                if data.get("status") != "success":
                    raise ValueError(
                        f"Prometheus query failed: {data.get('error', 'Unknown error')}"
                    )

                return self._aggregate_result(data["data"]["result"], aggregation)

            except Exception as e:
                last_error = e
                if attempt < self.retry_count - 1:
                    logger.warning(
                        f"Attempt {attempt + 1} failed: {e}. Retrying in {self.retry_delay}s..."
                    )
                    time.sleep(self.retry_delay)

        raise ValueError(f"Failed to fetch metric after {self.retry_count} attempts: {last_error}")

    def _aggregate_result(
        self, results: list[dict[str, Any]], aggregation: str
    ) -> float:
        """Aggregate Prometheus query results.

        Args:
            results: List of result objects from Prometheus.
            aggregation: Aggregation type (sum, avg, max, min, value).

        Returns:
            Aggregated value.
        """
        if not results:
            return 0.0

        # Extract values from results
        values = []
        for result in results:
            value = result.get("value", [0, "0"])[1]
            try:
                values.append(float(value))
            except (ValueError, TypeError):
                continue

        if not values:
            return 0.0

        if aggregation == "sum":
            return sum(values)
        elif aggregation == "avg":
            return sum(values) / len(values)
        elif aggregation == "max":
            return max(values)
        elif aggregation == "min":
            return min(values)
        else:  # "value" - return first value
            return values[0]

    def collect(
        self,
        app_id: str,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
    ) -> MetricsResult:
        """Collect all configured metrics.

        Args:
            app_id: Spark application ID.
            start_time: Start time for metrics collection.
            end_time: End time for metrics collection.

        Returns:
            MetricsResult with collected metrics.
        """
        logger.info(f"Collecting metrics for app_id={app_id}")

        if end_time is None:
            end_time = datetime.now()
        if start_time is None:
            start_time = end_time - timedelta(hours=1)

        metrics = {}
        errors = []
        collection_start = time.time()

        queries = self.config.get("prometheus_queries", {})

        for metric_name, metric_config in queries.items():
            query = metric_config.get("query", "")
            aggregation = metric_config.get("aggregation", "value")

            try:
                value = self.fetch_metric(
                    query=query,
                    aggregation=aggregation,
                    start_time=start_time,
                    end_time=end_time,
                )
                metrics[metric_name] = value
                logger.debug(f"Collected {metric_name}: {value}")
            except Exception as e:
                logger.warning(f"Failed to collect {metric_name}: {e}")
                errors.append((metric_name, str(e)))
                metrics[metric_name] = 0.0

        # Calculate derived metrics
        derived = self.calculate_derived_metrics(metrics)
        metrics.update(derived)

        collection_duration = time.time() - collection_start

        result = MetricsResult(
            app_id=app_id,
            timestamp=end_time,
            metrics=metrics,
            duration_seconds=collection_duration,
            raw_response={"errors": errors, "queries_count": len(queries)},
        )

        logger.info(
            f"Collected {len(metrics)} metrics in {collection_duration:.2f}s "
            f"({len(errors)} errors)"
        )

        return result

    def calculate_derived_metrics(
        self, metrics: dict[str, float]
    ) -> dict[str, float | None]:
        """Calculate derived metrics from raw metrics.

        Args:
            metrics: Raw metrics dictionary.

        Returns:
            Dictionary of derived metric values.
        """
        derived = {}
        derived_config = self.config.get("derived_metrics", {})

        for metric_name, config in derived_config.items():
            _ = config.get("formula", "")  # Reserved for future formula parser

            try:
                # Parse formula and calculate
                if metric_name == "task_skew_ratio":
                    p99 = metrics.get("task_duration_p99", 0)
                    p50 = metrics.get("task_duration_p50", 0)
                    if p50 > 0:
                        derived[metric_name] = p99 / p50
                    else:
                        derived[metric_name] = None

                elif metric_name == "shuffle_ratio":
                    read = metrics.get("shuffle_read", 0)
                    write = metrics.get("shuffle_write", 0)
                    if write > 0:
                        derived[metric_name] = read / write
                    else:
                        derived[metric_name] = None

                elif metric_name == "gc_ratio":
                    gc_time = metrics.get("gc_time", 0)
                    task_avg = metrics.get("task_duration_avg", 0)
                    executor_count = metrics.get("executor_count", 1) or 1
                    if task_avg > 0:
                        # Approximate: gc_time / total_task_time
                        derived[metric_name] = gc_time / (task_avg * executor_count)
                    else:
                        derived[metric_name] = None

                elif metric_name == "cpu_efficiency":
                    cpu_util = metrics.get("cpu_utilization", 0)
                    executor_count = metrics.get("executor_count", 1) or 1
                    derived[metric_name] = cpu_util / executor_count

            except (ZeroDivisionError, TypeError):
                derived[metric_name] = None

        return derived


def collect_metrics(
    app_id: str,
    prometheus_url: str = "http://localhost:9090",
    output_path: Path | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    config_path: Path | None = None,
) -> MetricsResult:
    """Collect metrics for a Spark application.

    Convenience function for CLI and programmatic use.

    Args:
        app_id: Spark application ID.
        prometheus_url: Prometheus API URL.
        output_path: Optional path to save results.
        start_time: Start time for metrics collection.
        end_time: End time for metrics collection.
        config_path: Path to metrics config file.

    Returns:
        MetricsResult with collected metrics.
    """
    collector = MetricsCollector(
        prometheus_url=prometheus_url,
        config_path=config_path,
    )
    result = collector.collect(
        app_id=app_id,
        start_time=start_time,
        end_time=end_time,
    )

    if output_path:
        result.save(output_path)

    return result


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Collect Spark metrics from Prometheus for autotuning"
    )
    parser.add_argument(
        "--app-id",
        required=True,
        help="Spark application ID to collect metrics for",
    )
    parser.add_argument(
        "--prometheus-url",
        default="http://localhost:9090",
        help="Prometheus API URL (default: http://localhost:9090)",
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        help="Output file path for metrics JSON",
    )
    parser.add_argument(
        "--start-time",
        help="Start time for metrics (ISO format, default: 1 hour ago)",
    )
    parser.add_argument(
        "--end-time",
        help="End time for metrics (ISO format, default: now)",
    )
    parser.add_argument(
        "--config",
        type=Path,
        help="Path to metrics config YAML",
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

    # Parse times
    start_time = None
    end_time = None
    if args.start_time:
        start_time = datetime.fromisoformat(args.start_time)
    if args.end_time:
        end_time = datetime.fromisoformat(args.end_time)

    # Collect metrics
    result = collect_metrics(
        app_id=args.app_id,
        prometheus_url=args.prometheus_url,
        output_path=args.output,
        start_time=start_time,
        end_time=end_time,
        config_path=args.config,
    )

    # Print summary
    print(f"\nCollected {len(result.metrics)} metrics for {args.app_id}")
    print(f"Duration: {result.duration_seconds:.2f}s")
    print(f"Timestamp: {result.timestamp.isoformat()}")

    if args.output:
        print(f"Saved to: {args.output}")
    else:
        print("\nMetrics:")
        for name, value in sorted(result.metrics.items()):
            if value is not None:
                print(f"  {name}: {value}")


if __name__ == "__main__":
    main()
