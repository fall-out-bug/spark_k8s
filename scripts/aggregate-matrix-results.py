#!/usr/bin/env python3
"""Aggregate run-matrix results. Machine-readable summary for 96 k8s/no-gpu scenarios."""

import argparse
import json
import sys
from pathlib import Path

import yaml


def load_matrix_filter(results_dir: Path, filter_str: str) -> list[str]:
    """Return scenario IDs matching filter from test-matrix.yaml."""
    matrix_file = results_dir.parent / "test-matrix.yaml"
    if not matrix_file.exists():
        return []
    with open(matrix_file) as f:
        data = yaml.safe_load(f)
    scenarios = data.get("scenarios", [])
    filters = {}
    for part in filter_str.split(","):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            filters[k.strip()] = v.strip()

    def matches(s: dict) -> bool:
        for k, v in filters.items():
            val = s.get(k)
            if val is None:
                return False
            if isinstance(val, bool):
                if v.lower() in ("true", "1", "yes") and not val:
                    return False
                if v.lower() in ("false", "0", "no") and val:
                    return False
            elif str(val) != str(v):
                return False
        return True

    return [s["id"] for s in scenarios if matches(s)]


def aggregate(
    results_dir: Path,
    expected_ids: list[str],
    filter_str: str,
    duration_sec: int = 0,
) -> dict:
    """Aggregate scenario-*.json into summary."""
    passed = 0
    failed = 0
    failed_ids = []
    for sid in expected_ids:
        fp = results_dir / f"scenario-{sid}.json"
        if not fp.exists():
            failed += 1
            failed_ids.append(sid)
            continue
        with open(fp) as f:
            r = json.load(f)
        # Scenario passes if no FAIL in deploy/smoke/e2e/load/history
        levels = ["deploy", "smoke", "e2e", "load", "history"]
        if any(r.get(lev) == "FAIL" for lev in levels):
            failed += 1
            failed_ids.append(sid)
        else:
            passed += 1

    return {
        "filter": filter_str,
        "expected": len(expected_ids),
        "passed": passed,
        "failed": failed,
        "failed_ids": failed_ids,
        "duration_sec": duration_sec,
        "pass_rate_pct": round(passed / len(expected_ids) * 100, 1) if expected_ids else 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Aggregate run-matrix results")
    parser.add_argument("--results-dir", type=Path, default=Path("tests/results"))
    parser.add_argument("--filter", default="gpu=false,platform=k8s")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--duration", type=int, default=0)
    args = parser.parse_args()

    expected = load_matrix_filter(args.results_dir, args.filter)
    if not expected:
        print("No scenarios match filter", file=sys.stderr)
        return 1

    summary = aggregate(args.results_dir, expected, args.filter, args.duration)
    out = args.output or args.results_dir / "matrix-96-summary.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"{summary['passed']}/{summary['expected']} PASS ({summary['pass_rate_pct']}%)")
    if summary["failed_ids"]:
        print(f"Failed: {', '.join(summary['failed_ids'][:10])}{'...' if len(summary['failed_ids']) > 10 else ''}")
    print(f"Duration: {summary['duration_sec']}s")
    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
