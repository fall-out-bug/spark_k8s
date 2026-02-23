"""End-to-end integration tests for autotuning pipeline.

These tests validate the complete autotuning workflow:
collect → analyze → recommend → apply
"""

import json
import time
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch

import pytest
import yaml

from autotuning import (
    MetricsCollector,
    MetricsResult,
    WorkloadAnalyzer,
    AnalysisResult,
    ConfigRecommender,
    RecommendationSet,
    HelmValuesGenerator,
    ValidationResult,
    collect_metrics,
    analyze_metrics,
    generate_recommendations,
    apply_recommendations,
)

FIXTURES_PATH = Path(__file__).parent / "fixtures"


class TestE2EBasicPipeline:
    """Basic end-to-end pipeline tests."""

    @pytest.fixture
    def sample_metrics_dict(self):
        """Sample metrics dictionary for testing."""
        return {
            "gc_time": 0.08,  # High GC (8%)
            "memory_spill": 500_000_000,  # 500MB spilled
            "cpu_utilization": 0.35,  # Low CPU (35%)
            "shuffle_read": 2_000_000_000,  # 2GB shuffle read
            "shuffle_write": 1_500_000_000,  # 1.5GB shuffle write
            "executor_count": 4,
            "executor_memory_bytes": 8_000_000_000,  # 8GB
            "executor_cores": 4,
            "duration_seconds": 300,
        }

    def test_full_pipeline_with_mocks(self, sample_metrics_dict, tmp_path: Path):
        """Test full pipeline with mocked Prometheus."""
        # Step 1: Create metrics result
        mock_result = MetricsResult(
            app_id="test-app-e2e",
            timestamp=datetime.now(),
            metrics=sample_metrics_dict,
            duration_seconds=300,
            raw_response={},
        )

        # Save metrics to file
        metrics_file = tmp_path / "metrics.json"
        metrics_file.write_text(mock_result.to_json())

        # Step 2: Analyze metrics
        analysis_result = analyze_metrics(metrics_file=metrics_file)
        assert analysis_result.workload_type in ["etl_batch", "interactive", "ml_training", "streaming"]
        assert len(analysis_result.issues) >= 0

        # Save analysis
        analysis_file = tmp_path / "analysis.json"
        analysis_file.write_text(analysis_result.to_json())

        # Step 3: Generate recommendations
        rec_set = generate_recommendations(analysis_file=analysis_file)
        assert rec_set.overall_confidence >= 0.0
        assert rec_set.overall_confidence <= 1.0

        # Save recommendations
        recs_file = tmp_path / "recommendations.json"
        recs_file.write_text(rec_set.to_json())

        # Step 4: Apply recommendations
        values_file = tmp_path / "autotuned-values.yaml"
        validation = apply_recommendations(
            recommendations_file=recs_file,
            output_path=values_file,
        )

        assert values_file.exists()
        assert isinstance(validation, ValidationResult)

        # Validate output YAML
        content = values_file.read_text()
        values = yaml.safe_load(content)

        assert "connect" in values or "autotuning" in values
        if "autotuning" in values:
            assert values["autotuning"]["appId"] == "test-app-e2e"

    def test_pipeline_from_fixture_files(self, tmp_path: Path):
        """Test pipeline using fixture files."""
        metrics_file = FIXTURES_PATH / "sample_metrics.json"

        if not metrics_file.exists():
            pytest.skip("sample_metrics.json fixture not found")

        # Load metrics
        metrics_data = json.loads(metrics_file.read_text())

        # Analyze using the API
        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(
            app_id=metrics_data.get("app_id", "fixture-app"),
            metrics=metrics_data.get("metrics", {}),
            duration_seconds=metrics_data.get("duration_seconds", 0),
        )

        assert isinstance(analysis, AnalysisResult)
        assert analysis.workload_type in ["etl_batch", "interactive", "ml_training", "streaming"]

        # Recommend (with default current config)
        recommender = ConfigRecommender()
        current_config = {
            "spark.executor.memory": "8Gi",
            "spark.executor.cores": "4",
        }
        rec_set = recommender.recommend(analysis, current_config)

        assert isinstance(rec_set, RecommendationSet)

        # Apply
        generator = HelmValuesGenerator()
        yaml_content = generator.generate_overlay(rec_set)

        assert "connect:" in yaml_content or "autotuning:" in yaml_content


class TestE2EScenarios:
    """E2E tests for specific scenarios."""

    @pytest.fixture
    def gc_pressure_metrics(self):
        """Metrics indicating GC pressure."""
        return {
            "gc_time": 0.15,  # 15% GC time - HIGH
            "memory_spill": 2_000_000_000,  # 2GB spilled
            "cpu_utilization": 0.6,
            "shuffle_read": 1_000_000_000,
            "shuffle_write": 500_000_000,
            "executor_count": 4,
            "executor_memory_bytes": 4_000_000_000,  # 4GB - Too low
            "executor_cores": 4,
            "duration_seconds": 600,
        }

    @pytest.fixture
    def low_cpu_metrics(self):
        """Metrics indicating low CPU utilization."""
        return {
            "gc_time": 0.02,
            "memory_spill": 0,
            "cpu_utilization": 0.25,  # 25% CPU - LOW
            "shuffle_read": 500_000_000,
            "shuffle_write": 300_000_000,
            "executor_count": 8,
            "executor_memory_bytes": 16_000_000_000,  # 16GB
            "executor_cores": 8,  # Too many
            "duration_seconds": 300,
        }

    @pytest.fixture
    def optimal_metrics(self):
        """Metrics for optimal configuration."""
        return {
            "gc_time": 0.03,  # 3% - good
            "memory_spill": 0,  # No spill
            "cpu_utilization": 0.7,  # 70% - good
            "shuffle_read": 1_000_000_000,
            "shuffle_write": 800_000_000,
            "executor_count": 4,
            "executor_memory_bytes": 16_000_000_000,  # 16GB
            "executor_cores": 4,
            "duration_seconds": 200,
        }

    def test_gc_pressure_scenario(self, gc_pressure_metrics, tmp_path: Path):
        """Test scenario with GC pressure issues."""
        # Analyze
        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(
            app_id="gc-pressure-test",
            metrics=gc_pressure_metrics,
            duration_seconds=600,
        )

        # Should detect GC pressure
        issue_types = [i.issue_type for i in analysis.issues]
        assert "gc_pressure" in issue_types or "memory_spill" in issue_types

        # Generate recommendations
        recommender = ConfigRecommender()
        current_config = {
            "spark.executor.memory": "4Gi",
            "spark.executor.cores": "4",
        }
        rec_set = recommender.recommend(analysis, current_config)

        # Should recommend memory increase
        params = [r.parameter for r in rec_set.recommendations]
        assert any("memory" in p.lower() for p in params)

    def test_low_cpu_scenario(self, low_cpu_metrics, tmp_path: Path):
        """Test scenario with low CPU utilization."""
        # Analyze
        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(
            app_id="low-cpu-test",
            metrics=low_cpu_metrics,
            duration_seconds=300,
        )

        # Should detect low CPU (issue type is "low_cpu_utilization")
        issue_types = [i.issue_type for i in analysis.issues]
        assert "low_cpu_utilization" in issue_types or "low_cpu_util" in issue_types

        # Generate recommendations
        recommender = ConfigRecommender()
        current_config = {
            "spark.executor.memory": "16Gi",
            "spark.executor.cores": "8",
        }
        rec_set = recommender.recommend(analysis, current_config)

        # Should recommend core reduction
        params = [r.parameter for r in rec_set.recommendations]
        assert any("cores" in p.lower() for p in params)

    def test_optimal_scenario(self, optimal_metrics, tmp_path: Path):
        """Test scenario with optimal configuration."""
        # Analyze
        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(
            app_id="optimal-test",
            metrics=optimal_metrics,
            duration_seconds=200,
        )

        # Should have few or no issues
        # (optimal config might still have minor suggestions)
        assert len(analysis.issues) <= 2

        # Generate recommendations
        recommender = ConfigRecommender()
        current_config = {
            "spark.executor.memory": "16Gi",
            "spark.executor.cores": "4",
        }
        rec_set = recommender.recommend(analysis, current_config)

        # Recommendations should be minimal or have high confidence
        for rec in rec_set.recommendations:
            assert rec.confidence >= 0.5


class TestE2ESafetyValidation:
    """E2E tests for safety validation."""

    def test_recommendations_within_bounds(self, tmp_path: Path):
        """Test that recommendations stay within safety bounds."""
        # Create extreme metrics that would push recommendations
        extreme_metrics = {
            "gc_time": 0.5,  # 50% GC - extremely high
            "memory_spill": 10_000_000_000,  # 10GB spilled
            "cpu_utilization": 0.1,  # 10% CPU
            "shuffle_read": 50_000_000_000,  # 50GB
            "shuffle_write": 30_000_000_000,  # 30GB
            "executor_count": 2,
            "executor_memory_bytes": 2_000_000_000,  # 2GB
            "executor_cores": 2,
            "duration_seconds": 3600,
        }

        # Analyze
        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(
            app_id="extreme-test",
            metrics=extreme_metrics,
            duration_seconds=3600,
        )

        # Generate recommendations
        recommender = ConfigRecommender()
        current_config = {
            "spark.executor.memory": "2Gi",
            "spark.executor.cores": "2",
        }
        rec_set = recommender.recommend(analysis, current_config)

        # Apply with validation
        generator = HelmValuesGenerator()
        values_file = tmp_path / "values.yaml"
        result = generator.save_overlay(rec_set, values_file)

        # Validate safety bounds
        content = values_file.read_text()
        values = yaml.safe_load(content)

        # Memory should not exceed reasonable limits (e.g., 64Gi)
        if "connect" in values and "executor" in values.get("connect", {}):
            memory = values["connect"]["executor"].get("memory", "8Gi")
            # Parse memory and check bounds
            if isinstance(memory, str) and memory.endswith("Gi"):
                mem_val = int(memory[:-2])
                assert mem_val <= 64, f"Memory {mem_val}Gi exceeds max 64Gi"


class TestE2EPerformance:
    """E2E performance benchmarks."""

    PERFORMANCE_BENCHMARKS = {
        "analyzer_duration": 1.0,      # seconds, max
        "recommender_duration": 0.5,   # seconds, max
        "applier_duration": 0.5,       # seconds, max
        "full_pipeline_duration": 3.0, # seconds, max (without collection)
    }

    @pytest.fixture
    def sample_metrics_dict(self):
        """Sample metrics for performance testing."""
        return {
            "gc_time": 0.05,
            "memory_spill": 100_000_000,
            "cpu_utilization": 0.5,
            "shuffle_read": 1_000_000_000,
            "shuffle_write": 800_000_000,
        }

    def test_analyzer_performance(self, sample_metrics_dict):
        """Test analyzer performance."""
        analyzer = WorkloadAnalyzer()

        start = time.time()
        for _ in range(10):
            analyzer.analyze(app_id="perf-test", metrics=sample_metrics_dict)
        duration = (time.time() - start) / 10

        assert duration < self.PERFORMANCE_BENCHMARKS["analyzer_duration"], \
            f"Analyzer too slow: {duration:.3f}s > {self.PERFORMANCE_BENCHMARKS['analyzer_duration']}s"

    def test_recommender_performance(self, sample_metrics_dict):
        """Test recommender performance."""
        analyzer = WorkloadAnalyzer()
        recommender = ConfigRecommender()

        analysis = analyzer.analyze(app_id="perf-test", metrics=sample_metrics_dict)
        current_config = {"spark.executor.memory": "8Gi", "spark.executor.cores": "4"}

        start = time.time()
        for _ in range(10):
            recommender.recommend(analysis, current_config)
        duration = (time.time() - start) / 10

        assert duration < self.PERFORMANCE_BENCHMARKS["recommender_duration"], \
            f"Recommender too slow: {duration:.3f}s > {self.PERFORMANCE_BENCHMARKS['recommender_duration']}s"

    def test_applier_performance(self, sample_metrics_dict):
        """Test applier performance."""
        analyzer = WorkloadAnalyzer()
        recommender = ConfigRecommender()
        generator = HelmValuesGenerator()

        analysis = analyzer.analyze(app_id="perf-test", metrics=sample_metrics_dict)
        current_config = {"spark.executor.memory": "8Gi", "spark.executor.cores": "4"}
        rec_set = recommender.recommend(analysis, current_config)

        start = time.time()
        for _ in range(10):
            generator.generate_overlay(rec_set)
        duration = (time.time() - start) / 10

        assert duration < self.PERFORMANCE_BENCHMARKS["applier_duration"], \
            f"Applier too slow: {duration:.3f}s > {self.PERFORMANCE_BENCHMARKS['applier_duration']}s"

    def test_full_pipeline_performance(self, sample_metrics_dict, tmp_path: Path):
        """Test full pipeline performance (without collection)."""
        start = time.time()

        # Analyze
        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(app_id="perf-test", metrics=sample_metrics_dict)

        # Recommend
        recommender = ConfigRecommender()
        current_config = {"spark.executor.memory": "8Gi", "spark.executor.cores": "4"}
        rec_set = recommender.recommend(analysis, current_config)

        # Apply
        generator = HelmValuesGenerator()
        values_file = tmp_path / "values.yaml"
        generator.save_overlay(rec_set, values_file)

        duration = time.time() - start

        assert duration < self.PERFORMANCE_BENCHMARKS["full_pipeline_duration"], \
            f"Full pipeline too slow: {duration:.3f}s > {self.PERFORMANCE_BENCHMARKS['full_pipeline_duration']}s"


class TestE2EWorkloadClassification:
    """E2E tests for workload classification."""

    def test_classify_etl_batch(self):
        """Test ETL batch workload classification."""
        metrics = {
            "gc_time": 0.05,
            "shuffle_read": 5_000_000_000,  # 5GB - large shuffle
            "shuffle_write": 3_000_000_000,  # 3GB
            "cpu_utilization": 0.6,
            "duration_seconds": 600,
        }

        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(app_id="etl-test", metrics=metrics)

        assert analysis.workload_type == "etl_batch"

    def test_classify_interactive(self):
        """Test interactive workload classification."""
        metrics = {
            "gc_time": 0.03,
            "shuffle_read": 100_000_000,  # 100MB - small
            "shuffle_write": 50_000_000,
            "cpu_utilization": 0.4,
            "duration_seconds": 30,  # Short
        }

        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(app_id="interactive-test", metrics=metrics)

        # Interactive or other valid type
        assert analysis.workload_type in ["interactive", "etl_batch"]

    def test_classify_ml_training(self):
        """Test ML training workload classification."""
        metrics = {
            "gc_time": 0.08,
            "shuffle_read": 50_000_000,  # 50MB - low shuffle (cached data)
            "shuffle_write": 20_000_000,
            "cpu_utilization": 0.9,  # High CPU
            "duration_seconds": 3600,  # Long running
        }

        analyzer = WorkloadAnalyzer()
        analysis = analyzer.analyze(app_id="ml-test", metrics=metrics)

        # Should classify as ml_training or similar
        assert analysis.workload_type in ["ml_training", "etl_batch"]


class TestE2EOutputValidation:
    """E2E tests for output validation."""

    def test_helm_values_structure(self, tmp_path: Path):
        """Test that generated Helm values have correct structure."""
        metrics = {
            "gc_time": 0.1,
            "memory_spill": 1_000_000_000,
            "cpu_utilization": 0.5,
            "shuffle_read": 2_000_000_000,
            "shuffle_write": 1_500_000_000,
        }

        analyzer = WorkloadAnalyzer()
        recommender = ConfigRecommender()
        generator = HelmValuesGenerator()

        analysis = analyzer.analyze(app_id="structure-test", metrics=metrics)
        current_config = {"spark.executor.memory": "8Gi", "spark.executor.cores": "4"}
        rec_set = recommender.recommend(analysis, current_config)

        values_file = tmp_path / "values.yaml"
        generator.save_overlay(rec_set, values_file)

        content = values_file.read_text()
        values = yaml.safe_load(content)

        # Check structure
        assert isinstance(values, dict)

        # Check autotuning metadata
        if "autotuning" in values:
            auto = values["autotuning"]
            assert "appId" in auto
            assert "confidence" in auto
            assert "workloadType" in auto
            assert "generatedAt" in auto

    def test_yaml_is_valid(self, tmp_path: Path):
        """Test that output is valid YAML."""
        metrics = {"gc_time": 0.05}

        analyzer = WorkloadAnalyzer()
        recommender = ConfigRecommender()
        generator = HelmValuesGenerator()

        analysis = analyzer.analyze(app_id="yaml-test", metrics=metrics)
        current_config = {"spark.executor.memory": "8Gi", "spark.executor.cores": "4"}
        rec_set = recommender.recommend(analysis, current_config)

        yaml_content = generator.generate_overlay(rec_set)

        # Should parse without errors
        values = yaml.safe_load(yaml_content)
        assert isinstance(values, dict)


@pytest.mark.integration
class TestE2ERealPrometheus:
    """E2E tests requiring real Prometheus connection.

    These tests are skipped by default. Set PROMETHEUS_URL env var to enable.
    """

    @pytest.fixture
    def prometheus_url(self):
        """Get Prometheus URL from environment."""
        import os
        url = os.environ.get("PROMETHEUS_URL")
        if not url:
            pytest.skip("PROMETHEUS_URL not set")
        return url

    def test_real_collection(self, prometheus_url):
        """Test real metrics collection from Prometheus."""
        collector = MetricsCollector(prometheus_url=prometheus_url)

        # Try to collect metrics for a test app
        # This will fail if no app exists, which is expected
        try:
            result = collector.collect(app_id="test-app")
            assert isinstance(result, MetricsResult)
        except Exception as e:
            # Connection errors are acceptable in test env
            if "connection" in str(e).lower() or "refused" in str(e).lower():
                pytest.skip(f"Cannot connect to Prometheus: {e}")
            raise
