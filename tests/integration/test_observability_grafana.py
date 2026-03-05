"""Tests for charts/observability/grafana — WS-016-04 AC validation."""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
GRAFANA_CHART = PROJECT_ROOT / "charts" / "observability" / "grafana"


def _helm_template() -> str:
    """Run helm template on observability grafana chart."""
    result = subprocess.run(
        ["helm", "template", "test", str(GRAFANA_CHART)],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_grafana_chart_renders() -> None:
    """AC1: Grafana Helm chart renders valid YAML."""
    output = _helm_template()
    assert "grafana" in output.lower()
    assert "kind:" in output


def test_prometheus_datasource() -> None:
    """AC2: Prometheus datasource configured."""
    output = _helm_template()
    assert "Prometheus" in output
    assert "prometheus" in output.lower()
    assert "9090" in output


def test_loki_datasource() -> None:
    """AC3: Loki datasource configured."""
    output = _helm_template()
    assert "Loki" in output
    assert "loki" in output.lower()
    assert "3100" in output


def test_jaeger_datasource() -> None:
    """AC4: Jaeger datasource configured."""
    output = _helm_template()
    assert "Jaeger" in output
    assert "jaeger" in output.lower()
    assert "16686" in output


def test_five_plus_dashboards() -> None:
    """AC5: 5+ dashboards created/provisioned."""
    output = _helm_template()
    # Count dashboard ConfigMaps or .json references
    dashboard_count = output.count(".json:") + output.count("dashboards-")
    assert dashboard_count >= 5, f"Expected 5+ dashboards, found {dashboard_count}"


def test_dashboard_providers() -> None:
    """AC6: Dashboards auto-provision (dashboardProviders configured)."""
    output = _helm_template()
    assert "dashboardproviders" in output.lower() or "dashboardProviders" in output
    assert "/var/lib/grafana/dashboards" in output or "dashboards" in output.lower()
