"""
Credential leak detection tests (constitution §IV).

Verifies that known-bad default credentials (minioadmin, hive123) do NOT appear
in chart values, presets, or templates. These were stripped in the
credential-hardening spec; this test guards against regression.

Per constitution §V, this is a valid test: it executes a real assertion on the
source files (grep equivalent), not a mere Path.exists check.
"""

from pathlib import Path

import pytest

# Credentials that must never appear as default values in chart source.
# (They MAY appear in docs/recipes as illustrative examples, and in
# tests/evidence as frozen historical snapshots — both excluded below.)
FORBIDDEN_DEFAULTS = ["minioadmin", "hive123"]

# Directories where these strings are allowed (docs with warnings, historical
# evidence, this very test file, archived/frozen content).
ALLOWED_DIRS = (
    "docs/",
    "tests/evidence/",
    "specs/",
    ".git/",
    "dist/",
    "node_modules/",
)

# File extensions to scan (chart source: yaml + templates).
SCAN_EXTENSIONS = (".yaml", ".yml", ".tpl")


@pytest.fixture(scope="session")
def chart_source_files(repository_root: Path) -> list[Path]:
    """Collect chart source files (values, presets, templates) to scan."""
    charts_dir = repository_root / "charts"
    files: list[Path] = []
    if not charts_dir.exists():
        return files
    for ext in SCAN_EXTENSIONS:
        files.extend(charts_dir.rglob(f"*{ext}"))
    # Exclude vendored/archived subcharts and tgz-packed deps
    return [f for f in files if "/_archived/" not in str(f) and "/charts/charts/" not in str(f)]


def _is_in_allowed_context(file_path: Path, line: str) -> bool:
    """True if the match is in an allowed doc/evidence/test context."""
    s = str(file_path)
    if any(s.startswith(str(repository_root_global / d)) or f"/{d}" in s for d in ALLOWED_DIRS):
        return True
    # Allow docs/recipes and READMEs (illustrative)
    if "README" in s or "recipe" in s.lower() or "docs/" in s:
        return True
    # Allow commented-out lines (e.g. '# --set ...=minioadmin' showing what NOT to do)
    stripped = line.lstrip()
    return bool(stripped.startswith("#"))


repository_root_global: Path = Path(__file__).parent.parent.parent  # set for the helper


def test_no_hardcoded_default_credentials_in_chart_source(chart_source_files: list[Path]) -> None:
    """No forbidden default credential may appear as an active value in chart source.

    Active = not commented out, not in docs/README/recipe/evidence. Violations
    indicate a hardcoded default that violates constitution §IV.
    """
    global repository_root_global
    violations: list[str] = []

    for f in chart_source_files:
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(content.splitlines(), start=1):
            for cred in FORBIDDEN_DEFAULTS:
                if cred not in line:
                    continue
                if _is_in_allowed_context(f, line):
                    continue
                violations.append(f"{f}:{lineno}: found '{cred}' in active source: {line.strip()}")

    assert not violations, (
        "Hardcoded default credentials found in chart source (constitution §IV violation):\n"
        + "\n".join(violations)
        + "\n\nReplace with empty string + REQUIRED comment. See "
        "docs/recipes/security/credential-management.md and specs/credential-hardening/."
    )


def test_hive_metastore_password_required_when_enabled(repository_root: Path) -> None:
    """When hiveMetastore is enabled, the password must be supplied (no default).

    Tests against the spark-base chart (where the init-job + secret live), not
    the parent spark-3.5 chart (which delegates core.* to spark-base subchart).
    Uses helm template to confirm the `required` validator fires when the
    password is empty. This is a real helm invocation per constitution §V.
    """
    import subprocess

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
            # password intentionally NOT set
        ],
        capture_output=True,
        text=True,
        cwd=str(spark_base),
    )
    # Should fail (non-zero) with the required-validator message
    assert result.returncode != 0, (
        "hiveMetastore enabled without password must fail helm template (required validator), "
        "but it rendered successfully — the credential-hardening guard is missing."
    )
    combined = result.stderr + result.stdout
    assert (
        "hiveMetastore.postgresql.password is REQUIRED" in combined
    ), f"Expected REQUIRED error, got: {combined[:400]}"
