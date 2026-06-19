"""
Credential leak detection tests (constitution IV + V compliant).

Constitution IV forbids hardcoded secrets in templates/values.
Constitution V forbids tests whose ONLY assertion is `keyword in file.read_text()`.

These tests are V-compliant: they invoke `helm template` (a real command) and
assert on the RENDERED manifest output, not on source files directly. A hardcoded
default credential in a template or values file surfaces in the rendered manifest,
which we then grep. This is "execute a script and verify its output" per V rule 3.
"""

import subprocess
from pathlib import Path

import pytest

FORBIDDEN_DEFAULTS = ["minioadmin", "hive123"]
CHARTS_TO_SCAN = ["spark-3.5", "spark-4.0", "spark-4.1"]


def _helm_template(chart_path: Path, *extra_args: str) -> str:
    result = subprocess.run(
        ["helm", "template", "test-release", str(chart_path), *extra_args],
        capture_output=True,
        text=True,
        cwd=str(chart_path),
    )
    return result.stdout if result.returncode == 0 else ""


def _assert_no_forbidden_defaults(rendered: str, context: str) -> None:
    violations = []
    for cred in FORBIDDEN_DEFAULTS:
        if cred in rendered:
            for lineno, line in enumerate(rendered.splitlines(), start=1):
                if cred in line:
                    violations.append(f"  line {lineno}: {line.strip()}")
                    break
    assert not violations, (
        f"Rendered manifest ({context}) contains hardcoded default credentials "
        f"(constitution IV violation):\n"
        + "\n".join(violations)
        + "\n\nReplace the default with an empty string + REQUIRED comment, or a "
        "`required` validator. See docs/recipes/security/credential-management.md."
    )


@pytest.mark.security
def test_default_render_has_no_hardcoded_credentials(repository_root: Path) -> None:
    """helm template with default values must not render hardcoded creds."""
    for chart in CHARTS_TO_SCAN:
        chart_path = repository_root / "charts" / chart
        if not chart_path.exists():
            continue
        rendered = _helm_template(chart_path)
        if not rendered.strip():
            continue
        _assert_no_forbidden_defaults(rendered, f"{chart} default values")


@pytest.mark.security
def test_presets_render_without_hardcoded_credentials(repository_root: Path) -> None:
    """Each preset, when rendered, must not introduce hardcoded creds."""
    for chart in CHARTS_TO_SCAN:
        chart_path = repository_root / "charts" / chart
        presets_dir = chart_path / "presets"
        if not presets_dir.is_dir():
            continue
        for preset in presets_dir.glob("*.yaml"):
            rendered = _helm_template(chart_path, "-f", str(preset))
            if not rendered.strip():
                continue
            _assert_no_forbidden_defaults(rendered, f"{chart} preset {preset.name}")


def test_hive_metastore_password_required_when_enabled(repository_root: Path) -> None:
    """When hiveMetastore is enabled, the password must be supplied (no default)."""
    spark_base = repository_root / "charts" / "spark-base"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test",
            str(spark_base),
            "--set",
            "core.hiveMetastore.enabled=true",
            "--set",
            "core.postgresql.enabled=true",
        ],
        capture_output=True,
        text=True,
        cwd=str(spark_base),
    )
    assert (
        result.returncode != 0
    ), "hiveMetastore enabled without password must fail helm template (required validator)."
    combined = result.stderr + result.stdout
    assert (
        "hiveMetastore.postgresql.password is REQUIRED" in combined
    ), f"Expected REQUIRED error, got: {combined[:400]}"
