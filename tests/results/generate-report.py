#!/usr/bin/env python3
"""
Test Report Generator for Lego-Spark Test Matrix
Aggregates test results and generates HTML/JSON reports
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import List, Optional

RESULTS_DIR = Path("tests/results")


class TestResult:
    def __init__(
        self,
        scenario_id: str,
        test_type: str,
        status: str,
        passed: int = 0,
        failed: int = 0,
        skipped: int = 0,
        duration: float = 0,
        error_message: str = None,
    ):
        self.scenario_id = scenario_id
        self.test_type = test_type
        self.status = status
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.duration = duration
        self.error_message = error_message

    def to_dict(self) -> dict:
        return {
            "scenario_id": self.scenario_id,
            "test_type": self.test_type,
            "status": self.status,
            "passed": self.passed,
            "failed": self.failed,
            "skipped": self.skipped,
            "duration": self.duration,
            "error_message": self.error_message,
        }


class ReportGenerator:
    def __init__(self, results_dir: Path = RESULTS_DIR):
        self.results_dir = results_dir
        self.results: List[TestResult] = []
        self.summary = {
            "total": 0,
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "by_type": defaultdict(lambda: {"passed": 0, "failed": 0, "skipped": 0}),
            "by_spark_version": defaultdict(lambda: {"passed": 0, "failed": 0, "skipped": 0}),
            "by_platform": defaultdict(lambda: {"passed": 0, "failed": 0, "skipped": 0}),
            "by_deployment_mode": defaultdict(lambda: {"passed": 0, "failed": 0, "skipped": 0}),
        }

    def parse_junit_xml(self, xml_path: Path) -> Optional[TestResult]:
        try:
            tree = ET.parse(xml_path)
            root = tree.getroot()

            for testcase in root.iter("testcase"):
                scenario_id = testcase.get("name", "unknown")
                classname = testcase.get("classname", "")
                test_type = classname.split(".")[-1] if classname else "unknown"

                duration = float(testcase.get("time", 0))

                failure = testcase.find("failure")
                error = testcase.find("error")
                skipped = testcase.find("skipped")

                if failure is not None:
                    status = "failed"
                    error_message = failure.get("message", "")
                elif error is not None:
                    status = "failed"
                    error_message = error.get("message", "")
                elif skipped is not None:
                    status = "skipped"
                    error_message = None
                else:
                    status = "passed"
                    error_message = None

                return TestResult(
                    scenario_id=scenario_id,
                    test_type=test_type,
                    status=status,
                    duration=duration,
                    error_message=error_message,
                )
        except Exception as e:
            print(f"Error parsing {xml_path}: {e}", file=sys.stderr)
            return None

    def parse_csv_history(self, csv_path: Path) -> List[TestResult]:
        results = []
        try:
            with open(csv_path) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("scenario") or line.startswith("timestamp"):
                        continue

                    parts = line.split(",")
                    if len(parts) >= 5:
                        scenario_id = parts[0]
                        passed = int(parts[1]) if parts[1].isdigit() else 0
                        failed = int(parts[2]) if parts[2].isdigit() else 0
                        skipped = int(parts[3]) if parts[3].isdigit() else 0

                        test_type = "unknown"
                        if "smoke" in scenario_id:
                            test_type = "smoke"
                        elif "e2e" in scenario_id:
                            test_type = "e2e"
                        elif "load" in scenario_id:
                            test_type = "load"
                        elif "openlineage" in scenario_id:
                            test_type = "openlineage"
                        elif "shuffle" in scenario_id:
                            test_type = "shuffle"
                        elif "gpu" in scenario_id:
                            test_type = "gpu"
                        elif "iceberg" in scenario_id:
                            test_type = "iceberg"
                        elif "openshift" in scenario_id:
                            test_type = "openshift"

                        status = "passed" if failed == 0 else "failed"

                        results.append(
                            TestResult(
                                scenario_id=scenario_id,
                                test_type=test_type,
                                status=status,
                                passed=passed,
                                failed=failed,
                                skipped=skipped,
                            )
                        )
        except Exception as e:
            print(f"Error parsing {csv_path}: {e}", file=sys.stderr)

        return results

    def collect_results(self):
        if not self.results_dir.exists():
            print(f"Results directory not found: {self.results_dir}", file=sys.stderr)
            return

        for xml_file in self.results_dir.glob("**/*.xml"):
            result = self.parse_junit_xml(xml_file)
            if result:
                self.results.append(result)

        for csv_file in self.results_dir.glob("*-history.csv"):
            results = self.parse_csv_history(csv_file)
            self.results.extend(results)

    def calculate_summary(self):
        for result in self.results:
            self.summary["total"] += 1

            if result.status == "passed":
                self.summary["passed"] += 1
            elif result.status == "failed":
                self.summary["failed"] += 1
            else:
                self.summary["skipped"] += 1

            self.summary["by_type"][result.test_type][result.status] += 1

            parts = result.scenario_id.split("-")
            if len(parts) >= 2:
                for i, part in enumerate(parts):
                    if part.startswith("3.5") or part.startswith("4.0") or part.startswith("4.1"):
                        self.summary["by_spark_version"][part][result.status] += 1
                    if part in ["k8s", "openshift"]:
                        self.summary["by_platform"][part][result.status] += 1
                    if part in ["native", "standalone"]:
                        self.summary["by_deployment_mode"][part][result.status] += 1

    def generate_json_report(self, output_path: Path):
        report = {
            "generated_at": datetime.now().isoformat(),
            "summary": dict(self.summary),
            "results": [r.to_dict() for r in self.results],
        }

        with open(output_path, "w") as f:
            json.dump(report, f, indent=2)

        print(f"JSON report generated: {output_path}")

    def generate_html_report(self, output_path: Path):
        pass_rate = (self.summary["passed"] / max(self.summary["total"], 1)) * 100

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lego-Spark Test Matrix Report</title>
    <style>
        :root {{
            --pass-color: #28a745;
            --fail-color: #dc3545;
            --skip-color: #ffc107;
            --primary-color: #007bff;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }}
        h1, h2, h3 {{
            color: #333;
        }}
        .summary-cards {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .card {{
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .card h3 {{
            margin-top: 0;
            color: #666;
            font-size: 14px;
            text-transform: uppercase;
        }}
        .card .value {{
            font-size: 32px;
            font-weight: bold;
            margin: 10px 0;
        }}
        .card.pass .value {{ color: var(--pass-color); }}
        .card.fail .value {{ color: var(--fail-color); }}
        .card.skip .value {{ color: var(--skip-color); }}
        .progress-bar {{
            background: #e9ecef;
            border-radius: 4px;
            height: 24px;
            overflow: hidden;
            margin: 20px 0;
        }}
        .progress-fill {{
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            transition: width 0.3s;
        }}
        .progress-fill.pass {{ background: var(--pass-color); }}
        .progress-fill.fail {{ background: var(--fail-color); }}
        .progress-fill.skip {{ background: var(--skip-color); }}
        table {{
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }}
        th {{
            background: #f8f9fa;
            font-weight: 600;
        }}
        tr:hover {{
            background: #f5f5f5;
        }}
        .status {{
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }}
        .status.passed {{ background: #d4edda; color: #155724; }}
        .status.failed {{ background: #f8d7da; color: #721c24; }}
        .status.skipped {{ background: #fff3cd; color: #856404; }}
        .section {{
            margin-bottom: 30px;
        }}
        .generated {{
            color: #666;
            font-size: 12px;
            text-align: center;
            margin-top: 30px;
        }}
    </style>
</head>
<body>
    <h1>🧪 Lego-Spark Test Matrix Report</h1>
    <p>Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")}</p>

    <div class="summary-cards">
        <div class="card">
            <h3>Total Scenarios</h3>
            <div class="value">{self.summary["total"]}</div>
        </div>
        <div class="card pass">
            <h3>✓ Passed</h3>
            <div class="value">{self.summary["passed"]}</div>
        </div>
        <div class="card fail">
            <h3>✗ Failed</h3>
            <div class="value">{self.summary["failed"]}</div>
        </div>
        <div class="card skip">
            <h3>⊘ Skipped</h3>
            <div class="value">{self.summary["skipped"]}</div>
        </div>
    </div>

    <div class="section">
        <h2>Pass Rate</h2>
        <div class="progress-bar">
            <div class="progress-fill pass" style="width: {pass_rate}%">{pass_rate:.1f}%</div>
        </div>
    </div>

    <div class="section">
        <h2>Results by Test Type</h2>
        <table>
            <thead>
                <tr>
                    <th>Test Type</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Skipped</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>
"""

        for test_type, counts in sorted(self.summary["by_type"].items()):
            total = counts["passed"] + counts["failed"] + counts["skipped"]
            html += f"""
                <tr>
                    <td>{test_type}</td>
                    <td>{counts["passed"]}</td>
                    <td>{counts["failed"]}</td>
                    <td>{counts["skipped"]}</td>
                    <td>{total}</td>
                </tr>
"""

        html += """
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Results by Spark Version</h2>
        <table>
            <thead>
                <tr>
                    <th>Spark Version</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Skipped</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>
"""

        for version, counts in sorted(self.summary["by_spark_version"].items()):
            total = counts["passed"] + counts["failed"] + counts["skipped"]
            html += f"""
                <tr>
                    <td>{version}</td>
                    <td>{counts["passed"]}</td>
                    <td>{counts["failed"]}</td>
                    <td>{counts["skipped"]}</td>
                    <td>{total}</td>
                </tr>
"""

        html += """
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Failed Scenarios</h2>
        <table>
            <thead>
                <tr>
                    <th>Scenario</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Error</th>
                </tr>
            </thead>
            <tbody>
"""

        failed_results = [r for r in self.results if r.status == "failed"]
        for result in failed_results[:50]:
            error = (
                result.error_message[:50] + "..."
                if result.error_message and len(result.error_message) > 50
                else (result.error_message or "")
            )
            html += f"""
                <tr>
                    <td>{result.scenario_id}</td>
                    <td>{result.test_type}</td>
                    <td><span class="status failed">failed</span></td>
                    <td>{error}</td>
                </tr>
"""

        if len(failed_results) > 50:
            html += f"""
                <tr>
                    <td colspan="4" style="text-align: center;">... and {len(failed_results) - 50} more failed scenarios</td>
                </tr>
"""

        html += """
            </tbody>
        </table>
    </div>

    <p class="generated">Generated by Lego-Spark Test Matrix Runner</p>
</body>
</html>
"""

        with open(output_path, "w") as f:
            f.write(html)

        print(f"HTML report generated: {output_path}")

    def generate(self, output_dir: Path = None):
        if output_dir is None:
            output_dir = self.results_dir

        output_dir.mkdir(parents=True, exist_ok=True)

        self.collect_results()
        self.calculate_summary()

        self.generate_json_report(output_dir / "test-report.json")
        self.generate_html_report(output_dir / "test-report.html")

        print("\nSummary:")
        print(f"  Total:   {self.summary['total']}")
        print(f"  Passed:  {self.summary['passed']}")
        print(f"  Failed:  {self.summary['failed']}")
        print(f"  Skipped: {self.summary['skipped']}")

        if self.summary["total"] > 0:
            rate = (self.summary["passed"] / self.summary["total"]) * 100
            print(f"  Pass Rate: {rate:.1f}%")


def main():
    parser = argparse.ArgumentParser(description="Generate test reports from test results")
    parser.add_argument("--results-dir", type=Path, default=RESULTS_DIR, help="Directory containing test results")
    parser.add_argument(
        "--output-dir", type=Path, default=None, help="Output directory for reports (default: same as results-dir)"
    )
    parser.add_argument("--format", choices=["json", "html", "all"], default="all", help="Output format")

    args = parser.parse_args()

    generator = ReportGenerator(args.results_dir)
    generator.generate(args.output_dir)


if __name__ == "__main__":
    main()
