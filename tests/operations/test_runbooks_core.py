"""Runbook tests: finder, structure, code blocks, links."""

import tempfile
from pathlib import Path

from .runbook_validator import RunbookTester


def test_runbook_finder() -> None:
    """Test finding runbooks in directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tester = RunbookTester(tmpdir)
        runbooks = tester.find_runbooks()
        assert len(runbooks) == 0, "Expected no runbooks in empty dir"
        assert isinstance(runbooks, list), "Should return list"


def test_structure_validation() -> None:
    """Test runbook structure validation."""
    with tempfile.TemporaryDirectory() as tmpdir:
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


def test_code_block_validation() -> None:
    """Test code block validation."""
    with tempfile.TemporaryDirectory() as tmpdir:
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


def test_link_validation() -> None:
    """Test link validation."""
    with tempfile.TemporaryDirectory() as tmpdir:
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


def test_get_section_count() -> None:
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
