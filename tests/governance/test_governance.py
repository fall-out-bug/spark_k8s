"""
Governance Documentation Tests

Tests:
1. Data access control documentation completeness
2. Data lineage documentation completeness
3. Naming conventions documentation completeness
4. Audit logging documentation completeness
5. Dataset README template availability
"""

import pytest
import re
from pathlib import Path


class TestDataAccessControlDocs:
    """Tests for data access control documentation"""

    @pytest.fixture(scope="class")
    def doc_path(self):
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance" / "data-access-control.md"

    def test_doc_exists(self, doc_path):
        """Test that data access control doc exists"""
        assert doc_path.exists(), "Data access control documentation should exist"

    def test_doc_contains_hive_acls(self, doc_path):
        """Test that Hive ACLs section exists"""
        content = doc_path.read_text()
        assert "Hive ACLs" in content or "Storage-Based Authorization" in content, \
            "Should document Hive ACLs"

    def test_doc_contains_ranger_reference(self, doc_path):
        """Test that Apache Ranger reference exists"""
        content = doc_path.read_text()
        assert "Apache Ranger" in content or "Ranger" in content, \
            "Should reference Apache Ranger for future implementation"

    def test_doc_contains_permission_examples(self, doc_path):
        """Test that permission examples are provided"""
        content = doc_path.read_text()
        assert "GRANT" in content and "REVOKE" in content, \
            "Should contain GRANT and REVOKE examples"

    def test_doc_contains_best_practices(self, doc_path):
        """Test that best practices section exists"""
        content = doc_path.read_text()
        assert "Best Practices" in content or "best practices" in content.lower(), \
            "Should contain best practices section"


class TestDataLineageDocs:
    """Tests for data lineage documentation"""

    @pytest.fixture(scope="class")
    def doc_path(self):
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance" / "data-lineage.md"

    def test_doc_exists(self, doc_path):
        """Test that data lineage doc exists"""
        assert doc_path.exists(), "Data lineage documentation should exist"

    def test_doc_contains_manual_patterns(self, doc_path):
        """Test that manual lineage patterns are documented"""
        content = doc_path.read_text()
        assert "Manual" in content or "README" in content, \
            "Should document manual lineage patterns"

    def test_doc_contains_datahub_reference(self, doc_path):
        """Test that DataHub reference exists"""
        content = doc_path.read_text()
        assert "DataHub" in content, \
            "Should reference DataHub for future implementation"

    def test_doc_contains_dataset_readme_pattern(self, doc_path):
        """Test that dataset README pattern is documented"""
        content = doc_path.read_text()
        assert "README" in content or "readme" in content.lower(), \
            "Should document dataset README pattern"

    def test_doc_contains_lineage_diagram_example(self, doc_path):
        """Test that lineage diagram example exists"""
        content = doc_path.read_text()
        assert "mermaid" in content or "diagram" in content.lower(), \
            "Should contain lineage diagram example"


class TestNamingConventionsDocs:
    """Tests for naming conventions documentation"""

    @pytest.fixture(scope="class")
    def doc_path(self):
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance" / "naming-conventions.md"

    def test_doc_exists(self, doc_path):
        """Test that naming conventions doc exists"""
        assert doc_path.exists(), "Naming conventions documentation should exist"

    def test_doc_contains_database_naming(self, doc_path):
        """Test that database naming section exists"""
        content = doc_path.read_text()
        assert "Database" in content or "database" in content.lower(), \
            "Should document database naming"

    def test_doc_contains_table_naming(self, doc_path):
        """Test that table naming section exists"""
        content = doc_path.read_text()
        assert "Table" in content or "table" in content.lower(), \
            "Should document table naming"

    def test_doc_contains_column_naming(self, doc_path):
        """Test that column naming section exists"""
        content = doc_path.read_text()
        assert "Column" in content or "column" in content.lower(), \
            "Should document column naming"

    def test_doc_contains_examples(self, doc_path):
        """Test that naming examples are provided"""
        content = doc_path.read_text()
        assert "prod_" in content or "dev_" in content or "staging_" in content, \
            "Should contain environment prefix examples"

    def test_doc_contains_snake_case_rule(self, doc_path):
        """Test that snake_case rule is documented"""
        content = doc_path.read_text()
        assert "snake_case" in content, \
            "Should recommend snake_case naming"


class TestAuditLoggingDocs:
    """Tests for audit logging documentation"""

    @pytest.fixture(scope="class")
    def doc_path(self):
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance" / "audit-logging.md"

    def test_doc_exists(self, doc_path):
        """Test that audit logging doc exists"""
        assert doc_path.exists(), "Audit logging documentation should exist"

    def test_doc_contains_spark_audit(self, doc_path):
        """Test that Spark audit logging section exists"""
        content = doc_path.read_text()
        assert "Spark" in content or "spark" in content.lower(), \
            "Should document Spark audit logging"

    def test_doc_contains_metastore_audit(self, doc_path):
        """Test that metastore audit section exists"""
        content = doc_path.read_text()
        assert "Metastore" in content or "metastore" in content.lower(), \
            "Should document metastore audit logging"

    def test_doc_contains_kubernetes_audit(self, doc_path):
        """Test that Kubernetes audit section exists"""
        content = doc_path.read_text()
        assert "Kubernetes" in content or "kubernetes" in content.lower(), \
            "Should document Kubernetes audit logging"

    def test_doc_contains_compliance_section(self, doc_path):
        """Test that compliance section exists"""
        content = doc_path.read_text()
        assert "GDPR" in content or "SOX" in content or "compliance" in content.lower(), \
            "Should contain compliance guidance"

    def test_doc_contains_query_examples(self, doc_path):
        """Test that audit query examples are provided"""
        content = doc_path.read_text()
        assert "SELECT" in content and "FROM" in content, \
            "Should contain SQL query examples for audit logs"


class TestDatasetReadmeTemplate:
    """Tests for dataset README template"""

    @pytest.fixture(scope="class")
    def template_path(self):
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance" / "dataset-readme-template.md"

    def test_template_exists(self, template_path):
        """Test that dataset README template exists"""
        assert template_path.exists(), "Dataset README template should exist"

    def test_template_contains_overview_section(self, template_path):
        """Test that overview section exists"""
        content = template_path.read_text()
        assert "## Overview" in content or "## overview" in content.lower(), \
            "Template should have overview section"

    def test_template_contains_schema_section(self, template_path):
        """Test that schema section exists"""
        content = template_path.read_text()
        assert "## Schema" in content or "## schema" in content.lower() or "Schema" in content, \
            "Template should have schema section"

    def test_template_contains_lineage_section(self, template_path):
        """Test that lineage section exists"""
        content = template_path.read_text()
        assert "Lineage" in content or "lineage" in content.lower(), \
            "Template should have lineage section"

    def test_template_contains_access_section(self, template_path):
        """Test that access/security section exists"""
        content = template_path.read_text()
        assert "Access" in content or "Security" in content or "access" in content.lower(), \
            "Template should have access/security section"

    def test_template_contains_usage_examples(self, template_path):
        """Test that usage examples section exists"""
        content = template_path.read_text()
        assert "Usage" in content or "Examples" in content or "usage" in content.lower(), \
            "Template should have usage examples section"

    def test_template_contains_placeholder_syntax(self, template_path):
        """Test that template uses placeholder syntax"""
        content = template_path.read_text()
        assert "{" in content and "}" in content, \
            "Template should use {placeholder} syntax"


class TestGovernanceDocsCompleteness:
    """Tests for overall governance documentation completeness"""

    @pytest.fixture(scope="class")
    def governance_dir(self):
        return Path(__file__).parent.parent.parent / "docs" / "recipes" / "governance"

    def test_all_required_docs_exist(self, governance_dir):
        """Test that all required governance docs exist"""
        required_docs = [
            "data-access-control.md",
            "data-lineage.md",
            "naming-conventions.md",
            "audit-logging.md",
            "dataset-readme-template.md"
        ]

        for doc in required_docs:
            assert (governance_dir / doc).exists(), f"Governance doc {doc} should exist"

    def test_docs_contain_future_sections(self, governance_dir):
        """Test that docs contain 'Future' sections for tool references"""
        docs = list(governance_dir.glob("*.md"))

        for doc in docs:
            if doc.name != "dataset-readme-template.md":
                content = doc.read_text()
                # Should reference future tools (Ranger, DataHub, etc.)
                has_future_ref = any(term in content for term in ["Future", "future", "deferred", "Phase"])
                assert has_future_ref, f"{doc.name} should contain 'Future' section for deferred implementations"
