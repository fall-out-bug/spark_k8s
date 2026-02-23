#!/usr/bin/env python3
"""
Generate HTML report from aggregated test results.

Usage:
    python generate_html.py [--results-dir DIR]
"""

import argparse
import json
import sys
from pathlib import Path

# Import styles and metrics from separate modules
from generate_html_styles import get_html_head, get_html_body_end
from generate_html_metrics import calculate_metrics


def generate_html_body_start(aggregated: dict, metrics: dict) -> str:
    """Generate HTML body start with summary section."""
    return f"""    <div class="container">
        <div class="overall-status" style="background: {metrics['status_color']};">
            {metrics['status_text']}
        </div>

        <h1>Spark K8s Test Report</h1>
        <div class="subtitle">Generated: {aggregated['timestamp']}</div>

        <div class="summary">
            <div class="metric total">
                <h3>Total Tests</h3>
                <div class="value">{metrics['total']}</div>
            </div>
            <div class="metric passed">
                <h3>Passed</h3>
                <div class="value">{metrics['passed']}</div>
            </div>
            <div class="metric failed">
                <h3>Failed</h3>
                <div class="value">{metrics['failed']}</div>
            </div>
            <div class="metric skipped">
                <h3>Skipped</h3>
                <div class="value">{metrics['skipped']}</div>
            </div>
            <div class="metric">
                <h3>Pass Rate</h3>
                <div class="value">{metrics['pass_rate']:.1f}%</div>
            </div>
            <div class="metric">
                <h3>Duration</h3>
                <div class="value">{metrics['duration_minutes']:.1f}m</div>
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


def generate_scenario_row(scenario: dict) -> str:
    """Generate HTML table row for a scenario."""
    scenario_name = scenario.get("scenario", "unknown")
    status = scenario.get("status", "unknown")
    status_class = f"status-{status}"
    duration_val = scenario.get("duration", 0)
    duration_str = f"{duration_val}s" if duration_val > 0 else "-"

    # Get details based on status
    details = ""
    if status == "failed":
        details = scenario.get("error", f"Exit code: {scenario.get('exit_code', 1)}")
    elif status == "error":
        details = scenario.get("error", "Unknown error")
    elif status == "skipped":
        details = scenario.get("error", "Test skipped")
    elif status == "passed":
        details = "Completed successfully"

    return f"""                <tr>
                    <td><strong>{scenario_name}</strong></td>
                    <td><span class="status-badge {status_class}">{status.upper()}</span></td>
                    <td class="duration">{duration_str}</td>
                    <td class="details">{details}</td>
                </tr>"""


def generate_html_report(results_dir: str) -> str:
    """Generate HTML report from aggregated results."""
    results_path = Path(results_dir)
    aggregated_file = results_path / "aggregated.json"

    if not aggregated_file.exists():
        print(f"Error: {aggregated_file} not found. Run aggregate_json.py first.", file=sys.stderr)
        sys.exit(1)

    with open(aggregated_file, "r", encoding="utf-8") as f:
        aggregated = json.load(f)

    # Calculate metrics using imported function
    metrics = calculate_metrics(aggregated)

    # Build HTML report
    html = get_html_head()
    html += generate_html_body_start(aggregated, metrics)

    # Add scenario rows (failed first, then by name)
    sorted_scenarios = sorted(
        aggregated["scenarios"],
        key=lambda s: (s.get("status") != "failed", s.get("scenario", ""))
    )

    for scenario in sorted_scenarios:
        html += generate_scenario_row(scenario)

    html += get_html_body_end()
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
