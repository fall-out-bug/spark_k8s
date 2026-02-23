"""Governance tests for dataset template and documentation completeness."""

from pathlib import Path

import pytest


class TestDatasetReadmeTemplate:
    """Tests for dataset README template."""

    @pytest.fixture(scope="class")
    def template_path(self) -> Path:
        return (
            Path(__file__).parent.parent.parent
            / "docs"
            / "recipes"
            / "governance"
            / "dataset-readme-template.md"
        )

    def test_template_exists(self, template_path: Path) -> None:
        """Test that dataset README template exists."""
        assert template_path.exists(), "Dataset README template should exist"

    def test_template_contains_overview_section(self, template_path: Path) -> None:
        """Test that overview section exists."""
        content = template_path.read_text()
        assert "## Overview" in content or "## overview" in content.lower()

    def test_template_contains_schema_section(self, template_path: Path) -> None:
        """Test that schema section exists."""
        content = template_path.read_text()
        assert "## Schema" in content or "Schema" in content

    def test_template_contains_lineage_section(self, template_path: Path) -> None:
        """Test that lineage section exists."""
        content = template_path.read_text()
        assert "Lineage" in content or "lineage" in content.lower()

    def test_template_contains_access_section(self, template_path: Path) -> None:
        """Test that access/security section exists."""
        content = template_path.read_text()
        assert "Access" in content or "Security" in content or "access" in content.lower()

    def test_template_contains_usage_examples(self, template_path: Path) -> None:
        """Test that usage examples section exists."""
        content = template_path.read_text()
        assert "Usage" in content or "Examples" in content or "usage" in content.lower()

    def test_template_contains_placeholder_syntax(self, template_path: Path) -> None:
        """Test that template uses placeholder syntax."""
        content = template_path.read_text()
        assert "{" in content and "}" in content


class TestGovernanceDocsCompleteness:
    """Tests for overall governance documentation completeness."""

    @pytest.fixture(scope="class")
    def governance_dir(self) -> Path:
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance"

    def test_all_required_docs_exist(self, governance_dir: Path) -> None:
        """Test that all required governance docs exist."""
        required_docs = [
            "data-access-control.md",
            "data-lineage.md",
            "naming-conventions.md",
            "audit-logging.md",
            "dataset-readme-template.md",
        ]
        for doc in required_docs:
            assert (governance_dir / doc).exists(), f"Governance doc {doc} should exist"

    def test_docs_contain_future_sections(self, governance_dir: Path) -> None:
        """Test that docs contain 'Future' sections for tool references."""
        docs = list(governance_dir.glob("*.md"))
        for doc in docs:
            if doc.name != "dataset-readme-template.md":
                content = doc.read_text()
                has_future_ref = any(
                    term in content for term in ["Future", "future", "deferred", "Phase"]
                )
                assert has_future_ref, (
                    f"{doc.name} should contain 'Future' section for deferred implementations"
                )
