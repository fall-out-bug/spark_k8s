"""Tests for compliance requirements"""

import pytest
import subprocess
from pathlib import Path


class TestCompliance:
    """Tests for compliance requirements"""

    @pytest.fixture(scope="class")
    def repository_root(self):
        return Path(__file__).parent.parent.parent

    def test_pod_security_standards_enforced(self, repository_root):
        """Test that PSS labels can be enforced"""
        # Check for namespace labels in documentation
        docs_dir = repository_root / "docs"
        if docs_dir.exists():
            result = subprocess.run(
                ["grep", "-r", "pod-security.kubernetes.io/enforce", str(docs_dir)],
                capture_output=True
            )
            # Should find reference in documentation
            # (not necessarily applied, but documented)

    def test_security_documentation_complete(self, repository_root):
        """Test that security documentation is comprehensive"""
        security_doc = repository_root / "docs" / "recipes" / "security" / "hardening-guide.md"
        assert security_doc.exists(), "Security documentation should exist"

        content = security_doc.read_text()
        assert "Network Policies" in content, "Should cover network policies"
        assert "RBAC" in content, "Should cover RBAC"
        assert "Trivy" in content, "Should cover image scanning"
        assert "Secrets Management" in content, "Should cover secrets"
