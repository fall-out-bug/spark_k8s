#!/usr/bin/env python3
"""
Generate HTML report from aggregated test results.

Usage:
    python generate_html.py [--results-dir DIR]
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path


def generate_html_report(results_dir: str) -> str:
    """Generate HTML report from aggregated results."""
    results_path = Path(results_dir)
    aggregated_file = results_path / "aggregated.json"

    if not aggregated_file.exists():
        print(f"Error: {aggregated_file} not found. Run aggregate_json.py first.", file=sys.stderr)
        sys.exit(1)

    with open(aggregated_file, "r", encoding="utf-8") as f:
        aggregated = json.load(f)

    # Calculate metrics
    total = aggregated["total"]
    passed = aggregated["passed"]
    failed = aggregated["failed"]
    skipped = aggregated["skipped"]
    pass_rate = aggregated.get("pass_rate", 0)
    duration = aggregated.get("duration", 0)
    duration_minutes = duration / 60

    # Determine overall status
    if failed == 0:
        status_color = "#d4edda"
        status_text = "PASSED"
    else:
        status_color = "#f8d7da"
        status_text = "FAILED"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Spark K8s Test Report</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; margin-bottom: 5px; }}
        .subtitle {{ color: #666; margin-bottom: 20px; font-size: 14px; }}
        .summary {{ display: flex; gap: 15px; margin: 20px 0; flex-wrap: wrap; }}
        .metric {{ background: #f5f5f5; padding: 20px; border-radius: 6px; flex: 1; min-width: 120px; text-align: center; }}
        .metric h3 {{ margin: 0 0 10px 0; font-size: 14px; color: #666; text-transform: uppercase; }}
        .metric .value {{ font-size: 36px; font-weight: bold; margin: 5px 0; }}
        .metric.passed {{ background: #d4edda; color: #155724; }}
        .metric.failed {{ background: #f8d7da; color: #721c24; }}
        .metric.skipped {{ background: #fff3cd; color: #856404; }}
        .metric.total {{ background: #e2e3e5; color: #383d41; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 14px; }}
        th, td {{ padding: 12px 10px; text-align: left; border-bottom: 1px solid #dee2e6; }}
        th {{ background: #f8f9fa; font-weight: 600; color: #495057; position: sticky; top: 0; }}
        tr:hover {{ background: #f8f9fa; }}
        .status-badge {{ display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; text-transform: uppercase; }}
        .status-passed {{ background: #d4edda; color: #155724; }}
        .status-failed {{ background: #f8d7da; color: #721c24; }}
        .status-skipped {{ background: #fff3cd; color: #856404; }}
        .status-error {{ background: #f5c6cb; color: #721c24; }}
        .details {{ font-size: 12px; color: #6c757d; max-width: 400px; }}
        .duration {{ color: #6c757d; font-size: 12px; }}
        .overall-status {{ padding: 15px; border-radius: 6px; margin-bottom: 20px; text-align: center; font-size: 18px; font-weight: bold; }}
        .footer {{ margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6; color: #6c757d; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="overall-status" style="background: {status_color};">
            {status_text}
        </div>

        <h1>Spark K8s Test Report</h1>
        <div class="subtitle">Generated: {aggregated['timestamp']}</div>

        <div class="summary">
            <div class="metric total">
                <h3>Total Tests</h3>
                <div class="value">{total}</div>
            </div>
            <div class="metric passed">
                <h3>Passed</h3>
                <div class="value">{passed}</div>
            </div>
            <div class="metric failed">
                <h3>Failed</h3>
                <div class="value">{failed}</div>
            </div>
            <div class="metric skipped">
                <h3>Skipped</h3>
                <div class="value">{skipped}</div>
            </div>
            <div class="metric">
                <h3>Pass Rate</h3>
                <div class="value">{pass_rate}%</div>
            </div>
            <div class="metric">
                <h3>Duration</h3>
                <div class="value">{duration_minutes:.1f}m</div>
            </div>
        </div>

        <h2>Test Results</h2>
        <table>
            <thead>
                <tr>
                    <th>Scenario</th>
                    <th>Status</th>
                    <th>Duration</th>
                    <th>Details</th>
                </tr>
            </thead>
            <tbody>
"""

    # Sort scenarios: failed first, then by name
    sorted_scenarios = sorted(
        aggregated["scenarios"],
        key=lambda s: (s.get("status") != "failed", s.get("scenario", ""))
    )

    for scenario in sorted_scenarios:
        scenario_name = scenario.get("scenario", "unknown")
        status = scenario.get("status", "unknown")
        status_class = f"status-{status}"
        duration_val = scenario.get("duration", 0)
        duration_str = f"{duration_val}s" if duration_val > 0 else "-"

        details = ""
        if status == "failed":
            details = scenario.get("error", f"Exit code: {scenario.get('exit_code', 1)}")
        elif status == "error":
            details = scenario.get("error", "Unknown error")
        elif status == "skipped":
            details = scenario.get("error", "Test skipped")
        elif status == "passed":
            details = "Completed successfully"

        html += f"""                <tr>
                    <td><strong>{scenario_name}</strong></td>
                    <td><span class="status-badge {status_class}">{status.upper()}</span></td>
                    <td class="duration">{duration_str}</td>
                    <td class="details">{details}</td>
                </tr>
"""

    html += """            </tbody>
        </table>

        <div class="footer">
            <p>Generated by Spark K8s Test Framework</p>
        </div>
    </div>
</body>
</html>
"""

    return html


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate HTML report from aggregated test results"
    )
    parser.add_argument(
        "--results-dir",
        default="test-results",
        help="Directory containing aggregated.json (default: test-results)"
    )

    args = parser.parse_args()
    results_path = Path(args.results_dir)

    if not results_path.exists():
        print(f"Error: Results directory not found: {results_path}", file=sys.stderr)
        return 1

    html_report = generate_html_report(str(results_path))

    # Write HTML report
    output_file = results_path / "report.html"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html_report)

    print(f"HTML report written to {output_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
