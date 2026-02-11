#!/usr/bin/env python3
"""
Generate JUnit XML from aggregated test results.

Usage:
    python aggregate_junit.py [--results-dir DIR]
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.dom import minidom


def generate_junit_xml(results_dir: str) -> str:
    """Generate JUnit XML from aggregated results."""
    results_path = Path(results_dir)
    aggregated_file = results_path / "aggregated.json"

    if not aggregated_file.exists():
        print(f"Error: {aggregated_file} not found. Run aggregate_json.py first.", file=sys.stderr)
        sys.exit(1)

    with open(aggregated_file, "r", encoding="utf-8") as f:
        aggregated = json.load(f)

    # Create testsuites element
    testsuites = ET.Element("testsuites")
    testsuites.set("name", "spark-k8s-tests")
    testsuites.set("tests", str(aggregated["total"]))
    testsuites.set("failures", str(aggregated["failed"]))
    testsuites.set("skipped", str(aggregated["skipped"]))
    testsuites.set("time", str(aggregated.get("duration", 0)))
    testsuites.set("timestamp", aggregated["timestamp"])

    # Create testsuite element
    testsuite = ET.SubElement(testsuites, "testsuite")
    testsuite.set("name", "spark-k8s-scenarios")
    testsuite.set("tests", str(aggregated["total"]))
    testsuite.set("failures", str(aggregated["failed"]))
    testsuite.set("skipped", str(aggregated["skipped"]))
    testsuite.set("time", str(aggregated.get("duration", 0)))
    testsuite.set("timestamp", aggregated["timestamp"])

    # Add properties
    properties = ET.SubElement(testsuite, "properties")
    ET.SubElement(properties, "property").set("value", f"pass_rate={aggregated.get('pass_rate', 0)}")

    # Add test cases
    for scenario in aggregated["scenarios"]:
        testcase = ET.SubElement(testsuite, "testcase")
        testcase.set("name", scenario.get("scenario", "unknown"))
        testcase.set("classname", "spark.k8s.scenario")
        testcase.set("time", str(scenario.get("duration", 0)))

        status = scenario.get("status", "unknown")

        if status == "failed":
            failure = ET.SubElement(testcase, "failure")
            failure.set("type", "AssertionError")
            failure.set("message", scenario.get("error", f"Exit code: {scenario.get('exit_code', 1)}"))
            failure.text = json.dumps(scenario, indent=2)
        elif status == "skipped":
            skipped = ET.SubElement(testcase, "skipped")
            skipped.text = scenario.get("error", "Test skipped")
        elif status == "error":
            error = ET.SubElement(testcase, "error")
            error.set("type", "RuntimeError")
            error.set("message", scenario.get("error", "Unknown error"))
            error.text = json.dumps(scenario, indent=2)

    # Pretty print XML
    xml_str = ET.tostring(testsuites, encoding="unicode")
    dom = minidom.parseString(xml_str)
    pretty_xml = dom.toprettyxml(indent="  ")

    return pretty_xml


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate JUnit XML from aggregated test results"
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

    junit_xml = generate_junit_xml(str(results_path))

    # Write JUnit XML
    output_file = results_path / "junit.xml"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(junit_xml)

    print(f"JUnit XML written to {output_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
