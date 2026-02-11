#!/usr/bin/env python3
"""
Aggregate test results from JSON files.

Usage:
    python aggregate_json.py [--results-dir DIR]
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List


def aggregate_results(results_dir: str) -> Dict[str, Any]:
    """Aggregate test results from JSON files."""
    results_path = Path(results_dir)
    result_files = list(results_path.glob("*.json"))

    # Exclude aggregated.json itself
    result_files = [f for f in result_files if f.name != "aggregated.json"]

    aggregated: Dict[str, Any] = {
        "timestamp": datetime.now().isoformat(),
        "total": len(result_files),
        "passed": 0,
        "failed": 0,
        "skipped": 0,
        "scenarios": [],
        "duration": 0,
    }

    total_duration = 0

    for result_file in result_files:
        try:
            with open(result_file, "r", encoding="utf-8") as f:
                result = json.load(f)

            scenario_name = result_file.stem
            result["scenario"] = scenario_name
            aggregated["scenarios"].append(result)

            status = result.get("status", "unknown")
            if status == "passed":
                aggregated["passed"] += 1
            elif status == "failed":
                aggregated["failed"] += 1
            elif status == "skipped":
                aggregated["skipped"] += 1

            # Accumulate duration
            duration = result.get("duration", 0)
            total_duration += duration

        except FileNotFoundError:
            print(f"Warning: Result file not found: {result_file}", file=sys.stderr)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in {result_file}: {e}", file=sys.stderr)
            aggregated["failed"] += 1
            aggregated["scenarios"].append({
                "scenario": result_file.stem,
                "status": "error",
                "error": f"JSON decode error: {e}"
            })
        except Exception as e:
            print(f"Error reading {result_file}: {e}", file=sys.stderr)
            aggregated["failed"] += 1
            aggregated["scenarios"].append({
                "scenario": result_file.stem,
                "status": "error",
                "error": str(e)
            })

    aggregated["duration"] = total_duration

    # Calculate pass rate
    if aggregated["total"] > 0:
        aggregated["pass_rate"] = round(aggregated["passed"] / aggregated["total"] * 100, 2)
    else:
        aggregated["pass_rate"] = 0.0

    return aggregated


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate test results from JSON files"
    )
    parser.add_argument(
        "--results-dir",
        default="test-results",
        help="Directory containing result JSON files (default: test-results)"
    )

    args = parser.parse_args()
    results_path = Path(args.results_dir)

    if not results_path.exists():
        print(f"Error: Results directory not found: {results_path}", file=sys.stderr)
        return 1

    aggregated = aggregate_results(str(results_path))

    # Write aggregated results
    output_file = results_path / "aggregated.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(aggregated, f, indent=2)

    print(f"Aggregated results written to {output_file}")
    print(f"Total: {aggregated['total']}, Passed: {aggregated['passed']}, Failed: {aggregated['failed']}, Skipped: {aggregated['skipped']}")
    print(f"Pass Rate: {aggregated['pass_rate']}%, Duration: {aggregated['duration']}s")

    # Exit with error code if any tests failed
    return 0 if aggregated["failed"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
