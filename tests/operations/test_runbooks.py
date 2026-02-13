#!/usr/bin/env python3
"""
Runbook CLI entry point.
Tests are in test_runbooks_core, test_runbooks_validation, test_runbooks_integration.
"""

import argparse
import sys

from .runbook_validator import RunbookTester


def main() -> None:
    """CLI for testing operational runbooks."""
    parser = argparse.ArgumentParser(description="Test operational runbooks")
    parser.add_argument(
        "--runbook-dir",
        default="docs/operations/runbooks",
        help="Runbook directory",
    )
    parser.add_argument("--output", help="Output JSON file")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    tester = RunbookTester(args.runbook_dir)
    results = tester.test_all_runbooks()
    tester.print_results(results)

    if args.output:
        tester.save_results(results, args.output)
        print(f"\nResults saved to: {args.output}")

    passed = sum(1 for r in results if r["passed"])
    total = len(results)
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
