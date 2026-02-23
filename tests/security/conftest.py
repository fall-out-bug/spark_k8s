"""
Security test fixtures for Spark K8s Helm charts

This module provides shared fixtures for all security tests.
"""

import pytest
import subprocess
import yaml
from pathlib import Path
from typing import Dict, Any, List


@pytest.fixture(scope="session")
def repository_root() -> Path:
    """Get the repository root directory"""
    # Start from current file and go up to repository root
    current = Path(__file__).parent
    while current.parent != current:
        if (current / "charts").exists():
            return current
        current = current.parent
    # Fallback
    return Path(__file__).parent.parent.parent


@pytest.fixture(scope="session")
def chart_35_path(repository_root: Path) -> Path:
    """Get path to Spark 3.5 chart"""
    return repository_root / "charts" / "spark-3.5"


@pytest.fixture(scope="session")
def chart_41_path(repository_root: Path) -> Path:
    """Get path to Spark 4.1 chart"""
    return repository_root / "charts" / "spark-4.1"


@pytest.fixture(scope="session")
def preset_35_baseline(chart_35_path: Path) -> Path:
    """Get path to Spark 3.5 baseline preset"""
    return chart_35_path / "presets" / "core-baseline.yaml"


@pytest.fixture(scope="session")
def preset_41_baseline(chart_41_path: Path) -> Path:
    """Get path to Spark 4.1 baseline preset"""
    return chart_41_path / "presets" / "core-baseline.yaml"


def helm_template(chart_path: Path, values_files: List[Path] = None,
                 set_values: Dict[str, str] = None) -> str:
    """
    Run helm template command and return output.

    Args:
        chart_path: Path to Helm chart
        values_files: List of values files to include
        set_values: Dict of --set values

    Returns:
        Rendered YAML output or None if failed
    """
    cmd = ["helm", "template", "test-release", str(chart_path)]

    if values_files:
        for values_file in values_files:
            cmd.extend(["-f", str(values_file)])

    # Add common workarounds for chart template issues
    set_values = set_values or {}
    default_sets = {
        "vpa.enabled": "false",
        "keda.enabled": "false",
        "hpa.enabled": "false",
        "budget.enabled": "false",
        "costExporter.enabled": "false",
    }
    for key, value in default_sets.items():
        if key not in set_values:
            set_values[key] = value

    for key, value in set_values.items():
        cmd.extend(["--set", f"{key}={value}"])

    # Run from chart directory for correct template resolution
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(chart_path))

    if result.returncode != 0:
        return None

    return result.stdout


def parse_yaml_docs(yaml_content: str) -> List[Dict[str, Any]]:
    """
    Parse YAML content containing multiple documents.

    Args:
        yaml_content: YAML string with potential multiple documents

    Returns:
        List of parsed YAML documents
    """
    if not yaml_content:
        return []
    return [doc for doc in yaml.safe_load_all(yaml_content) if doc]


def get_pod_specs(yaml_content: str) -> List[Dict[str, Any]]:
    """
    Extract pod specs from rendered YAML.

    Args:
        yaml_content: Rendered YAML from helm template

    Returns:
        List of dict with kind, name, and spec
    """
    docs = parse_yaml_docs(yaml_content)
    pod_specs = []

    for doc in docs:
        if not doc:
            continue
        kind = doc.get("kind", "")
        if kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "Pod"]:
            template = doc.get("spec", {}).get("template", {})
            spec = template.get("spec", {})
            pod_specs.append({
                "kind": kind,
                "name": doc.get("metadata", {}).get("name", "unknown"),
                "spec": spec
            })

    return pod_specs
