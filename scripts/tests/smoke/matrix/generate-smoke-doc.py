#!/usr/bin/env python3
"""Generate smoke-test-matrix.md visualization from smoke-matrix.yaml.

Reads scripts/tests/smoke/matrix/smoke-matrix.yaml, renders P0/P1/P2
tier tables as markdown. Output: docs/smoke-test-matrix.md.

Usage:
    python3 scripts/tests/smoke/matrix/generate-smoke-doc.py
    python3 scripts/tests/smoke/matrix/generate-smoke-doc.py --check  # exit 1 if drift
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[4]
MATRIX_YAML = ROOT / "scripts/tests/smoke/matrix/smoke-matrix.yaml"
OUTPUT_MD = ROOT / "docs/smoke-test-matrix.md"


def load_matrix() -> dict[str, Any]:
    with MATRIX_YAML.open() as f:
        return yaml.safe_load(f)


def tier_count(matrix: dict[str, Any], tier: str) -> int:
    t = matrix["matrix"]["priority_tiers"][tier]
    n = len(t["components"]) * len(t["spark_versions"]) * len(t["modes"]) * len(t["features"])
    return n


def render_dimension_table(matrix: dict[str, Any]) -> str:
    dims = matrix["matrix"]["dimensions"]
    lines = [
        "| Dimension | Values | Count |",
        "|-----------|--------|-------|",
        f"| Components | {', '.join(d['name'] for d in dims['components'])} | {len(dims['components'])} |",
        f"| Spark Versions | {', '.join(d['version'] for d in dims['spark_versions'])} | {len(dims['spark_versions'])} |",
        f"| Modes | {', '.join(d['name'] for d in dims['modes'])} | {len(dims['modes'])} |",
        f"| Features | {', '.join(d['name'] for d in dims['features'])} | {len(dims['features'])} |",
    ]
    return "\n".join(lines)


def render_tier_table(matrix: dict[str, Any]) -> str:
    tiers = matrix["matrix"]["priority_tiers"]
    lines = [
        "| Tier | Purpose | Timeout | Components | Versions | Modes | Features | Scenarios |",
        "|------|---------|---------|------------|----------|-------|----------|-----------|",
    ]
    for key, t in tiers.items():
        n = tier_count(matrix, key)
        lines.append(
            f"| {key} | {t['description']} | {t['timeout_minutes']}m | "
            f"{len(t['components'])} | {len(t['spark_versions'])} | {len(t['modes'])} | "
            f"{len(t['features'])} | **{n}** |"
        )
    return "\n".join(lines)


def render_p1_grid(matrix: dict[str, Any]) -> str:
    """Render P1 nightly scenarios grid: components × versions × modes × features."""
    dims = matrix["matrix"]["dimensions"]
    versions = [d["version"] for d in dims["spark_versions"]]
    features = [d["name"] for d in dims["features"]]
    modes = ["k8s", "standalone"]
    components = ["jupyter", "airflow", "spark-submit"]

    lines = [
        f"### P1 Nightly — {tier_count(matrix, 'p1_nightly')} scenarios",
        "",
        "Matrix slice: components (3) × spark_versions (4) × modes (2) × features (4) = 96.",
        "",
    ]
    for comp in components:
        lines.append(f"#### {comp}")
        lines.append("")
        lines.append("| Mode | " + " | ".join(versions) + " |")
        lines.append("|------|" + "|".join(["------"] * len(versions)) + "|")
        for mode in modes:
            row = [f"`{mode}`"]
            for _v in versions:
                row.append("see `scripts/tests/smoke/scenarios/`")
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")
        lines.append(f"Features per cell: {', '.join(features)}")
        lines.append("")
    return "\n".join(lines)


def render_yaml_pointer() -> str:
    return (
        "> **Source of truth**: [`scripts/tests/smoke/matrix/smoke-matrix.yaml`]"
        "(../scripts/tests/smoke/matrix/smoke-matrix.yaml). "
        "This document is auto-generated. Do not edit by hand — run "
        "`python3 scripts/tests/smoke/matrix/generate-smoke-doc.py`."
    )


def render_doc(matrix: dict[str, Any]) -> str:
    sections = [
        "# Smoke Test Matrix",
        "",
        render_yaml_pointer(),
        "",
        "Full smoke matrix: 3 components × 4 spark versions × 3 modes × 4 features = **144 scenarios**.",
        "",
        "## Dimensions",
        "",
        render_dimension_table(matrix),
        "",
        "## Priority Tiers",
        "",
        render_tier_table(matrix),
        "",
        "## MANDATORY Requirements (all scenarios)",
        "",
        "All smoke tests MUST include:",
        "",
        "1. **S3 for Event Log** — all Spark job logs persisted to S3",
        "2. **History Server** — deployed, reads logs from S3",
        "3. **MinIO** — S3-compatible storage for local testing",
        "",
        "```yaml",
        "global:",
        "  s3:",
        "    enabled: true",
        '    endpoint: "http://minio:9000"',
        "    pathStyleAccess: true",
        "    sslEnabled: false",
        "",
        "connect:  # or jupyter, spark-submit",
        "  eventLog:",
        "    enabled: true",
        '    dir: "s3a://spark-logs/{version}/events"',
        "",
        "historyServer:",
        "  enabled: true",
        '  provider: "s3"',
        "  s3:",
        '    endpoint: "http://minio:9000"',
        "```",
        "",
        "## Scenario Naming",
        "",
        "Pattern: `{component}-{feature_suffix}{mode}-{spark_version_short}.sh`",
        "",
        "Examples:",
        "- `airflow-connect-k8s-357.sh` (airflow, baseline, k8s, 3.5.7)",
        "- `jupyter-gpu-k8s-410.sh` (jupyter, gpu, k8s, 4.1.0)",
        "- `spark-submit-iceberg-standalone-411.sh` (spark-submit, iceberg, standalone, 4.1.1)",
        "",
        "## P0 (PR gate)",
        "",
        f"**{tier_count(matrix, 'p0_pr')} scenarios** — fast feedback, baseline only.",
        "",
        "## P1 (Nightly)",
        "",
        render_p1_grid(matrix),
        "## P2 (Weekly)",
        "",
        f"**{tier_count(matrix, 'p2_weekly')} scenarios** — full matrix incl. connect mode.",
        "",
        "## Image Pyramid",
        "",
        "`scripts/tests/lib/get_runtime_image.sh` resolves image tag:",
        "",
        "```",
        "spark-custom:3.5.7|3.5.8|4.1.0|4.1.1 (base)",
        "  → spark-k8s-runtime:<short>-7-{image_suffix}",
        "  → spark-k8s-jupyter:<short>-7-{image_suffix}",
        "```",
        "",
        "## CI Integration",
        "",
        "| Tier | Workflow | Trigger |",
        "|------|----------|---------|",
        "| P0 | `.github/workflows/ci-matrix-p0.yml` | `pull_request` |",
        "| P1 | `.github/workflows/ci-matrix-p1.yml` | `schedule: nightly` |",
        "| P2 | `.github/workflows/ci-matrix-p2.yml` | `schedule: weekly` |",
        "",
        "_Auto-generated from `smoke-matrix.yaml`. Last regenerated: see git blame._",
    ]
    return "\n".join(sections) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit 1 if doc drifts from yaml")
    args = parser.parse_args()

    matrix = load_matrix()
    rendered = render_doc(matrix)

    if args.check:
        existing = OUTPUT_MD.read_text() if OUTPUT_MD.exists() else ""
        if existing.strip() != rendered.strip():
            print(f"DRIFT: {OUTPUT_MD} out of sync with smoke-matrix.yaml", file=sys.stderr)
            return 1
        print("OK: smoke-test-matrix.md in sync")
        return 0

    OUTPUT_MD.write_text(rendered)
    print(f"Wrote {OUTPUT_MD} ({len(rendered.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
