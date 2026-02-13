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
import tempfile
import json

# Import the validator module
from .runbook_validator import RunbookTester


def test_runbook_finder():
    """Test finding runbooks in directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tester = RunbookTester(tmpdir)
        runbooks = tester.find_runbooks()
        assert len(runbooks) == 0, "Expected no runbooks in empty dir"
        assert isinstance(runbooks, list), "Should return list"


def test_structure_validation():
    """Test runbook structure validation."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create test runbook with all required sections
        test_file = Path(tmpdir) / "test-runbook.md"
        test_file.write_text("""
## Overview

Test overview content.

## Detection

Detection section.

## Diagnosis

Diagnosis section.

## Remediation

Remediation section.

""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_structure(test_file)

        assert len(result["errors"]) == 0, f"Structure validation should pass: {result}"
        assert len(result["sections"]) >= 4, "Should find all required sections"


def test_code_block_validation():
    """Test code block validation."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create test runbook with bash blocks
        test_file = Path(tmpdir) / "test-code.md"
        test_file.write_text("""
## Test Section

```bash
kubectl get pods
echo "test"
```

""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_code_blocks(test_file)

        assert result["bash_blocks"] == 1, f"Should find 1 bash block: {result}"


def test_link_validation():
    """Test link validation."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create test runbook with various links
        test_file = Path(tmpdir) / "test-links.md"
        test_file.write_text("""
## Test Section

[Internal Link](../other-file.md)

[Broken Link](nonexistent.md)

[External Link](https://example.com)

""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_links(test_file)

        assert len(result["links"]) == 3, f"Should find 3 links: {result}"
        assert len(result["broken"]) >= 1, f"Should detect broken links: {result}"


def test_get_section_count():
    """Test getting section count from runbook."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-sections.md"
        test_file.write_text("""
# Title

## Overview

Content here.

## Detection

More content.

### Subsection

## Diagnosis

Final content.
""")
        tester = RunbookTester(tmpdir)
        count = tester.get_section_count(test_file)
        assert count == 4, f"Should count 4 sections, got {count}"


def test_has_required_headers():
    """Test checking for required headers."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-required.md"
        test_file.write_text("""
## Overview

Test.

## Detection

Test.

## Diagnosis

Test.

## Remediation

Test.
""")
        tester = RunbookTester(tmpdir)
        result = tester.has_required_headers(test_file)
        assert result is True, "Should have all required headers"


def test_has_required_headers_missing():
    """Test checking for required headers when some are missing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-missing.md"
        test_file.write_text("""
## Overview

Test.

## Detection

Test.
""")
        tester = RunbookTester(tmpdir)
        result = tester.has_required_headers(test_file)
        assert result is False, "Should not have all required headers"


def test_get_link_count():
    """Test counting links in runbook."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-links-count.md"
        test_file.write_text("""
## Test

[Link 1](http://example.com)
[Link 2](http://test.com)
[Link 3](../file.md)
""")
        tester = RunbookTester(tmpdir)
        count = tester.get_link_count(test_file)
        assert count == 3, f"Should count 3 links, got {count}"


def test_get_code_block_count():
    """Test counting code blocks by type."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-code-count.md"
        test_file.write_text("""
## Test

```bash
echo "test"
```

```python
print("test")
```

```yaml
key: value
```

```bash
ls -la
```
""")
        tester = RunbookTester(tmpdir)
        counts = tester.get_code_block_count(test_file)
        assert counts["bash"] == 2, f"Should have 2 bash blocks, got {counts['bash']}"
        assert counts["python"] == 1, f"Should have 1 python block, got {counts['python']}"
        assert counts["yaml"] == 1, f"Should have 1 yaml block, got {counts['yaml']}"
        assert counts["total"] == 4, f"Should have 4 total blocks, got {counts['total']}"


def test_validate_frontmatter_with_valid():
    """Test frontmatter validation with valid YAML."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-frontmatter.md"
        test_file.write_text("""---
title: Test Runbook
severity: high
tags: [test, example]
---

## Overview

Content.
""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_frontmatter(test_file)
        assert result["has_frontmatter"] is True, "Should detect frontmatter"
        assert result["valid"] is True, "Should validate frontmatter"
        assert len(result["errors"]) == 0, f"Should have no errors: {result['errors']}"


def test_validate_frontmatter_without():
    """Test frontmatter validation when no frontmatter exists."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-no-frontmatter.md"
        test_file.write_text("""
## Overview

Content without frontmatter.
""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_frontmatter(test_file)
        assert result["has_frontmatter"] is False, "Should not detect frontmatter"
        assert result["valid"] is False, "Should not be valid when missing"


def test_validate_frontmatter_invalid():
    """Test frontmatter validation with invalid YAML."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-invalid-fm.md"
        test_file.write_text("""---
just some text without colons
---

## Overview

Content.
""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_frontmatter(test_file)
        assert result["has_frontmatter"] is True, "Should detect frontmatter"
        assert result["valid"] is False, "Should be invalid YAML"
        assert len(result["errors"]) > 0, "Should have validation errors"


def test_structure_validation_with_recommended():
    """Test structure validation with recommended sections present."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-full.md"
        test_file.write_text("""
## Overview

Test.

## Detection

Test.

## Diagnosis

Test.

## Remediation

Test.

## Prevention

Test prevention.

## Related Runbooks

Test related.

## Troubleshooting

Test troubleshooting.
""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_structure(test_file)
        assert len(result["errors"]) == 0, "Should have no errors"
        assert len(result["warnings"]) == 0, "Should have no warnings with all recommended sections"
        assert len(result["sections"]) == 4, "Should have 4 required sections"


def test_validate_code_blocks_with_warnings():
    """Test code block validation generates warnings for kubectl commands."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-kubectl.md"
        test_file.write_text("""
## Test

```bash
kubectl get pods
echo "done"
```
""")
        tester = RunbookTester(tmpdir)
        result = tester.validate_code_blocks(test_file)
        assert result["bash_blocks"] == 1, "Should find bash block"
        assert len(result["warnings"]) > 0, "Should warn about kubectl get pods"


def test_test_runbook_integration():
    """Test the full test_runbook method integration."""
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test-integration.md"
        test_file.write_text("""
## Overview

Test overview.

## Detection

Test detection.

## Diagnosis

Test diagnosis.

## Remediation

Test remediation.

## Prevention

Test prevention.

## Related Runbooks

Test related.

## Troubleshooting

Test troubleshooting.
""")
        tester = RunbookTester(tmpdir)
        result = tester.test_runbook(test_file)
        assert "file" in result, "Should include file path"
        assert "structure" in result, "Should include structure validation"
        assert "code_blocks" in result, "Should include code block validation"
        assert "links" in result, "Should include link validation"
        assert result["passed"] is True, "Should pass with all required and recommended sections"


def test_test_all_runbooks():
    """Test testing all runbooks in directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create multiple runbooks
        (Path(tmpdir) / "runbook1.md").write_text("""
## Overview

Test.

## Detection

Test.

## Diagnosis

Test.

## Remediation

Test.
""")
        (Path(tmpdir) / "runbook2.md").write_text("""
## Overview

Test2.

## Detection

Test2.

## Diagnosis

Test2.

## Remediation

Test2.
""")
        tester = RunbookTester(tmpdir)
        results = tester.test_all_runbooks()
        assert len(results) == 2, f"Should test 2 runbooks, got {len(results)}"


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
