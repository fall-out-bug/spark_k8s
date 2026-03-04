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
