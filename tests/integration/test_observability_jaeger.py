"""Tests for charts/observability/jaeger — WS-016-03 AC validation."""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
JAEGER_CHART = PROJECT_ROOT / "charts" / "observability" / "jaeger"


def _helm_template() -> str:
    """Run helm template on observability jaeger chart."""
    result = subprocess.run(
        ["helm", "template", "test", str(JAEGER_CHART)],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_jaeger_chart_renders() -> None:
    """AC1: Jaeger Helm chart renders valid YAML."""
    output = _helm_template()
    assert "jaeger" in output.lower()
    assert "kind:" in output


def test_otlp_port_exposed() -> None:
    """AC2: OpenTelemetry OTLP port 4317 exposed for Spark."""
    output = _helm_template()
    assert "4317" in output


def test_jaeger_ui_port() -> None:
    """AC6: Jaeger UI available (port 16686)."""
    output = _helm_template()
    assert "16686" in output


def test_spark_endpoint_documented() -> None:
    """AC2/AC3: Spark OTLP endpoint documented for trace propagation."""
    output = _helm_template()
    assert "4317" in output
    assert "jaeger" in output.lower() or "otlp" in output.lower()


def test_deployment_or_service_present() -> None:
    """AC1: Jaeger deployment or service exists."""
    output = _helm_template()
    assert "Deployment" in output or "Service" in output
    assert "jaeger" in output.lower()


def test_spark_otel_configmap() -> None:
    """AC2/AC5: Spark OTel ConfigMap with endpoint and 10% sampling."""
    output = _helm_template()
    assert "spark-otel-endpoint" in output
    assert "0.1" in output
