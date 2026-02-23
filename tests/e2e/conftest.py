"""Shared fixtures for E2E tests."""

from pathlib import Path

import pytest


@pytest.fixture(scope="class")
def helm_chart_path() -> Path:
    """Path to Helm chart."""
    return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"


@pytest.fixture(scope="class")
def environments_path(helm_chart_path: Path) -> Path:
    """Path to environments directory."""
    return helm_chart_path / "environments"
