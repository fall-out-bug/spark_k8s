"""Tests for autotuning metrics collector."""

import json
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

# Will be implemented in collector.py
from autotuning.collector import (
    MetricsCollector,
    MetricsResult,
    collect_metrics,
    load_metrics_config,
)


class TestLoadMetricsConfig:
    """Test metrics configuration loading."""

    def test_load_valid_config(self, tmp_path: Path):
        """Test loading valid metrics config."""
        config_path = tmp_path / "metrics.yaml"
        config_path.write_text("""
prometheus_queries:
  gc_time:
    query: 'rate(jvm_gc_time_seconds_sum[5m])'
    aggregation: sum
""")
        config = load_metrics_config(config_path)
        assert "prometheus_queries" in config
        assert "gc_time" in config["prometheus_queries"]

    def test_load_missing_config_raises(self, tmp_path: Path):
        """Test loading missing config raises error."""
        config_path = tmp_path / "nonexistent.yaml"
        with pytest.raises(FileNotFoundError):
            load_metrics_config(config_path)


class TestMetricsResult:
    """Test MetricsResult dataclass."""

    def test_create_result(self):
        """Test creating MetricsResult."""
        result = MetricsResult(
            app_id="app-123",
            timestamp=datetime(2026, 2, 22, 12, 0, 0),
            metrics={
                "gc_time": 0.05,
                "memory_spill": 1000000,
                "task_duration_avg": 2.5,
            },
            duration_seconds=45.0,
            raw_response={"status": "success"},
        )
        assert result.app_id == "app-123"
        assert result.metrics["gc_time"] == 0.05

    def test_to_json(self):
        """Test serializing to JSON."""
        result = MetricsResult(
            app_id="app-123",
            timestamp=datetime(2026, 2, 22, 12, 0, 0),
            metrics={"gc_time": 0.05},
            duration_seconds=45.0,
            raw_response={},
        )
        json_str = result.to_json()
        data = json.loads(json_str)
        assert data["app_id"] == "app-123"
        assert data["metrics"]["gc_time"] == 0.05

    def test_save_to_file(self, tmp_path: Path):
        """Test saving result to file."""
        result = MetricsResult(
            app_id="app-123",
            timestamp=datetime(2026, 2, 22, 12, 0, 0),
            metrics={"gc_time": 0.05},
            duration_seconds=45.0,
            raw_response={},
        )
        output_path = tmp_path / "metrics.json"
        result.save(output_path)
        assert output_path.exists()
        data = json.loads(output_path.read_text())
        assert data["app_id"] == "app-123"


class TestMetricsCollector:
    """Test MetricsCollector class."""

    @pytest.fixture
    def mock_prometheus_response(self):
        """Mock Prometheus API response."""
        return {
            "status": "success",
            "data": {
                "resultType": "vector",
                "result": [
                    {
                        "metric": {"job": "spark-connect"},
                        "value": [1708600800, "0.05"],
                    }
                ],
            },
        }

    @pytest.fixture
    def collector(self):
        """Create collector with mocked Prometheus."""
        return MetricsCollector(
            prometheus_url="http://prometheus:9090",
            timeout=10,
        )

    def test_collector_init(self, collector):
        """Test collector initialization."""
        assert collector.prometheus_url == "http://prometheus:9090"
        assert collector.timeout == 10

    def test_collector_default_timeout(self):
        """Test collector with default timeout."""
        collector = MetricsCollector("http://prometheus:9090")
        assert collector.timeout == 30

    @patch("autotuning.collector.requests.get")
    def test_fetch_metric(self, mock_get, collector, mock_prometheus_response):
        """Test fetching single metric."""
        mock_response = Mock()
        mock_response.json.return_value = mock_prometheus_response
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        value = collector.fetch_metric('rate(jvm_gc_time_seconds_sum[5m])')

        assert value == 0.05
        mock_get.assert_called_once()

    @patch("autotuning.collector.requests.get")
    def test_fetch_metric_with_aggregation(self, mock_get, collector):
        """Test fetching metric with sum aggregation."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "success",
            "data": {
                "resultType": "vector",
                "result": [
                    {"metric": {}, "value": [1708600800, "100"]},
                    {"metric": {}, "value": [1708600800, "200"]},
                ],
            },
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        value = collector.fetch_metric(
            'spark_executor_memory_bytes_spilled_total',
            aggregation="sum"
        )

        assert value == 300.0  # 100 + 200

    @patch("autotuning.collector.requests.get")
    def test_fetch_metric_empty_result(self, mock_get, collector):
        """Test fetching metric with no results."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "success",
            "data": {"resultType": "vector", "result": []},
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        value = collector.fetch_metric('nonexistent_metric')

        assert value == 0.0

    @patch("autotuning.collector.requests.get")
    def test_fetch_metric_error(self, mock_get, collector):
        """Test fetching metric with error response."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "error",
            "error": "query exhausted",
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        with pytest.raises(ValueError, match="Prometheus query failed"):
            collector.fetch_metric('bad_query')

    @patch("autotuning.collector.requests.get")
    def test_collect_all_metrics(self, mock_get, collector, mock_prometheus_response):
        """Test collecting all configured metrics."""
        mock_response = Mock()
        mock_response.json.return_value = mock_prometheus_response
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        result = collector.collect(app_id="app-123")

        assert result.app_id == "app-123"
        assert "gc_time" in result.metrics
        assert result.timestamp is not None

    @patch("autotuning.collector.requests.get")
    def test_collect_with_time_range(self, mock_get, collector, mock_prometheus_response):
        """Test collecting metrics for time range."""
        mock_response = Mock()
        mock_response.json.return_value = mock_prometheus_response
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        start = datetime(2026, 2, 22, 10, 0, 0)
        end = datetime(2026, 2, 22, 12, 0, 0)

        result = collector.collect(
            app_id="app-123",
            start_time=start,
            end_time=end,
        )

        assert result.app_id == "app-123"

    @patch("autotuning.collector.requests.get")
    def test_collect_retry_on_failure(self, mock_get, collector):
        """Test retry logic on transient failures."""
        # First call fails, second succeeds
        mock_response_success = Mock()
        mock_response_success.json.return_value = {
            "status": "success",
            "data": {"resultType": "vector", "result": [{"value": [0, "1.0"]}]},
        }
        mock_response_success.raise_for_status = Mock()

        mock_get.side_effect = [
            Exception("Connection error"),
            mock_response_success,
        ]

        value = collector.fetch_metric('test_metric')

        assert value == 1.0
        assert mock_get.call_count == 2

    def test_get_config_path(self, collector):
        """Test getting default config path."""
        path = collector.get_config_path()
        assert path.exists()
        assert path.name == "metrics.yaml"


class TestCollectMetricsCLI:
    """Test collect_metrics CLI function."""

    @patch("autotuning.collector.MetricsCollector")
    def test_collect_metrics_default(self, mock_collector_class):
        """Test collect_metrics with defaults."""
        mock_collector = Mock()
        mock_result = Mock()
        mock_result.save = Mock()
        mock_collector.collect.return_value = mock_result
        mock_collector_class.return_value = mock_collector

        collect_metrics(app_id="app-123")

        mock_collector.collect.assert_called_once_with(
            app_id="app-123",
            start_time=None,
            end_time=None,
        )

    @patch("autotuning.collector.MetricsCollector")
    def test_collect_metrics_with_output(self, mock_collector_class, tmp_path: Path):
        """Test collect_metrics with output file."""
        mock_collector = Mock()
        mock_result = Mock()
        mock_result.save = Mock()
        mock_collector.collect.return_value = mock_result
        mock_collector_class.return_value = mock_collector

        output_path = tmp_path / "metrics.json"
        collect_metrics(app_id="app-123", output_path=output_path)

        mock_result.save.assert_called_once_with(output_path)


class TestDerivedMetrics:
    """Test derived metrics calculation."""

    @pytest.fixture
    def collector(self):
        """Create collector for derived metrics tests."""
        return MetricsCollector("http://prometheus:9090")

    def test_calculate_gc_ratio(self, collector):
        """Test GC ratio calculation."""
        metrics = {
            "gc_time": 5.0,
            "task_duration_avg": 2.0,
        }
        # This would need task_count, so we test the formula exists
        derived = collector.calculate_derived_metrics(metrics)
        # gc_ratio = gc_time / (task_duration_avg * task_count)
        # Without task_count, should skip or use default
        assert "gc_ratio" in derived or derived == {}

    def test_calculate_task_skew_ratio(self, collector):
        """Test task skew ratio calculation."""
        metrics = {
            "task_duration_p99": 10.0,
            "task_duration_p50": 2.0,
        }
        derived = collector.calculate_derived_metrics(metrics)
        assert derived.get("task_skew_ratio") == 5.0  # 10 / 2

    def test_calculate_shuffle_ratio(self, collector):
        """Test shuffle ratio calculation."""
        metrics = {
            "shuffle_read": 1000000,
            "shuffle_write": 500000,
        }
        derived = collector.calculate_derived_metrics(metrics)
        assert derived.get("shuffle_ratio") == 2.0  # 1000000 / 500000

    def test_skip_calculation_with_missing_values(self, collector):
        """Test skipping calculation when values are missing."""
        metrics = {
            "task_duration_p99": 10.0,
            # Missing task_duration_p50
        }
        derived = collector.calculate_derived_metrics(metrics)
        # Should not raise, should skip
        assert "task_skew_ratio" not in derived or derived.get("task_skew_ratio") is None

    def test_handle_division_by_zero(self, collector):
        """Test handling division by zero in derived metrics."""
        metrics = {
            "shuffle_read": 1000000,
            "shuffle_write": 0,  # Division by zero
        }
        derived = collector.calculate_derived_metrics(metrics)
        # Should handle gracefully
        assert derived.get("shuffle_ratio") is None or derived.get("shuffle_ratio") == 0


class TestIntegration:
    """Integration tests (require Prometheus)."""

    @pytest.mark.integration
    def test_real_prometheus_connection(self):
        """Test connection to real Prometheus (skip in CI)."""
        pytest.skip("Integration test - requires running Prometheus")

    @pytest.mark.integration
    def test_real_metric_collection(self):
        """Test collecting real metrics from Prometheus."""
        pytest.skip("Integration test - requires running Prometheus")
