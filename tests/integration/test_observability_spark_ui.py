"""Tests for Spark UI observability integration — WS-016-06 AC validation.

Uses helm template + YAML assertions (no live cluster required).
"""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
SPARK_CHART = PROJECT_ROOT / "charts" / "spark-3.5"
GRAFANA_CHART = PROJECT_ROOT / "charts" / "observability" / "grafana"


def _helm_template_spark(values_file: str | None = None, sets: list[str] | None = None) -> str:
    """Run helm template on spark-3.5 chart."""
    cmd = ["helm", "template", "test", str(SPARK_CHART)]
    if values_file:
        cmd.extend(["-f", str(PROJECT_ROOT / values_file)])
    if sets:
        for s in sets:
            cmd.extend(["--set", s])
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(PROJECT_ROOT))
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def _helm_template_grafana() -> str:
    """Run helm template on grafana chart."""
    result = subprocess.run(
        ["helm", "template", "test", str(GRAFANA_CHART)],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_spark_chart_renders_with_observability() -> None:
    """AC1/AC6: Spark chart renders when historyServer.observability enabled."""
    output = _helm_template_spark(
        sets=[
            "historyServer.enabled=true",
            "historyServer.observability.enabled=true",
            "global.s3.enabled=true",
        ]
    )
    assert "history-server" in output.lower() or "history" in output.lower()


def test_history_server_servicemonitor_when_metrics_enabled() -> None:
    """AC1: ServiceMonitor for History Server when observability.metrics enabled."""
    output = _helm_template_spark(
        sets=[
            "historyServer.enabled=true",
            "historyServer.observability.enabled=true",
            "historyServer.observability.metrics.enabled=true",
            "global.s3.enabled=true",
        ]
    )
    assert "kind: ServiceMonitor" in output
    assert "history" in output.lower()
    assert "18080" in output or "metrics" in output.lower()


def test_history_server_jaeger_env_when_tracing_enabled() -> None:
    """AC2: Jaeger UI URL env var when observability.tracing enabled."""
    output = _helm_template_spark(
        sets=[
            "historyServer.enabled=true",
            "historyServer.observability.enabled=true",
            "historyServer.observability.tracing.enabled=true",
            "historyServer.observability.tracing.jaegerUrl=http://jaeger:16686",
            "global.s3.enabled=true",
        ]
    )
    assert "JAEGER" in output or "jaeger" in output
    assert "16686" in output


def test_history_server_loki_env_when_logging_enabled() -> None:
    """AC4: Loki URL env var when observability.logging enabled."""
    output = _helm_template_spark(
        sets=[
            "historyServer.enabled=true",
            "historyServer.observability.enabled=true",
            "historyServer.observability.logging.enabled=true",
            "historyServer.observability.logging.lokiUrl=http://loki:3100",
            "global.s3.enabled=true",
        ]
    )
    assert "LOKI" in output or "loki" in output
    assert "3100" in output


def test_grafana_spark_overview_dashboard() -> None:
    """AC5: Unified observability view - spark-overview dashboard in Grafana."""
    output = _helm_template_grafana()
    assert "spark-overview" in output.lower() or "spark_overview" in output.lower()


def test_grafana_datasources_prometheus_loki_jaeger() -> None:
    """AC5: Grafana has Prometheus, Loki, Jaeger datasources for unified view."""
    output = _helm_template_grafana()
    assert "Prometheus" in output
    assert "Loki" in output
    assert "Jaeger" in output
