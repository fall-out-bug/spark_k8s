"""Runbook tests: headers, counts, frontmatter."""

import tempfile
from pathlib import Path

from .runbook_validator import RunbookTester


def test_has_required_headers() -> None:
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


def test_has_required_headers_missing() -> None:
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


def test_get_link_count() -> None:
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


def test_get_code_block_count() -> None:
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


def test_validate_frontmatter_with_valid() -> None:
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


def test_validate_frontmatter_without() -> None:
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


def test_validate_frontmatter_invalid() -> None:
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
