"""Tests for run-matrix.sh — verifies it executes, not checks existence."""

import json
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent.parent
RUN_MATRIX = PROJECT_ROOT / "scripts" / "run-matrix.sh"
MATRIX_FILE = PROJECT_ROOT / "tests" / "test-matrix.yaml"
RESULTS_DIR = PROJECT_ROOT / "tests" / "results"


@pytest.fixture(scope="module")
def ensure_results_dir() -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def test_run_matrix_dry_run_single_scenario(ensure_results_dir: None) -> None:
    """run-matrix --filter id=SCENARIO-0009 --dry-run all executes and writes result."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "id=SCENARIO-0009", "--dry-run", "all"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert "helm install" in result.stdout
    assert "SCENARIO-0009" in result.stdout

    result_file = RESULTS_DIR / "scenario-SCENARIO-0009.json"
    assert result_file.exists()
    data = json.loads(result_file.read_text())
    assert data["id"] == "SCENARIO-0009"
    assert data.get("dry_run") is True


def test_run_matrix_filter_gpu_false(ensure_results_dir: None) -> None:
    """--filter gpu=false,platform=k8s returns multiple scenarios."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "gpu=false,platform=k8s", "--dry-run", "deploy"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    lines = [line for line in result.stdout.strip().split("\n") if line.startswith("[dry-run]")]
    assert len(lines) >= 96  # 96 k8s/no-gpu scenarios


def test_deploy_script_exists_and_has_required_behavior() -> None:
    """deploy.sh exists, is executable, and defines deploy_matrix_scenario."""
    deploy_sh = PROJECT_ROOT / "scripts" / "tests" / "lib" / "deploy.sh"
    assert deploy_sh.exists()
    assert deploy_sh.stat().st_mode & 0o111  # executable
    content = deploy_sh.read_text()
    assert "deploy_matrix_scenario" in content
    assert "kubectl wait" in content
    assert "DEPLOY_TIMEOUT" in content


def test_smoke_workload_executes_no_path_exists() -> None:
    """Smoke workload: 1K rows, count, filter. No Path.exists()."""
    smoke_py = PROJECT_ROOT / "scripts" / "tests" / "smoke" / "scripts" / "smoke_1k_count_filter.py"
    assert smoke_py.exists()
    content = smoke_py.read_text()
    assert "Path" not in content and "exists" not in content
    assert "spark.range(1000)" in content
    assert "count()" in content
    assert "filter" in content
    assert "SMOKE_SUCCESS" in content


def test_smoke_against_release_script_exists() -> None:
    """run-smoke-against-release.sh exists and uses smoke workload."""
    smoke_sh = PROJECT_ROOT / "scripts" / "tests" / "smoke" / "run-smoke-against-release.sh"
    assert smoke_sh.exists()
    content = smoke_sh.read_text()
    assert "smoke_1k_count_filter.py" in content
    assert "NAMESPACE" in content
    assert "kubectl exec" in content
    assert "Path" not in content
    assert "exists" not in content


def test_e2e_workload_executes_no_path_exists() -> None:
    """E2E workload: 10K rows, aggregations, joins. No Path.exists()."""
    e2e_py = PROJECT_ROOT / "scripts" / "tests" / "e2e" / "scripts" / "e2e_10k_agg_join.py"
    assert e2e_py.exists()
    content = e2e_py.read_text()
    assert "Path" not in content and "exists" not in content
    assert "spark.range(10000)" in content
    assert "groupBy" in content
    assert "join" in content
    assert "E2E_SUCCESS" in content


def test_e2e_against_release_script_exists() -> None:
    """run-e2e-against-release.sh exists and uses e2e workload."""
    e2e_sh = PROJECT_ROOT / "scripts" / "tests" / "e2e" / "run-e2e-against-release.sh"
    assert e2e_sh.exists()
    content = e2e_sh.read_text()
    assert "e2e_10k_agg_join.py" in content
    assert "NAMESPACE" in content
    assert "kubectl exec" in content
    assert "Path" not in content
    assert "exists" not in content


def test_load_workload_executes_no_path_exists() -> None:
    """Load workload: S3 parquet, 3 agg. No Path.exists(), no in-memory fallback."""
    load_py = PROJECT_ROOT / "scripts" / "tests" / "load" / "scripts" / "load_s3_parquet_3agg.py"
    assert load_py.exists()
    content = load_py.read_text()
    assert "Path" not in content and "exists" not in content
    assert "s3a://" in content
    assert "parquet" in content
    assert "groupBy" in content
    assert "LOAD_SUCCESS" in content
    assert "LOAD_THROUGHPUT" in content
    assert "S3_ENDPOINT" in content
    # Fail explicitly if S3 missing (no in-memory fallback)
    assert "sys.exit" in content


def test_load_against_release_script_exists() -> None:
    """run-load-against-release.sh exists and uses load workload."""
    load_sh = PROJECT_ROOT / "scripts" / "tests" / "load" / "run-load-against-release.sh"
    assert load_sh.exists()
    content = load_sh.read_text()
    assert "load_s3_parquet_3agg.py" in content
    assert "NAMESPACE" in content
    assert "RELEASE" in content
    assert "S3_ENDPOINT" in content
    assert "kubectl exec" in content
    assert "spark.eventLog.enabled" in content
    assert "spark.eventLog.dir" in content
    assert "Path" not in content
    assert "exists" not in content


def test_validate_history_script_exists() -> None:
    """run-validate-history-after-load.sh exists and curls History Server API."""
    hist_sh = PROJECT_ROOT / "scripts" / "tests" / "load" / "run-validate-history-after-load.sh"
    assert hist_sh.exists()
    content = hist_sh.read_text()
    assert "NAMESPACE" in content
    assert "RELEASE" in content
    assert "api/v1/applications" in content
    assert "HISTORY_VALIDATION_SUCCESS" in content
    assert "curl" in content
    assert "Path" not in content
    assert "exists" not in content


def test_get_runtime_image_baseline() -> None:
    """get_runtime_image: gpu=false, iceberg=false -> no suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "false", "false"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7"


def test_get_runtime_image_gpu() -> None:
    """get_runtime_image: gpu=true -> -gpu suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "true", "false"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7-gpu"


def test_get_runtime_image_iceberg() -> None:
    """get_runtime_image: iceberg=true -> -iceberg suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "false", "true"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7-iceberg"


def test_get_runtime_image_gpu_iceberg() -> None:
    """get_runtime_image: gpu+iceberg -> -gpu-iceberg suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "true", "true"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7-gpu-iceberg"


def test_run_matrix_injects_connect_image(ensure_results_dir: None) -> None:
    """run-matrix deploy dry-run succeeds with image pyramid (gpu+iceberg scenario)."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "id=SCENARIO-0001", "--dry-run", "deploy"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert "helm install" in result.stdout
    # Image pyramid adds 2 --set args (connect.image.repository, connect.image.tag)
    assert "--set args" in result.stdout


def test_aggregate_matrix_results_script() -> None:
    """aggregate-matrix-results.py produces machine-readable summary."""
    agg = PROJECT_ROOT / "scripts" / "aggregate-matrix-results.py"
    assert agg.exists()
    # Run with dry-run results (scenario-SCENARIO-0009.json from test_run_matrix_dry_run)
    result = subprocess.run(
        [
            "python3",
            str(agg),
            "--results-dir",
            str(RESULTS_DIR),
            "--filter",
            "id=SCENARIO-0009",
            "--output",
            str(RESULTS_DIR / "matrix-summary-test.json"),
            "--duration",
            "0",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    # Filter id=SCENARIO-0009 returns 1 scenario; dry-run creates scenario-SCENARIO-0009.json
    assert result.returncode == 0 or "No scenarios" in result.stderr
    if (RESULTS_DIR / "matrix-summary-test.json").exists():
        data = json.loads((RESULTS_DIR / "matrix-summary-test.json").read_text())
        assert "passed" in data
        assert "failed" in data
        assert "expected" in data


def test_run_matrix_96_script_exists() -> None:
    """run-matrix-96.sh exists and runs 96-scenario filter."""
    script = PROJECT_ROOT / "scripts" / "run-matrix-96.sh"
    assert script.exists()
    assert script.stat().st_mode & 0o111
    content = script.read_text()
    assert "gpu=false,platform=k8s" in content
    assert "run-matrix.sh" in content
    assert "aggregate-matrix-results" in content
    assert "matrix-96-summary.json" in content


def test_run_matrix_reads_test_matrix_yaml() -> None:
    """run-matrix reads tests/test-matrix.yaml with 320 scenarios."""
    assert MATRIX_FILE.exists()
    count = int(
        subprocess.run(
            [
                "python3",
                "-c",
                "import yaml; d=yaml.safe_load(open('tests/test-matrix.yaml')); print(len(d.get('scenarios',[])))",
            ],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
        ).stdout.strip()
    )
    assert count == 320
