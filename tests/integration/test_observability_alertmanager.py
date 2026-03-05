"""Tests for charts/observability/alertmanager — WS-016-05 AC validation."""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
ALERTMANAGER_CHART = PROJECT_ROOT / "charts" / "observability" / "alertmanager"


def _helm_template() -> str:
    """Run helm template on observability alertmanager chart."""
    result = subprocess.run(
        ["helm", "template", "test", str(ALERTMANAGER_CHART)],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


def test_alertmanager_chart_renders() -> None:
    """AC1: AlertManager Helm chart renders valid YAML."""
    output = _helm_template()
    assert "alertmanager" in output.lower()
    assert "kind:" in output


def test_critical_alerts() -> None:
    """AC2: Critical alerts (pod crash, OOM)."""
    output = _helm_template()
    assert "critical" in output.lower()
    assert "CrashLoop" in output or "OOM" in output or "OOMKilled" in output


def test_warning_alerts() -> None:
    """AC3: Warning alerts (high GC, slow queries)."""
    output = _helm_template()
    assert "warning" in output.lower()
    assert "GC" in output or "HighGC" in output or "SlowQuery" in output or "ShuffleSpill" in output


def test_slack_receiver() -> None:
    """AC4: Slack notification configured."""
    output = _helm_template()
    assert "slack" in output.lower()


def test_inhibit_rules() -> None:
    """AC5: Alert silence/inhibit (inhibit_rules)."""
    output = _helm_template()
    assert "inhibit" in output.lower()


def test_prometheus_rule_present() -> None:
    """AC2/AC3/AC6: PrometheusRule or alert rules present."""
    output = _helm_template()
    assert "PrometheusRule" in output or "alert:" in output or "rules:" in output
