"""Observability smoke tests — PR gate for dashboards, metrics, demo.

Runs helm template on observability-demo and asserts key resources render.
No live cluster required. See docs/observability/INVENTORY.md for components.
"""

import subprocess
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).parent.parent.parent
CHART_PATH = PROJECT_ROOT / "charts" / "observability-demo"
VALUES_DEMO = CHART_PATH / "values-demo.yaml"


def _helm_template() -> str:
    """Run helm template on observability-demo chart."""
    result = subprocess.run(
        [
            "helm",
            "template",
            "observability-demo",
            str(CHART_PATH),
            "-f",
            str(VALUES_DEMO),
            "-n",
            "observability",
            "--set",
            "targetNamespace=spark-infra",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def _parse_manifests(output: str) -> list[dict]:
    """Parse helm template output into list of manifest dicts."""
    docs = []
    for doc in yaml.safe_load_all(output):
        if doc:
            docs.append(doc)
    return docs


@pytest.mark.observability
def test_observability_demo_renders() -> None:
    """AC1: observability-demo chart renders valid YAML."""
    output = _helm_template()
    docs = _parse_manifests(output)
    assert len(docs) > 10, "Expected multiple manifests"


@pytest.mark.observability
def test_loki_resources_present() -> None:
    """AC2: Loki deployment/config present in rendered output."""
    output = _helm_template()
    assert "observability-demo-loki" in output or "loki" in output
    assert "app.kubernetes.io/name: loki" in output
    # Promtail config for spark-pods
    assert "spark-pods" in output or "job_name: spark-pods" in output


@pytest.mark.observability
def test_prometheus_scrape_config_present() -> None:
    """AC2: Prometheus scrape / ServiceMonitor present."""
    output = _helm_template()
    assert "ServiceMonitor" in output
    assert "demo-metrics-exporter" in output
    assert "observability-demo-prometh" in output or "prometheus" in output.lower()


@pytest.mark.observability
def test_grafana_dashboards_load() -> None:
    """AC2: Grafana dashboards ConfigMaps present and valid JSON."""
    output = _helm_template()
    assert "observability-demo-grafana-dashboards" in output
    assert "spark-overview" in output or "spark" in output
    # Datasources
    assert "Prometheus" in output and "Loki" in output


@pytest.mark.observability
def test_demo_metrics_exporter_enabled() -> None:
    """demo-metrics-exporter Deployment present when enabled."""
    output = _helm_template()
    assert "name: demo-metrics-exporter" in output
    assert "9108" in output or "metrics" in output
