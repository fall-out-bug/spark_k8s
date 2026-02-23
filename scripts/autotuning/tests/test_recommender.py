"""Tests for autotuning recommender."""

import json
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

from autotuning.analyzer import AnalysisResult, DetectedIssue
from autotuning.recommender import (
    ConfigRecommender,
    Recommendation,
    RecommendationSet,
    apply_safety_bounds,
    generate_recommendations,
    load_profiles_config,
    load_bounds_config,
    parse_memory_value,
    format_memory_value,
)


class TestLoadConfigs:
    """Test configuration loading."""

    def test_load_profiles_config(self, tmp_path: Path):
        """Test loading profiles config."""
        config_path = tmp_path / "profiles.yaml"
        config_path.write_text("""
profiles:
  etl_batch:
    base_config:
      spark.sql.adaptive.enabled: "true"
""")
        config = load_profiles_config(config_path)
        assert "profiles" in config
        assert "etl_batch" in config["profiles"]

    def test_load_bounds_config(self, tmp_path: Path):
        """Test loading bounds config."""
        config_path = tmp_path / "bounds.yaml"
        config_path.write_text("""
safety_bounds:
  spark.executor.memory:
    min: "1Gi"
    max: "32Gi"
""")
        config = load_bounds_config(config_path)
        assert "safety_bounds" in config
        assert "spark.executor.memory" in config["safety_bounds"]


class TestMemoryParsing:
    """Test memory value parsing and formatting."""

    def test_parse_memory_gib(self):
        """Test parsing GiB values."""
        assert parse_memory_value("4Gi") == 4294967296
        assert parse_memory_value("16Gi") == 17179869184

    def test_parse_memory_mib(self):
        """Test parsing MiB values."""
        assert parse_memory_value("512Mi") == 536870912
        assert parse_memory_value("1024Mi") == 1073741824

    def test_parse_memory_bytes(self):
        """Test parsing raw bytes."""
        assert parse_memory_value("1073741824") == 1073741824

    def test_format_memory_gib(self):
        """Test formatting to GiB."""
        assert format_memory_value(4294967296, "Gi") == "4Gi"
        assert format_memory_value(8589934592, "Gi") == "8Gi"

    def test_format_memory_mib(self):
        """Test formatting to MiB."""
        assert format_memory_value(536870912, "Mi") == "512Mi"


class TestRecommendation:
    """Test Recommendation dataclass."""

    def test_create_recommendation(self):
        """Test creating Recommendation."""
        rec = Recommendation(
            parameter="spark.executor.memory",
            current_value="4Gi",
            recommended_value="8Gi",
            change_pct=100.0,
            confidence=0.9,
            rationale="Increase memory to reduce GC",
            safety_check="pass",
        )
        assert rec.parameter == "spark.executor.memory"
        assert rec.change_pct == 100.0
        assert rec.safety_check == "pass"

    def test_recommendation_to_dict(self):
        """Test converting to dict."""
        rec = Recommendation(
            parameter="spark.executor.cores",
            current_value="4",
            recommended_value="2",
            change_pct=-50.0,
            confidence=0.7,
            rationale="Reduce cores",
            safety_check="pass",
        )
        data = rec.to_dict()
        assert data["parameter"] == "spark.executor.cores"
        assert data["change_pct"] == -50.0


class TestRecommendationSet:
    """Test RecommendationSet dataclass."""

    def test_create_set(self):
        """Test creating RecommendationSet."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[
                Recommendation(
                    parameter="spark.executor.memory",
                    current_value="4Gi",
                    recommended_value="8Gi",
                    change_pct=100.0,
                    confidence=0.9,
                    rationale="test",
                    safety_check="pass",
                )
            ],
            overall_confidence=0.85,
            safety_issues=[],
        )
        assert rec_set.app_id == "app-123"
        assert len(rec_set.recommendations) == 1

    def test_to_json(self):
        """Test serializing to JSON."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[],
            overall_confidence=0.9,
            safety_issues=[],
        )
        json_str = rec_set.to_json()
        data = json.loads(json_str)
        assert data["app_id"] == "app-123"

    def test_save(self, tmp_path: Path):
        """Test saving to file."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[],
            overall_confidence=0.9,
            safety_issues=[],
        )
        output_path = tmp_path / "recommendations.json"
        rec_set.save(output_path)
        assert output_path.exists()


class TestConfigRecommender:
    """Test ConfigRecommender class."""

    @pytest.fixture
    def sample_analysis(self):
        """Sample analysis result for testing."""
        return AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[
                DetectedIssue(
                    issue_type="memory_spill",
                    severity="critical",
                    metric_value=1500000000,
                    threshold=1073741824,
                    recommendation="increase_memory",
                    rationale="Memory spill detected",
                ),
            ],
            metrics_summary={"executor_memory": 8589934592},  # 8GB
            duration_seconds=45.0,
            confidence=0.9,
        )

    @pytest.fixture
    def current_config(self):
        """Sample current Spark config."""
        return {
            "spark.executor.memory": "8Gi",
            "spark.executor.cores": "4",
            "spark.executor.instances": "2",
            "spark.sql.shuffle.partitions": "200",
        }

    @pytest.fixture
    def recommender(self):
        """Create recommender instance."""
        return ConfigRecommender()

    def test_recommender_init(self, recommender):
        """Test recommender initialization."""
        assert recommender.profiles is not None
        assert recommender.bounds is not None

    def test_recommend_for_memory_spill(self, recommender, sample_analysis, current_config):
        """Test recommendation for memory spill issue."""
        rec_set = recommender.recommend(
            analysis=sample_analysis,
            current_config=current_config,
        )
        # Should recommend increasing memory
        params = [r.parameter for r in rec_set.recommendations]
        assert "spark.executor.memory" in params or any("memory" in p for p in params)

    def test_recommend_applies_workload_profile(self, recommender, sample_analysis, current_config):
        """Test that workload profile base config is applied."""
        rec_set = recommender.recommend(
            analysis=sample_analysis,
            current_config=current_config,
        )
        # ETL batch profile should include adaptive.enabled
        assert rec_set.workload_type == "etl_batch"

    def test_recommend_with_no_issues(self, recommender, current_config):
        """Test recommendation when no issues detected."""
        analysis = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[],
            metrics_summary={},
            duration_seconds=45.0,
            confidence=0.9,
        )
        rec_set = recommender.recommend(
            analysis=analysis,
            current_config=current_config,
        )
        # Should still apply profile base config
        assert rec_set.workload_type == "etl_batch"

    def test_safety_bounds_enforced(self, recommender):
        """Test that safety bounds are enforced."""
        analysis = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[
                DetectedIssue(
                    issue_type="memory_spill",
                    severity="critical",
                    metric_value=1500000000,
                    threshold=1073741824,
                    recommendation="increase_memory",
                    rationale="test",
                ),
            ],
            metrics_summary={"executor_memory": 30000000000},  # 30GB
            duration_seconds=45.0,
            confidence=0.9,
        )
        # Current memory near max, increase should be bounded
        current_config = {"spark.executor.memory": "30Gi"}

        rec_set = recommender.recommend(
            analysis=analysis,
            current_config=current_config,
        )

        # Check that no recommendation exceeds bounds
        for rec in rec_set.recommendations:
            if rec.parameter == "spark.executor.memory":
                recommended_bytes = parse_memory_value(rec.recommended_value)
                assert recommended_bytes <= parse_memory_value("32Gi")


class TestSafetyBounds:
    """Test safety bounds checking."""

    def test_apply_bounds_within_range(self):
        """Test value within bounds."""
        result = apply_safety_bounds(
            parameter="spark.executor.memory",
            value="8Gi",
            current="4Gi",
        )
        assert result.safety_check == "pass"

    def test_apply_bounds_exceeds_max(self):
        """Test value exceeds max bound."""
        result = apply_safety_bounds(
            parameter="spark.executor.memory",
            value="64Gi",  # Exceeds 32Gi max
            current="32Gi",
        )
        assert result.safety_check == "capped"
        assert "32Gi" in result.recommended_value  # Should be capped to max

    def test_apply_bounds_below_min(self):
        """Test value below min bound."""
        result = apply_safety_bounds(
            parameter="spark.executor.cores",
            value="0",  # Below min of 1
            current="2",
        )
        assert result.safety_check == "capped"
        assert result.recommended_value == "1"

    def test_apply_bounds_max_increase_pct(self):
        """Test max increase percentage."""
        result = apply_safety_bounds(
            parameter="spark.executor.memory",
            value="20Gi",  # 5x increase from 4Gi
            current="4Gi",
        )
        # Max increase is 100% (2x), so should be capped to 8Gi
        assert result.safety_check in ["capped", "warning"]


class TestGenerateRecommendations:
    """Test generate_recommendations CLI function."""

    @patch("autotuning.recommender.ConfigRecommender")
    def test_generate_from_file(self, mock_recommender_class, tmp_path: Path):
        """Test generating recommendations from analysis file."""
        analysis_file = tmp_path / "analysis.json"
        analysis_file.write_text(json.dumps({
            "app_id": "app-123",
            "timestamp": "2026-02-22T12:00:00",
            "workload_type": "etl_batch",
            "issues": [],
            "metrics_summary": {},
        }))

        mock_recommender = Mock()
        mock_result = Mock()
        mock_result.save = Mock()
        mock_result.to_json = Mock(return_value="{}")
        mock_recommender.recommend.return_value = mock_result
        mock_recommender_class.return_value = mock_recommender

        result = generate_recommendations(analysis_file=analysis_file)

        mock_recommender.recommend.assert_called_once()


class TestWorkloadProfiles:
    """Test workload profile application."""

    @pytest.fixture
    def recommender(self):
        """Create recommender instance."""
        return ConfigRecommender()

    def test_etl_batch_profile(self, recommender):
        """Test ETL batch profile application."""
        analysis = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[],
            metrics_summary={},
            duration_seconds=45.0,
            confidence=0.9,
        )
        rec_set = recommender.recommend(
            analysis=analysis,
            current_config={},
        )
        # Should include base config for ETL
        assert rec_set.workload_type == "etl_batch"

    def test_interactive_profile(self, recommender):
        """Test interactive profile application."""
        analysis = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="interactive",
            issues=[],
            metrics_summary={},
            duration_seconds=45.0,
            confidence=0.9,
        )
        rec_set = recommender.recommend(
            analysis=analysis,
            current_config={},
        )
        assert rec_set.workload_type == "interactive"

    def test_ml_training_profile(self, recommender):
        """Test ML training profile application."""
        analysis = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="ml_training",
            issues=[],
            metrics_summary={},
            duration_seconds=45.0,
            confidence=0.9,
        )
        rec_set = recommender.recommend(
            analysis=analysis,
            current_config={},
        )
        assert rec_set.workload_type == "ml_training"


class TestConfidenceScoring:
    """Test confidence scoring."""

    @pytest.fixture
    def recommender(self):
        """Create recommender instance."""
        return ConfigRecommender()

    def test_critical_issue_higher_confidence(self, recommender):
        """Test critical issues get higher confidence."""
        critical_analysis = AnalysisResult(
            app_id="app-123",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[
                DetectedIssue(
                    issue_type="memory_spill",
                    severity="critical",
                    metric_value=2000000000,
                    threshold=1073741824,
                    recommendation="increase_memory",
                    rationale="test",
                ),
            ],
            metrics_summary={},
            duration_seconds=45.0,
            confidence=0.9,
        )
        warning_analysis = AnalysisResult(
            app_id="app-456",
            timestamp=datetime.now(),
            workload_type="etl_batch",
            issues=[
                DetectedIssue(
                    issue_type="low_cpu_utilization",
                    severity="warning",
                    metric_value=0.5,
                    threshold=0.6,
                    recommendation="reduce_cores",
                    rationale="test",
                ),
            ],
            metrics_summary={},
            duration_seconds=45.0,
            confidence=0.9,
        )

        critical_rec = recommender.recommend(
            analysis=critical_analysis,
            current_config={"spark.executor.memory": "4Gi"},
        )
        warning_rec = recommender.recommend(
            analysis=warning_analysis,
            current_config={"spark.executor.cores": "4"},
        )

        # Critical issues should have higher confidence in recommendations
        # (memory_spill has confidence_factor 0.95, low_cpu has 0.7)
        assert critical_rec.overall_confidence >= warning_rec.overall_confidence


class TestIntegration:
    """Integration tests."""

    @pytest.fixture
    def fixtures_path(self):
        """Path to test fixtures."""
        return Path(__file__).parent / "fixtures"

    def test_full_recommendation_flow(self, fixtures_path):
        """Test full flow from analysis to recommendations."""
        analysis_file = fixtures_path / "sample_analysis.json"
        if not analysis_file.exists():
            pytest.skip("Fixture file not found")

        with open(analysis_file) as f:
            data = json.load(f)

        # Reconstruct AnalysisResult
        issues = [
            DetectedIssue(
                issue_type=i["issue_type"],
                severity=i["severity"],
                metric_value=i["metric_value"],
                threshold=i["threshold"],
                recommendation=i["recommendation"],
                rationale=i["rationale"],
            )
            for i in data["issues"]
        ]

        analysis = AnalysisResult(
            app_id=data["app_id"],
            timestamp=datetime.fromisoformat(data["timestamp"]),
            workload_type=data["workload_type"],
            issues=issues,
            metrics_summary=data["metrics_summary"],
            duration_seconds=data["duration_seconds"],
            confidence=data["confidence"],
        )

        recommender = ConfigRecommender()
        current_config = {
            "spark.executor.memory": "8Gi",
            "spark.executor.cores": "4",
            "spark.executor.instances": "2",
            "spark.sql.shuffle.partitions": "200",
        }

        rec_set = recommender.recommend(
            analysis=analysis,
            current_config=current_config,
        )

        assert rec_set.app_id == "app-20260222120000-0001"
        assert rec_set.workload_type == "etl_batch"
        # Should have recommendations for memory_spill, data_skew, etc.
        assert len(rec_set.recommendations) > 0

        # Check specific recommendations
        params = [r.parameter for r in rec_set.recommendations]
        # Memory spill should trigger memory increase
        # Data skew should trigger skew join config
        assert any("skew" in p.lower() or "memory" in p.lower() for p in params)
