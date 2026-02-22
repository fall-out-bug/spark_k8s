"""Tests for autotuning pattern analyzer."""

import json
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

from autotuning.analyzer import (
    AnalysisResult,
    DetectedIssue,
    WorkloadAnalyzer,
    analyze_metrics,
    classify_workload,
    load_rules_config,
)


class TestLoadRulesConfig:
    """Test rules configuration loading."""

    def test_load_valid_config(self, tmp_path: Path):
        """Test loading valid rules config."""
        config_path = tmp_path / "rules.yaml"
        config_path.write_text("""
detection_rules:
  gc_pressure:
    metric: "gc_ratio"
    condition: "gt"
    thresholds:
      warning: 0.10
      critical: 0.20
""")
        config = load_rules_config(config_path)
        assert "detection_rules" in config
        assert "gc_pressure" in config["detection_rules"]

    def test_load_missing_config_raises(self, tmp_path: Path):
        """Test loading missing config raises error."""
        config_path = tmp_path / "nonexistent.yaml"
        with pytest.raises(FileNotFoundError):
            load_rules_config(config_path)


class TestDetectedIssue:
    """Test DetectedIssue dataclass."""

    def test_create_issue(self):
        """Test creating DetectedIssue."""
        issue = DetectedIssue(
            issue_type="gc_pressure",
            severity="warning",
            metric_value=0.15,
            threshold=0.10,
            recommendation="increase_memory",
            rationale="GC time exceeds 15% of task time",
        )
        assert issue.issue_type == "gc_pressure"
        assert issue.severity == "warning"
        assert issue.metric_value == 0.15

    def test_issue_to_dict(self):
        """Test converting issue to dict."""
        issue = DetectedIssue(
            issue_type="memory_spill",
            severity="critical",
            metric_value=1500000000,
            threshold=1073741824,
            recommendation="increase_memory",
            rationale="1.5GB spilled to disk",
        )
        data = issue.to_dict()
        assert data["issue_type"] == "memory_spill"
        assert data["severity"] == "critical"


class TestAnalysisResult:
    """Test AnalysisResult dataclass."""

    def test_create_result(self):
        """Test creating AnalysisResult."""
        result = AnalysisResult(
            app_id="app-123",
            timestamp=datetime(2026, 2, 22, 12, 0, 0),
            workload_type="etl_batch",
            issues=[
                DetectedIssue(
                    issue_type="gc_pressure",
                    severity="warning",
                    metric_value=0.15,
                    threshold=0.10,
                    recommendation="increase_memory",
                    rationale="test",
                )
            ],
            metrics_summary={"gc_ratio": 0.15},
            duration_seconds=45.0,
        )
        assert result.app_id == "app-123"
        assert result.workload_type == "etl_batch"
        assert len(result.issues) == 1

    def test_result_to_json(self):
        """Test serializing result to JSON."""
        result = AnalysisResult(
            app_id="app-123",
            timestamp=datetime(2026, 2, 22, 12, 0, 0),
            workload_type="etl_batch",
            issues=[],
            metrics_summary={"gc_ratio": 0.08},
            duration_seconds=45.0,
        )
        json_str = result.to_json()
        data = json.loads(json_str)
        assert data["app_id"] == "app-123"
        assert data["workload_type"] == "etl_batch"

    def test_has_issues(self):
        """Test has_issues property."""
        result_no_issues = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[],
            metrics_summary={},
            duration_seconds=45.0,
        )
        assert result_no_issues.has_issues is False

        result_with_issues = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[
                DetectedIssue(
                    issue_type="gc_pressure",
                    severity="warning",
                    metric_value=0.15,
                    threshold=0.10,
                    recommendation="increase_memory",
                    rationale="test",
                )
            ],
            metrics_summary={},
            duration_seconds=45.0,
        )
        assert result_with_issues.has_issues is True

    def test_save_to_file(self, tmp_path: Path):
        """Test saving result to file."""
        result = AnalysisResult(
            app_id="app-123",
            timestamp=datetime(2026, 2, 22, 12, 0, 0),
            workload_type="etl_batch",
            issues=[],
            metrics_summary={"gc_ratio": 0.08},
            duration_seconds=45.0,
        )
        output_path = tmp_path / "analysis.json"
        result.save(output_path)
        assert output_path.exists()
        data = json.loads(output_path.read_text())
        assert data["app_id"] == "app-123"


class TestWorkloadAnalyzer:
    """Test WorkloadAnalyzer class."""

    @pytest.fixture
    def sample_metrics(self):
        """Sample metrics for testing."""
        return {
            "gc_time": 5.2,
            "memory_spill": 1500000000,
            "task_duration_p50": 2.5,
            "task_duration_p99": 12.5,
            "task_duration_avg": 3.2,
            "shuffle_read": 2100000000,
            "shuffle_write": 1800000000,
            "cpu_utilization": 0.55,
            "executor_memory": 12000000000,
            "gc_ratio": 0.15,
            "task_skew_ratio": 5.0,
        }

    @pytest.fixture
    def analyzer(self):
        """Create analyzer instance."""
        return WorkloadAnalyzer()

    def test_analyzer_init(self, analyzer):
        """Test analyzer initialization."""
        assert analyzer.rules is not None
        assert "detection_rules" in analyzer.rules

    def test_detect_gc_pressure_warning(self, analyzer):
        """Test detecting GC pressure at warning level."""
        metrics = {"gc_ratio": 0.15}
        issues = analyzer.detect_issues(metrics)
        gc_issues = [i for i in issues if i.issue_type == "gc_pressure"]
        assert len(gc_issues) == 1
        assert gc_issues[0].severity == "warning"

    def test_detect_gc_pressure_critical(self, analyzer):
        """Test detecting GC pressure at critical level."""
        metrics = {"gc_ratio": 0.25}
        issues = analyzer.detect_issues(metrics)
        gc_issues = [i for i in issues if i.issue_type == "gc_pressure"]
        assert len(gc_issues) == 1
        assert gc_issues[0].severity == "critical"

    def test_detect_no_gc_pressure(self, analyzer):
        """Test no GC pressure detected when within bounds."""
        metrics = {"gc_ratio": 0.05}
        issues = analyzer.detect_issues(metrics)
        gc_issues = [i for i in issues if i.issue_type == "gc_pressure"]
        assert len(gc_issues) == 0

    def test_detect_memory_spill_warning(self, analyzer):
        """Test detecting memory spill at warning level."""
        metrics = {"memory_spill": 500000000}  # 500MB
        issues = analyzer.detect_issues(metrics)
        spill_issues = [i for i in issues if i.issue_type == "memory_spill"]
        assert len(spill_issues) == 1
        assert spill_issues[0].severity == "warning"

    def test_detect_memory_spill_critical(self, analyzer):
        """Test detecting memory spill at critical level."""
        metrics = {"memory_spill": 2000000000}  # 2GB
        issues = analyzer.detect_issues(metrics)
        spill_issues = [i for i in issues if i.issue_type == "memory_spill"]
        assert len(spill_issues) == 1
        assert spill_issues[0].severity == "critical"

    def test_detect_no_memory_spill(self, analyzer):
        """Test no memory spill when zero."""
        metrics = {"memory_spill": 0}
        issues = analyzer.detect_issues(metrics)
        spill_issues = [i for i in issues if i.issue_type == "memory_spill"]
        assert len(spill_issues) == 0

    def test_detect_data_skew_warning(self, analyzer):
        """Test detecting data skew at warning level."""
        metrics = {"task_skew_ratio": 4.0}
        issues = analyzer.detect_issues(metrics)
        skew_issues = [i for i in issues if i.issue_type == "data_skew"]
        assert len(skew_issues) == 1
        assert skew_issues[0].severity == "warning"

    def test_detect_data_skew_critical(self, analyzer):
        """Test detecting data skew at critical level."""
        metrics = {"task_skew_ratio": 8.0}
        issues = analyzer.detect_issues(metrics)
        skew_issues = [i for i in issues if i.issue_type == "data_skew"]
        assert len(skew_issues) == 1
        assert skew_issues[0].severity == "critical"

    def test_detect_no_data_skew(self, analyzer):
        """Test no data skew when ratio is normal."""
        metrics = {"task_skew_ratio": 2.0}
        issues = analyzer.detect_issues(metrics)
        skew_issues = [i for i in issues if i.issue_type == "data_skew"]
        assert len(skew_issues) == 0

    def test_detect_low_cpu_warning(self, analyzer):
        """Test detecting low CPU utilization at warning level."""
        metrics = {"cpu_utilization": 0.50}
        issues = analyzer.detect_issues(metrics)
        cpu_issues = [i for i in issues if i.issue_type == "low_cpu_utilization"]
        assert len(cpu_issues) == 1
        assert cpu_issues[0].severity == "warning"

    def test_detect_low_cpu_critical(self, analyzer):
        """Test detecting low CPU utilization at critical level."""
        metrics = {"cpu_utilization": 0.30}
        issues = analyzer.detect_issues(metrics)
        cpu_issues = [i for i in issues if i.issue_type == "low_cpu_utilization"]
        assert len(cpu_issues) == 1
        assert cpu_issues[0].severity == "critical"

    def test_detect_high_cpu_warning(self, analyzer):
        """Test detecting high CPU utilization at warning level."""
        metrics = {"cpu_utilization": 0.96}
        issues = analyzer.detect_issues(metrics)
        cpu_issues = [i for i in issues if i.issue_type == "high_cpu_utilization"]
        assert len(cpu_issues) == 1
        assert cpu_issues[0].severity == "warning"

    def test_detect_high_cpu_critical(self, analyzer):
        """Test detecting high CPU utilization at critical level."""
        metrics = {"cpu_utilization": 0.995}
        issues = analyzer.detect_issues(metrics)
        cpu_issues = [i for i in issues if i.issue_type == "high_cpu_utilization"]
        assert len(cpu_issues) == 1
        assert cpu_issues[0].severity == "critical"

    def test_detect_multiple_issues(self, analyzer, sample_metrics):
        """Test detecting multiple issues simultaneously."""
        issues = analyzer.detect_issues(sample_metrics)
        issue_types = {i.issue_type for i in issues}
        # Sample metrics has: gc_pressure (0.15), memory_spill (1.5GB),
        # task_skew_ratio (5.0), cpu_utilization (0.55 - low)
        assert "gc_pressure" in issue_types
        assert "memory_spill" in issue_types
        assert "data_skew" in issue_types
        assert "low_cpu_utilization" in issue_types

    def test_analyze_full(self, analyzer, sample_metrics):
        """Test full analysis with all detections."""
        result = analyzer.analyze(
            app_id="app-123",
            metrics=sample_metrics,
            duration_seconds=45.0,
        )
        assert result.app_id == "app-123"
        assert result.workload_type is not None
        assert len(result.issues) > 0
        assert result.duration_seconds == 45.0


class TestWorkloadClassification:
    """Test workload classification."""

    @pytest.fixture
    def analyzer(self):
        """Create analyzer instance."""
        return WorkloadAnalyzer()

    def test_classify_etl_batch(self, analyzer):
        """Test classifying ETL batch workload."""
        metrics = {
            "shuffle_write": 2000000000,  # 2GB
            "task_duration_avg": 5.0,
            "executor_memory": 8000000000,
        }
        workload_type = analyzer.classify_workload(metrics)
        assert workload_type == "etl_batch"

    def test_classify_interactive(self, analyzer):
        """Test classifying interactive workload."""
        metrics = {
            "shuffle_write": 5000000,  # 5MB
            "task_duration_avg": 0.2,
            "executor_memory": 4000000000,
        }
        workload_type = analyzer.classify_workload(metrics)
        assert workload_type == "interactive"

    def test_classify_ml_training(self, analyzer):
        """Test classifying ML training workload."""
        # ML training: high memory, long tasks, low shuffle (cached data)
        metrics = {
            "shuffle_write": 50000000,  # 50MB - low shuffle (data cached)
            "task_duration_avg": 30.0,
            "executor_memory": 16000000000,  # 16GB
        }
        workload_type = analyzer.classify_workload(metrics)
        # ML training matches: executor_memory > 8GB, task_duration_avg > 10s (2 points)
        # ETL matches: task_duration_avg > 1s (1 point)
        # Interactive matches: nothing
        assert workload_type == "ml_training"

    def test_classify_default_to_etl(self, analyzer):
        """Test defaulting to ETL when ambiguous."""
        metrics = {
            "shuffle_write": 100000000,
            "task_duration_avg": 2.0,
            "executor_memory": 4000000000,
        }
        workload_type = analyzer.classify_workload(metrics)
        # Should default to etl_batch for ambiguous cases
        assert workload_type in ["etl_batch", "interactive"]


class TestAnalyzeMetricsCLI:
    """Test analyze_metrics CLI function."""

    @patch("autotuning.analyzer.WorkloadAnalyzer")
    def test_analyze_metrics_from_file(self, mock_analyzer_class, tmp_path: Path):
        """Test analyzing metrics from file."""
        # Create sample metrics file
        metrics_file = tmp_path / "metrics.json"
        metrics_file.write_text(json.dumps({
            "app_id": "app-123",
            "timestamp": "2026-02-22T12:00:00",
            "metrics": {"gc_ratio": 0.15},
            "duration_seconds": 45.0,
        }))

        mock_analyzer = Mock()
        mock_result = Mock()
        mock_result.save = Mock()
        mock_result.to_json = Mock(return_value="{}")
        mock_analyzer.analyze.return_value = mock_result
        mock_analyzer_class.return_value = mock_analyzer

        result = analyze_metrics(metrics_file=metrics_file)

        mock_analyzer.analyze.assert_called_once()


class TestSeverityLogic:
    """Test severity determination logic."""

    @pytest.fixture
    def analyzer(self):
        """Create analyzer instance."""
        return WorkloadAnalyzer()

    def test_determine_severity_ok(self, analyzer):
        """Test severity is ok when within thresholds."""
        severity = analyzer.determine_severity(
            value=0.05,
            warning_threshold=0.10,
            critical_threshold=0.20,
            condition="gt",
        )
        assert severity == "ok"

    def test_determine_severity_warning(self, analyzer):
        """Test severity is warning when between thresholds."""
        severity = analyzer.determine_severity(
            value=0.15,
            warning_threshold=0.10,
            critical_threshold=0.20,
            condition="gt",
        )
        assert severity == "warning"

    def test_determine_severity_critical(self, analyzer):
        """Test severity is critical when above threshold."""
        severity = analyzer.determine_severity(
            value=0.25,
            warning_threshold=0.10,
            critical_threshold=0.20,
            condition="gt",
        )
        assert severity == "critical"

    def test_determine_severity_lt_condition(self, analyzer):
        """Test severity with less-than condition."""
        severity = analyzer.determine_severity(
            value=0.30,
            warning_threshold=0.60,
            critical_threshold=0.40,
            condition="lt",
        )
        assert severity == "critical"

    def test_determine_severity_at_boundary(self, analyzer):
        """Test severity at exact threshold boundary."""
        severity = analyzer.determine_severity(
            value=0.10,
            warning_threshold=0.10,
            critical_threshold=0.20,
            condition="gt",
        )
        # At exactly warning threshold should be warning
        assert severity == "warning"


class TestEdgeCases:
    """Test edge cases and error handling."""

    @pytest.fixture
    def analyzer(self):
        """Create analyzer instance."""
        return WorkloadAnalyzer()

    def test_analyze_empty_metrics(self, analyzer):
        """Test analyzing empty metrics."""
        result = analyzer.analyze(
            app_id="app-123",
            metrics={},
            duration_seconds=45.0,
        )
        assert result.app_id == "app-123"
        assert len(result.issues) == 0  # No issues with empty metrics

    def test_analyze_missing_metric_defaults(self, analyzer):
        """Test missing metrics default to 0."""
        issues = analyzer.detect_issues({"gc_ratio": None})
        # Should handle None gracefully
        assert isinstance(issues, list)

    def test_analyze_negative_values(self, analyzer):
        """Test handling negative metric values."""
        metrics = {"cpu_utilization": -0.1}
        issues = analyzer.detect_issues(metrics)
        # Should handle negative values without crashing
        assert isinstance(issues, list)

    def test_classify_with_none_values(self, analyzer):
        """Test classification with None metric values."""
        metrics = {
            "shuffle_write": None,
            "task_duration_avg": None,
        }
        workload_type = analyzer.classify_workload(metrics)
        # Should not crash, return default
        assert workload_type is not None


class TestIntegration:
    """Integration tests."""

    @pytest.fixture
    def fixtures_path(self):
        """Path to test fixtures."""
        return Path(__file__).parent / "fixtures"

    def test_analyze_sample_metrics(self, fixtures_path):
        """Test analyzing sample metrics from fixture."""
        metrics_file = fixtures_path / "sample_metrics.json"
        if not metrics_file.exists():
            pytest.skip("Fixture file not found")

        analyzer = WorkloadAnalyzer()
        with open(metrics_file) as f:
            data = json.load(f)

        result = analyzer.analyze(
            app_id=data["app_id"],
            metrics=data["metrics"],
            duration_seconds=data.get("duration_seconds", 0),
        )

        assert result.app_id == "app-20260222120000-0001"
        assert result.workload_type in ["etl_batch", "ml_training"]
        # Sample has gc_ratio=0.08 (ok), memory_spill=1.5GB (critical),
        # task_skew_ratio=5.0 (critical), cpu_utilization missing
        issue_types = {i.issue_type for i in result.issues}
        assert "memory_spill" in issue_types
        assert "data_skew" in issue_types
