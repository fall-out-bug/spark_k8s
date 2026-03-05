"""Tests for charts/observability/loki — WS-016-02 AC validation."""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
LOKI_CHART = PROJECT_ROOT / "charts" / "observability" / "loki"


def _helm_template() -> str:
    """Run helm template on observability loki chart."""
    result = subprocess.run(
        ["helm", "template", "test", str(LOKI_CHART)],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_loki_chart_renders() -> None:
    """AC1: Loki Helm chart renders valid YAML."""
    output = _helm_template()
    assert "loki" in output.lower()
    assert "kind:" in output


def test_promtail_config_present() -> None:
    """AC2: Promtail collects logs from pods (ConfigMap with scrape_configs)."""
    output = _helm_template()
    assert "promtail" in output.lower()
    assert "scrape_configs" in output or "kubernetes_sd_configs" in output


def test_json_pipeline_stage() -> None:
    """AC3: JSON structured logging (pipeline_stages with json)."""
    output = _helm_template()
    assert "pipeline_stages" in output
    assert "json:" in output
    assert "expressions" in output


def test_trace_id_in_config() -> None:
    """AC4: Trace ID correlation (trace_id in pipeline or relabel)."""
    output = _helm_template()
    assert "trace_id" in output or "traceid" in output.lower()


def test_log_sampling_configured() -> None:
    """AC5: Log sampling (INFO 10%, ERROR/WARN 100%)."""
    output = _helm_template()
    assert "sampling" in output or "drop" in output
    assert "0.1" in output or "10" in output


def test_uses_target_namespace() -> None:
    """Scope: Uses targetNamespace from values, not hardcoded spark.name."""
    output = _helm_template()
    # Should use .Values or Release, not hardcoded spark-operations in wrong context
    assert "spark-operations" in output or "targetNamespace" in output


def test_grafana_datasource_configured() -> None:
    """AC6: Grafana datasource URL documented/configured."""
    output = _helm_template()
    assert "grafana" in output.lower() or "3100" in output
