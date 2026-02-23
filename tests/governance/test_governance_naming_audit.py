"""Governance tests for naming conventions and audit logging."""

from pathlib import Path

import pytest


class TestNamingConventionsDocs:
    """Tests for naming conventions documentation."""

    @pytest.fixture(scope="class")
    def doc_path(self) -> Path:
        return (
            Path(__file__).parent.parent.parent
            / "docs"
            / "recipes"
            / "governance"
            / "naming-conventions.md"
        )

    def test_doc_exists(self, doc_path: Path) -> None:
        """Test that naming conventions doc exists."""
        assert doc_path.exists(), "Naming conventions documentation should exist"

    def test_doc_contains_database_naming(self, doc_path: Path) -> None:
        """Test that database naming section exists."""
        content = doc_path.read_text()
        assert "Database" in content or "database" in content.lower()

    def test_doc_contains_table_naming(self, doc_path: Path) -> None:
        """Test that table naming section exists."""
        content = doc_path.read_text()
        assert "Table" in content or "table" in content.lower()

    def test_doc_contains_column_naming(self, doc_path: Path) -> None:
        """Test that column naming section exists."""
        content = doc_path.read_text()
        assert "Column" in content or "column" in content.lower()

    def test_doc_contains_examples(self, doc_path: Path) -> None:
        """Test that naming examples are provided."""
        content = doc_path.read_text()
        assert "prod_" in content or "dev_" in content or "staging_" in content

    def test_doc_contains_snake_case_rule(self, doc_path: Path) -> None:
        """Test that snake_case rule is documented."""
        content = doc_path.read_text()
        assert "snake_case" in content


class TestAuditLoggingDocs:
    """Tests for audit logging documentation."""

    @pytest.fixture(scope="class")
    def doc_path(self) -> Path:
        return (
            Path(__file__).parent.parent.parent
            / "docs"
            / "recipes"
            / "governance"
            / "audit-logging.md"
        )

    def test_doc_exists(self, doc_path: Path) -> None:
        """Test that audit logging doc exists."""
        assert doc_path.exists(), "Audit logging documentation should exist"

    def test_doc_contains_spark_audit(self, doc_path: Path) -> None:
        """Test that Spark audit logging section exists."""
        content = doc_path.read_text()
        assert "Spark" in content or "spark" in content.lower()

    def test_doc_contains_metastore_audit(self, doc_path: Path) -> None:
        """Test that metastore audit section exists."""
        content = doc_path.read_text()
        assert "Metastore" in content or "metastore" in content.lower()

    def test_doc_contains_kubernetes_audit(self, doc_path: Path) -> None:
        """Test that Kubernetes audit section exists."""
        content = doc_path.read_text()
        assert "Kubernetes" in content or "kubernetes" in content.lower()

    def test_doc_contains_compliance_section(self, doc_path: Path) -> None:
        """Test that compliance section exists."""
        content = doc_path.read_text()
        assert "GDPR" in content or "SOX" in content or "compliance" in content.lower()

    def test_doc_contains_query_examples(self, doc_path: Path) -> None:
        """Test that audit query examples are provided."""
        content = doc_path.read_text()
        assert "SELECT" in content and "FROM" in content
