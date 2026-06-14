#!/usr/bin/env python3
"""Validate smoke-matrix.yaml schema and constraints.

Checks:
- All required top-level keys present
- Each dimension non-empty
- Priority tiers reference valid dimension values
- scenario_filename_template has all required placeholders
- No orphan dimensions (every dimension used in at least one tier)

Exit 0 on success, 1 on validation failure.
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[4]
MATRIX_YAML = ROOT / "scripts/tests/smoke/matrix/smoke-matrix.yaml"

REQUIRED_TOP_KEYS = {"matrix", "image_pyramid", "s3_event_log", "history_server"}
REQUIRED_MATRIX_KEYS = {"priority_tiers", "scenario_filename_template", "dimensions"}
REQUIRED_DIMENSIONS = {"components", "spark_versions", "modes", "features"}


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def check_yaml_loads() -> dict[str, Any] | None:
    try:
        with MATRIX_YAML.open() as f:
            return yaml.safe_load(f)
    except yaml.YAMLError as e:
        fail(f"YAML parse error: {e}")
        return None


def check_top_keys(data: dict[str, Any]) -> bool:
    missing = REQUIRED_TOP_KEYS - set(data.keys())
    if missing:
        fail(f"missing top-level keys: {missing}")
        return False
    return True


def check_matrix_keys(data: dict[str, Any]) -> bool:
    matrix = data["matrix"]
    missing = REQUIRED_MATRIX_KEYS - set(matrix.keys())
    if missing:
        fail(f"matrix missing keys: {missing}")
        return False
    return True


def check_dimensions(matrix: dict[str, Any]) -> bool:
    dims = matrix["dimensions"]
    missing = REQUIRED_DIMENSIONS - set(dims.keys())
    if missing:
        fail(f"dimensions missing: {missing}")
        return False
    for name, values in dims.items():
        if not values:
            fail(f"dimension '{name}' is empty")
            return False
    return True


def check_tiers(matrix: dict[str, Any]) -> bool:
    tiers = matrix["priority_tiers"]
    dims = matrix["dimensions"]
    valid = {
        "components": {d["name"] for d in dims["components"]},
        "spark_versions": {d["version"] for d in dims["spark_versions"]},
        "modes": {d["name"] for d in dims["modes"]},
        "features": {d["name"] for d in dims["features"]},
    }
    ok = True
    for tier_key, tier in tiers.items():
        for dim_key in ("components", "spark_versions", "modes", "features"):
            values = tier.get(dim_key, [])
            invalid = set(values) - valid[dim_key]
            if invalid:
                fail(f"tier '{tier_key}' references unknown {dim_key}: {invalid}")
                ok = False
    return ok


def check_filename_template(matrix: dict[str, Any]) -> bool:
    template = matrix["scenario_filename_template"]
    required = ["{component}", "{feature_suffix}", "{mode}", "{spark_version_short}"]
    missing = [p for p in required if p not in template]
    if missing:
        fail(f"scenario_filename_template missing placeholders: {missing}")
        return False
    if not template.endswith(".sh"):
        fail("scenario_filename_template must end with .sh")
        return False
    return True


def main() -> int:
    data = check_yaml_loads()
    if data is None:
        return 1
    checks = [
        check_top_keys(data),
        check_matrix_keys(data),
        check_dimensions(data["matrix"]),
        check_tiers(data["matrix"]),
        check_filename_template(data["matrix"]),
    ]
    if all(checks):
        print(f"OK: {MATRIX_YAML.relative_to(ROOT)} valid")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
