"""Governance tests for data access control and lineage."""

from pathlib import Path

import pytest


class TestDataAccessControlDocs:
    """Tests for data access control documentation."""

    @pytest.fixture(scope="class")
    def doc_path(self) -> Path:
        return (
            Path(__file__).parent.parent.parent
            / "docs"
            / "recipes"
            / "governance"
            / "data-access-control.md"
        )

    def test_doc_exists(self, doc_path: Path) -> None:
        """Test that data access control doc exists."""
        assert doc_path.exists(), "Data access control documentation should exist"

    def test_doc_contains_hive_acls(self, doc_path: Path) -> None:
        """Test that Hive ACLs section exists."""
        content = doc_path.read_text()
        assert "Hive ACLs" in content or "Storage-Based Authorization" in content

    def test_doc_contains_ranger_reference(self, doc_path: Path) -> None:
        """Test that Apache Ranger reference exists."""
        content = doc_path.read_text()
        assert "Apache Ranger" in content or "Ranger" in content

    def test_doc_contains_permission_examples(self, doc_path: Path) -> None:
        """Test that permission examples are provided."""
        content = doc_path.read_text()
        assert "GRANT" in content and "REVOKE" in content

    def test_doc_contains_best_practices(self, doc_path: Path) -> None:
        """Test that best practices section exists."""
        content = doc_path.read_text()
        assert "Best Practices" in content or "best practices" in content.lower()


class TestDataLineageDocs:
    """Tests for data lineage documentation."""

    @pytest.fixture(scope="class")
    def doc_path(self) -> Path:
        return (
            Path(__file__).parent.parent.parent
            / "docs"
            / "recipes"
            / "governance"
            / "data-lineage.md"
        )

    def test_doc_exists(self, doc_path: Path) -> None:
        """Test that data lineage doc exists."""
        assert doc_path.exists(), "Data lineage documentation should exist"

    def test_doc_contains_manual_patterns(self, doc_path: Path) -> None:
        """Test that manual lineage patterns are documented."""
        content = doc_path.read_text()
        assert "Manual" in content or "README" in content

    def test_doc_contains_datahub_reference(self, doc_path: Path) -> None:
        """Test that DataHub reference exists."""
        content = doc_path.read_text()
        assert "DataHub" in content

    def test_doc_contains_dataset_readme_pattern(self, doc_path: Path) -> None:
        """Test that dataset README pattern is documented."""
        content = doc_path.read_text()
        assert "README" in content or "readme" in content.lower()

    def test_doc_contains_lineage_diagram_example(self, doc_path: Path) -> None:
        """Test that lineage diagram example exists."""
        content = doc_path.read_text()
        assert "mermaid" in content or "diagram" in content.lower()
