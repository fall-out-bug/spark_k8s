"""Tests for charts/observability-demo — umbrella chart for demo."""

import subprocess
from pathlib import Path

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
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_observability_demo_chart_renders() -> None:
    """observability-demo umbrella chart renders valid YAML."""
    output = _helm_template()
    assert "kind: ServiceMonitor" in output or "kind: Prometheus" in output
    assert "observability-demo" in output


def test_demo_metrics_servicemonitor_present() -> None:
    """ServiceMonitor for demo-metrics-exporter exists."""
    output = _helm_template()
    assert "demo-metrics-exporter" in output
    assert "ServiceMonitor" in output


def test_demo_metrics_exporter_deployment_present() -> None:
    """demo-metrics-exporter Deployment exists when enabled."""
    output = _helm_template()
    assert "name: demo-metrics-exporter" in output
    assert "demo-metrics-exporter-script" in output


def test_otel_collector_present() -> None:
    """OTEL Collector Deployment exists when enabled."""
    output = _helm_template()
    assert "name: otel-collector" in output
    assert "otel-collector-config" in output
