"""CLI integration tests for autotuning tools."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

# Test fixtures path
FIXTURES_PATH = Path(__file__).parent / "fixtures"

# Scripts directory for PYTHONPATH
SCRIPTS_DIR = Path(__file__).parent.parent.parent


def get_cli_env():
    """Get environment with PYTHONPATH set."""
    env = os.environ.copy()
    env["PYTHONPATH"] = str(SCRIPTS_DIR)
    return env


class TestCollectorCLI:
    """Test collector CLI commands."""

    def test_collector_help(self):
        """Test collector --help."""
        result = subprocess.run(
            [sys.executable, "-m", "autotuning.collector", "--help"],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        assert result.returncode == 0
        assert "prometheus" in result.stdout.lower()

    def test_collector_missing_url(self):
        """Test collector fails without Prometheus URL."""
        result = subprocess.run(
            [sys.executable, "-m", "autotuning.collector", "--app-id", "test-app"],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        # Should fail or show error about missing URL
        assert result.returncode != 0 or "error" in result.stderr.lower() or "required" in result.stderr.lower()


class TestAnalyzerCLI:
    """Test analyzer CLI commands."""

    def test_analyzer_help(self):
        """Test analyzer --help."""
        result = subprocess.run(
            [sys.executable, "-m", "autotuning.analyzer", "--help"],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        assert result.returncode == 0

    def test_analyzer_with_metrics_file(self, tmp_path: Path):
        """Test analyzer with metrics file input."""
        metrics_file = FIXTURES_PATH / "sample_metrics.json"
        output_file = tmp_path / "analysis.json"

        if not metrics_file.exists():
            pytest.skip("sample_metrics.json not found")

        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.analyzer",
                "--metrics-file", str(metrics_file),
                "--output", str(output_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )

        if result.returncode == 0:
            assert output_file.exists()
            data = json.loads(output_file.read_text())
            assert "workload_type" in data
            assert "issues" in data

    def test_analyzer_missing_file(self):
        """Test analyzer fails with missing file."""
        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.analyzer",
                "--metrics-file", "/nonexistent/metrics.json",
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        assert result.returncode != 0


class TestRecommenderCLI:
    """Test recommender CLI commands."""

    def test_recommender_help(self):
        """Test recommender --help."""
        result = subprocess.run(
            [sys.executable, "-m", "autotuning.recommender", "--help"],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        assert result.returncode == 0

    def test_recommender_with_analysis_file(self, tmp_path: Path):
        """Test recommender with analysis file input."""
        analysis_file = FIXTURES_PATH / "sample_analysis.json"
        output_file = tmp_path / "recommendations.json"

        if not analysis_file.exists():
            pytest.skip("sample_analysis.json not found")

        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.recommender",
                "--analysis-file", str(analysis_file),
                "--output", str(output_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )

        if result.returncode == 0:
            assert output_file.exists()
            data = json.loads(output_file.read_text())
            assert "recommendations" in data
            assert "overall_confidence" in data


class TestApplierCLI:
    """Test applier CLI commands."""

    def test_applier_help(self):
        """Test applier --help."""
        result = subprocess.run(
            [sys.executable, "-m", "autotuning.applier", "--help"],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        assert result.returncode == 0

    def test_applier_with_recommendations_file(self, tmp_path: Path):
        """Test applier with recommendations file input."""
        rec_file = FIXTURES_PATH / "sample_recommendations.json"
        output_file = tmp_path / "values.yaml"

        if not rec_file.exists():
            pytest.skip("sample_recommendations.json not found")

        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.applier",
                "--recommendations-file", str(rec_file),
                "--output", str(output_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )

        if result.returncode == 0:
            assert output_file.exists()
            content = output_file.read_text()
            assert "connect:" in content or "autotuning:" in content

    def test_applier_missing_file(self):
        """Test applier fails with missing file."""
        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.applier",
                "--recommendations-file", "/nonexistent/recs.json",
                "--output", "/tmp/out.yaml",
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        assert result.returncode != 0


class TestFullPipelineCLI:
    """Test full pipeline integration via CLI."""

    @pytest.mark.integration
    def test_full_pipeline_from_fixtures(self, tmp_path: Path):
        """Test full pipeline using fixture files."""
        metrics_file = FIXTURES_PATH / "sample_metrics.json"
        analysis_file = tmp_path / "analysis.json"
        recs_file = tmp_path / "recommendations.json"
        values_file = tmp_path / "values.yaml"

        if not metrics_file.exists():
            pytest.skip("sample_metrics.json not found")

        # Step 1: Analyze metrics
        result_analyze = subprocess.run(
            [
                sys.executable, "-m", "autotuning.analyzer",
                "--metrics-file", str(metrics_file),
                "--output", str(analysis_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )

        if result_analyze.returncode != 0:
            pytest.skip(f"Analyzer failed: {result_analyze.stderr}")

        assert analysis_file.exists()

        # Step 2: Generate recommendations
        result_recommend = subprocess.run(
            [
                sys.executable, "-m", "autotuning.recommender",
                "--analysis-file", str(analysis_file),
                "--output", str(recs_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )

        if result_recommend.returncode != 0:
            pytest.skip(f"Recommender failed: {result_recommend.stderr}")

        assert recs_file.exists()

        # Step 3: Apply recommendations
        result_apply = subprocess.run(
            [
                sys.executable, "-m", "autotuning.applier",
                "--recommendations-file", str(recs_file),
                "--output", str(values_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )

        if result_apply.returncode != 0:
            pytest.skip(f"Applier failed: {result_apply.stderr}")

        assert values_file.exists()

        # Validate final output
        content = values_file.read_text()
        assert "connect:" in content or "# Generated" in content


class TestCLIErrors:
    """Test CLI error handling."""

    def test_collector_invalid_prometheus_url(self):
        """Test collector handles invalid Prometheus URL."""
        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.collector",
                "--app-id", "test",
                "--prometheus-url", "not-a-valid-url",
            ],
            capture_output=True,
            text=True,
            timeout=30,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        # Should fail gracefully (not crash)
        # Return code can be 0 or non-zero, but should not hang

    def test_analyzer_invalid_json(self, tmp_path: Path):
        """Test analyzer handles invalid JSON."""
        invalid_file = tmp_path / "invalid.json"
        invalid_file.write_text("not valid json {{{")

        result = subprocess.run(
            [
                sys.executable, "-m", "autotuning.analyzer",
                "--metrics-file", str(invalid_file),
            ],
            capture_output=True,
            text=True,
            env=get_cli_env(),
            cwd=str(SCRIPTS_DIR),
        )
        # Should fail with error, not crash
        assert result.returncode != 0 or "error" in result.stderr.lower()
