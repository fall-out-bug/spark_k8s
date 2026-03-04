"""Shared helpers for test matrix validation."""

from pathlib import Path

import yaml


def load_matrix() -> dict:
    """Load test-matrix.yaml from tests directory."""
    path = Path(__file__).resolve().parent.parent / "test-matrix.yaml"
    with path.open() as f:
        return yaml.safe_load(f)


def apply_filter(scenarios: list, filter_str: str) -> list:
    """Replicate run-matrix.sh get_scenarios filter logic."""
    if not filter_str:
        return scenarios
    result = scenarios
    for part in filter_str.split(","):
        key, value = part.split("=", 1)
        key = key.strip()
        value = value.strip()
        if value.lower() == "true":
            result = [s for s in result if s.get(key) is True]
        elif value.lower() == "false":
            result = [s for s in result if s.get(key) is False]
        else:
            result = [s for s in result if str(s.get(key, "")).lower() == value.lower()]
    return result
