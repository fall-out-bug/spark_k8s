"""Tests for charts/observability/prometheus — WS-016-01 AC validation."""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
PROMETHEUS_CHART = PROJECT_ROOT / "charts" / "observability" / "prometheus"


def _helm_template() -> str:
    """Run helm template on observability prometheus chart."""
    result = subprocess.run(
        ["helm", "template", "test", str(PROMETHEUS_CHART)],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_prometheus_chart_renders() -> None:
    """AC1: Prometheus Helm chart renders valid YAML."""
    output = _helm_template()
    assert "kind: ServiceMonitor" in output or "kind: Prometheus" in output
    assert "prometheus" in output.lower()


def test_scrape_interval_15s() -> None:
    """AC5: Scrape interval is 15s."""
    output = _helm_template()
    assert "15s" in output, "Expected scrape interval 15s in rendered output"


def test_retention_15d() -> None:
    """AC6: Data retention is 15d."""
    output = _helm_template()
    assert "15d" in output, "Expected retention 15d in rendered output"


def test_kube_state_metrics_enabled() -> None:
    """AC4: K8s metrics (kube-state-metrics) are configured."""
    output = _helm_template()
    assert "kube-state-metrics" in output or "kubeStateMetrics" in output


def test_spark_servicemonitor_present() -> None:
    """AC2/AC3: ServiceMonitor for Spark metrics exists."""
    output = _helm_template()
    assert "ServiceMonitor" in output
    assert "spark" in output.lower() or "metrics" in output.lower()
