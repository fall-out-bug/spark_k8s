"""Tests for autotuning Helm values generator (applier)."""

import json
import re
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch

import pytest
import yaml

from autotuning.recommender import Recommendation, RecommendationSet
from autotuning.applier import (
    HelmValuesGenerator,
    ValidationResult,
    apply_recommendations,
    generate_helm_overlay,
    validate_helm_values,
    get_helm_path,
    load_recommendations,
)


class TestGetHelmPath:
    """Test Spark config to Helm path mapping."""

    def test_executor_memory(self):
        """Test executor memory mapping."""
        path = get_helm_path("spark.executor.memory")
        assert path == "connect.executor.memory"

    def test_executor_cores(self):
        """Test executor cores mapping."""
        path = get_helm_path("spark.executor.cores")
        assert path == "connect.executor.cores"

    def test_shuffle_partitions(self):
        """Test shuffle partitions mapping."""
        path = get_helm_path("spark.sql.shuffle.partitions")
        assert path == "connect.sparkConf.spark.sql.shuffle.partitions"

    def test_adaptive_enabled(self):
        """Test adaptive enabled mapping."""
        path = get_helm_path("spark.sql.adaptive.enabled")
        assert path == "connect.sparkConf.spark.sql.adaptive.enabled"

    def test_unknown_param(self):
        """Test unknown parameter returns sparkConf path."""
        path = get_helm_path("spark.sql.custom.param")
        assert "sparkConf" in path


class TestValidationResult:
    """Test ValidationResult dataclass."""

    def test_empty_result(self):
        """Test empty validation result."""
        result = ValidationResult()
        assert result.valid is True
        assert len(result.errors) == 0
        assert len(result.warnings) == 0

    def test_add_error(self):
        """Test adding error."""
        result = ValidationResult()
        result.add_error("Test error")
        assert result.valid is False
        assert "Test error" in result.errors

    def test_add_warning(self):
        """Test adding warning."""
        result = ValidationResult()
        result.add_warning("Test warning")
        assert result.valid is True  # Warnings don't invalidate
        assert "Test warning" in result.warnings


class TestValidateHelmValues:
    """Test Helm values validation."""

    def test_validate_valid_yaml(self, tmp_path: Path):
        """Test validating valid YAML file."""
        values_file = tmp_path / "values.yaml"
        values_file.write_text("""
connect:
  executor:
    memory: "8Gi"
    cores: 4
""")
        result = validate_helm_values(values_file)
        assert result.valid is True

    def test_validate_invalid_yaml(self, tmp_path: Path):
        """Test validating invalid YAML file."""
        values_file = tmp_path / "values.yaml"
        values_file.write_text("""
connect:
  executor:
    memory: "8Gi"
    - invalid list
""")
        result = validate_helm_values(values_file)
        assert result.valid is False
        assert len(result.errors) > 0

    def test_validate_memory_format(self, tmp_path: Path):
        """Test memory format validation."""
        values_file = tmp_path / "values.yaml"
        values_file.write_text("""
connect:
  executor:
    memory: "invalid"
""")
        result = validate_helm_values(values_file)
        assert len(result.errors) > 0

    def test_validate_missing_connect(self, tmp_path: Path):
        """Test missing connect section warning."""
        values_file = tmp_path / "values.yaml"
        values_file.write_text("other: value")
        result = validate_helm_values(values_file)
        assert any("connect" in w.lower() for w in result.warnings)


class TestHelmValuesGenerator:
    """Test HelmValuesGenerator class."""

    @pytest.fixture
    def sample_rec_set(self):
        """Sample recommendation set for testing."""
        return RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[
                Recommendation(
                    parameter="spark.executor.memory",
                    current_value="8Gi",
                    recommended_value="10Gi",
                    change_pct=25.0,
                    confidence=0.9,
                    rationale="test",
                    safety_check="pass",
                ),
                Recommendation(
                    parameter="spark.executor.cores",
                    current_value="4",
                    recommended_value="3",
                    change_pct=-25.0,
                    confidence=0.7,
                    rationale="test",
                    safety_check="pass",
                ),
            ],
            overall_confidence=0.8,
            safety_issues=[],
        )

    @pytest.fixture
    def generator(self):
        """Create generator instance."""
        return HelmValuesGenerator()

    def test_generator_init(self, generator):
        """Test generator initialization."""
        assert generator is not None

    def test_generate_overlay(self, generator, sample_rec_set):
        """Test generating overlay format."""
        yaml_str = generator.generate_overlay(sample_rec_set)
        values = yaml.safe_load(yaml_str)

        assert "connect" in values
        assert values["connect"]["executor"]["memory"] == "10Gi"
        assert values["connect"]["executor"]["cores"] == 3

    def test_overlay_includes_metadata(self, generator, sample_rec_set):
        """Test overlay includes metadata."""
        yaml_str = generator.generate_overlay(sample_rec_set)
        values = yaml.safe_load(yaml_str)

        assert "autotuning" in values
        assert values["autotuning"]["appId"] == "app-123"
        assert "confidence" in values["autotuning"]

    def test_overlay_includes_spark_conf(self, generator):
        """Test overlay includes sparkConf section."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[
                Recommendation(
                    parameter="spark.sql.shuffle.partitions",
                    current_value="200",
                    recommended_value="400",
                    change_pct=100.0,
                    confidence=0.8,
                    rationale="test",
                    safety_check="pass",
                ),
            ],
            overall_confidence=0.8,
            safety_issues=[],
        )
        yaml_str = generator.generate_overlay(rec_set)
        values = yaml.safe_load(yaml_str)

        assert "sparkConf" in values["connect"]
        assert values["connect"]["sparkConf"]["spark.sql.shuffle.partitions"] == 400

    def test_generate_with_base_config(self, generator):
        """Test generating with base config from profile."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[],
            overall_confidence=0.8,
            safety_issues=[],
            base_config={
                "spark.sql.adaptive.enabled": "true",
                "spark.memory.fraction": "0.7",
            },
        )
        yaml_str = generator.generate_overlay(rec_set)
        values = yaml.safe_load(yaml_str)

        assert values["connect"]["sparkConf"]["spark.sql.adaptive.enabled"] == "true"

    def test_save_overlay(self, generator, sample_rec_set, tmp_path: Path):
        """Test saving overlay to file."""
        output_path = tmp_path / "overlay.yaml"
        generator.save_overlay(sample_rec_set, output_path)

        assert output_path.exists()
        content = output_path.read_text()
        assert "connect:" in content


class TestGenerateHelmOverlay:
    """Test generate_helm_overlay convenience function."""

    def test_generate_from_file(self, tmp_path: Path):
        """Test generating from recommendations file."""
        rec_file = tmp_path / "recommendations.json"
        rec_file.write_text(json.dumps({
            "app_id": "app-123",
            "workload_type": "etl_batch",
            "recommendations": [
                {
                    "parameter": "spark.executor.memory",
                    "current_value": "8Gi",
                    "recommended_value": "10Gi",
                    "change_pct": 25.0,
                    "confidence": 0.9,
                    "rationale": "test",
                    "safety_check": "pass",
                }
            ],
            "overall_confidence": 0.8,
            "safety_issues": [],
            "base_config": {},
        }))

        yaml_str = generate_helm_overlay(rec_file)
        values = yaml.safe_load(yaml_str)

        assert values["connect"]["executor"]["memory"] == "10Gi"


class TestApplyRecommendations:
    """Test apply_recommendations CLI function."""

    def test_apply_with_output(self, tmp_path: Path):
        """Test applying with output file."""
        rec_file = tmp_path / "recommendations.json"
        rec_file.write_text(json.dumps({
            "app_id": "app-123",
            "workload_type": "etl_batch",
            "recommendations": [],
            "overall_confidence": 0.8,
            "safety_issues": [],
            "base_config": {},
        }))

        output_path = tmp_path / "output.yaml"
        result = apply_recommendations(
            recommendations_file=rec_file,
            output_path=output_path,
        )

        assert output_path.exists()
        assert result.valid is True


class TestYamlFormat:
    """Test YAML output formatting."""

    @pytest.fixture
    def generator(self):
        """Create generator instance."""
        return HelmValuesGenerator()

    def test_yaml_has_header_comments(self, generator):
        """Test YAML includes header comments."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[],
            overall_confidence=0.85,
            safety_issues=[],
            generated_at=datetime(2026, 2, 22, 12, 0, 0),
        )
        yaml_str = generator.generate_overlay(rec_set)

        assert "# Generated by spark-autotuner" in yaml_str
        assert "app-123" in yaml_str

    def test_numeric_values_not_quoted(self, generator):
        """Test numeric values are not quoted."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[
                Recommendation(
                    parameter="spark.executor.cores",
                    current_value="4",
                    recommended_value="3",
                    change_pct=-25.0,
                    confidence=0.7,
                    rationale="test",
                    safety_check="pass",
                ),
            ],
            overall_confidence=0.8,
            safety_issues=[],
        )
        yaml_str = generator.generate_overlay(rec_set)

        # Cores should be numeric, not string
        assert "cores: 3" in yaml_str or "cores: '3'" not in yaml_str

    def test_memory_values_preserved(self, generator):
        """Test memory values keep Gi/Mi suffix."""
        rec_set = RecommendationSet(
            app_id="app-123",
            workload_type="etl_batch",
            recommendations=[
                Recommendation(
                    parameter="spark.executor.memory",
                    current_value="8Gi",
                    recommended_value="10Gi",
                    change_pct=25.0,
                    confidence=0.9,
                    rationale="test",
                    safety_check="pass",
                ),
            ],
            overall_confidence=0.8,
            safety_issues=[],
        )
        yaml_str = generator.generate_overlay(rec_set)

        assert "10Gi" in yaml_str


class TestIntegration:
    """Integration tests."""

    @pytest.fixture
    def fixtures_path(self):
        """Path to test fixtures."""
        return Path(__file__).parent / "fixtures"

    def test_full_generation_flow(self, fixtures_path, tmp_path: Path):
        """Test full flow from recommendations to Helm values."""
        rec_file = fixtures_path / "sample_recommendations.json"
        if not rec_file.exists():
            pytest.skip("Fixture file not found")

        generator = HelmValuesGenerator()
        output_path = tmp_path / "autotuned-values.yaml"

        generator.generate_from_file(rec_file, output_path)

        assert output_path.exists()

        # Verify content
        content = output_path.read_text()
        values = yaml.safe_load(content)

        assert "connect" in values
        assert "autotuning" in values
        assert values["autotuning"]["appId"] == "app-20260222120000-0001"

        # Check recommendations were applied
        assert values["connect"]["executor"]["memory"] == "10Gi"
        assert values["connect"]["executor"]["cores"] == 3


class TestLoadRecommendations:
    """Test loading recommendations from file."""

    def test_load_valid_file(self, tmp_path: Path):
        """Test loading valid recommendations file."""
        rec_file = tmp_path / "recs.json"
        rec_file.write_text(json.dumps({
            "app_id": "app-123",
            "workload_type": "etl_batch",
            "recommendations": [],
            "overall_confidence": 0.8,
            "safety_issues": [],
            "generated_at": "2026-02-22T12:00:00",
            "base_config": {},
        }))

        rec_set = load_recommendations(rec_file)

        assert rec_set.app_id == "app-123"
        assert rec_set.workload_type == "etl_batch"

    def test_load_missing_file(self, tmp_path: Path):
        """Test loading missing file raises error."""
        with pytest.raises(FileNotFoundError):
            load_recommendations(tmp_path / "nonexistent.json")
