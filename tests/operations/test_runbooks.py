#!/usr/bin/env python3
"""
Runbook Testing Script
Tests operational runbooks for accuracy and completeness
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Any
import argparse
import subprocess


class RunbookTester:
    def __init__(self, runbook_dir: str):
        self.runbook_dir = Path(runbook_dir)
        self.results = []

    def find_runbooks(self) -> List[Path]:
        """Find all markdown files in runbook directory"""
        return list(self.runbook_dir.rglob("*.md"))

    def validate_structure(self, runbook: Path) -> Dict[str, Any]:
        """Validate runbook structure"""
        content = runbook.read_text()
        result = {
            "file": str(runbook.relative_to(self.runbook_dir)),
            "errors": [],
            "warnings": [],
            "sections": []
        }

        # Check for required sections
        required_sections = ["Overview", "Detection", "Diagnosis", "Remediation"]
        for section in required_sections:
            if f"## {section}" in content:
                result["sections"].append(section)
            else:
                result["errors"].append(f"Missing required section: {section}")

        # Check for recommended sections
        recommended_sections = ["Prevention", "Related Runbooks", "Troubleshooting"]
        for section in recommended_sections:
            if f"## {section}" not in content:
                result["warnings"].append(f"Missing recommended section: {section}")

        return result

    def validate_code_blocks(self, runbook: Path) -> Dict[str, Any]:
        """Validate code blocks in runbook"""
        content = runbook.read_text()
        result = {
            "bash_blocks": 0,
            "invalid_commands": [],
            "warnings": []
        }

        # Extract bash code blocks
        bash_blocks = re.findall(r'```bash\n(.*?)\n```', content, re.DOTALL)
        result["bash_blocks"] = len(bash_blocks)

        # Validate commands (basic check)
        for block in bash_blocks:
            for line in block.split('\n'):
                line = line.strip()
                if line and not line.startswith('#') and not line.startswith('echo'):
                    # Check for kubectl commands
                    if 'kubectl' in line:
                        if 'get pods' in line:
                            result["warnings"].append(f"Consider using -A flag: {line[:50]}")

        return result

    def validate_links(self, runbook: Path) -> Dict[str, Any]:
        """Validate internal and external links"""
        content = runbook.read_text()
        result = {
            "links": [],
            "broken": []
        }

        # Extract links
        links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
        for text, url in links:
            result["links"].append(url)

            # Check internal links
            if not url.startswith('http') and not url.startswith('#'):
                link_path = runbook.parent / url
                if not link_path.exists():
                    result["broken"].append(f"Broken link: {url}")

        return result

    def test_runbook(self, runbook: Path) -> Dict[str, Any]:
        """Test a single runbook"""
        result = {
            "file": str(runbook.relative_to(self.runbook_dir)),
            "structure": self.validate_structure(runbook),
            "code_blocks": self.validate_code_blocks(runbook),
            "links": self.validate_links(runbook)
        }

        # Calculate overall pass/fail
        result["passed"] = (
            len(result["structure"]["errors"]) == 0 and
            len(result["structure"]["warnings"]) == 0
        )

        return result

    def test_all_runbooks(self) -> List[Dict[str, Any]]:
        """Test all runbooks"""
        results = []
        for runbook in self.find_runbooks():
            results.append(self.test_runbook(runbook))
        return results

    def print_results(self, results: List[Dict[str, Any]]):
        """Print test results"""
        passed = sum(1 for r in results if r["passed"])
        total = len(results)

        print(f"\n{'='*60}")
        print(f"Runbook Test Results: {passed}/{total} passed")
        print(f"{'='*60}\n")

        for result in results:
            status = "PASS" if result["passed"] else "FAIL"
            print(f"{status}: {result['file']}")

            if not result["passed"]:
                print(f"  Errors: {result['structure']['errors']}")
                print(f"  Warnings: {result['structure']['warnings']}")

    def save_results(self, results: List[Dict[str, Any]], output: str):
        """Save results to JSON file"""
        import json
        with open(output, 'w') as f:
            json.dump(results, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description="Test operational runbooks")
    parser.add_argument("--runbook-dir", default="docs/operations/runbooks",
                       help="Runbook directory")
    parser.add_argument("--output", help="Output JSON file")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Verbose output")

    args = parser.parse_args()

    tester = RunbookTester(args.runbook_dir)
    results = tester.test_all_runbooks()

    tester.print_results(results)

    if args.output:
        tester.save_results(results, args.output)
        print(f"\nResults saved to: {args.output}")

    # Exit with error code if any tests failed
    passed = sum(1 for r in results if r["passed"])
    total = len(results)
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
