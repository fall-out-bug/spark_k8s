"""Runbook tests: structure with recommended, integration."""

import tempfile
from pathlib import Path

from .runbook_validator import RunbookTester


def test_structure_validation_with_recommended() -> None:
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
        assert len(result["warnings"]) == 0, "No warnings with all recommended"
        assert len(result["sections"]) == 4, "Should have 4 required sections"


def test_validate_code_blocks_with_warnings() -> None:
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


def test_test_runbook_integration() -> None:
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
        assert result["passed"] is True, "Should pass with all sections"


def test_test_all_runbooks() -> None:
    """Test testing all runbooks in directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
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
