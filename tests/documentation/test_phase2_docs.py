"""Tests for data quality and Great Expectations integration."""

import pytest
from pathlib import Path


class TestDataQualityGuide:
    """Test data quality documentation."""

    def test_great_expectations_guide_exists(self):
        """Great Expectations guide should exist."""
        guide = Path("docs/recipes/data-quality/great-expectations-guide.md")
        assert guide.exists()

    def test_guide_has_quick_start(self):
        """Guide should have quick start section."""
        guide = Path("docs/recipes/data-quality/great-expectations-guide.md")
        content = guide.read_text()
        assert "Quick Start" in content

    def test_guide_has_examples(self):
        """Guide should have code examples."""
        guide = Path("docs/recipes/data-quality/great-expectations-guide.md")
        content = guide.read_text()
        assert "```" in content

    def test_guide_has_airflow_integration(self):
        """Guide should cover Airflow integration."""
        guide = Path("docs/recipes/data-quality/great-expectations-guide.md")
        content = guide.read_text()
        assert "Airflow" in content


class TestCompatibilityMatrix:
    """Test compatibility matrix documentation."""

    def test_compatibility_matrix_exists(self):
        """Compatibility matrix should exist."""
        matrix = Path("docs/operations/compatibility-matrix.md")
        assert matrix.exists()

    def test_matrix_has_version_table(self):
        """Matrix should have version compatibility table."""
        matrix = Path("docs/operations/compatibility-matrix.md")
        content = matrix.read_text()
        assert "Spark Version" in content or "3.5" in content

    def test_matrix_has_breaking_changes(self):
        """Matrix should document breaking changes."""
        matrix = Path("docs/operations/compatibility-matrix.md")
        content = matrix.read_text()
        assert "Breaking Changes" in content or "Migration" in content

    def test_matrix_has_platform_support(self):
        """Matrix should show platform support."""
        matrix = Path("docs/operations/compatibility-matrix.md")
        content = matrix.read_text()
        assert "Kubernetes" in content


class TestDisasterRecovery:
    """Test disaster recovery documentation."""

    def test_dr_guide_exists(self):
        """DR guide should exist."""
        guide = Path("docs/operations/disaster-recovery.md")
        assert guide.exists()

    def test_guide_has_backup_strategy(self):
        """Guide should explain backup strategy."""
        guide = Path("docs/operations/disaster-recovery.md")
        content = guide.read_text()
        assert "Backup" in content or "backup" in content

    def test_guide_has_restore_procedures(self):
        """Guide should have restore procedures."""
        guide = Path("docs/operations/disaster-recovery.md")
        content = guide.read_text()
        assert "Restore" in content or "restore" in content

    def test_guide_has_disaster_scenarios(self):
        """Guide should cover disaster scenarios."""
        guide = Path("docs/operations/disaster-recovery.md")
        content = guide.read_text()
        assert "Scenario" in content

    def test_guide_has_rto_rpo(self):
        """Guide should specify RTO/RPO."""
        guide = Path("docs/operations/disaster-recovery.md")
        content = guide.read_text()
        assert "RTO" in content or "RPO" in content


class TestQuickStartGuide:
    """Test quick start guide."""

    def test_quick_start_exists(self):
        """Quick start guide should exist."""
        guide = Path("docs/quick-start.md")
        assert guide.exists()

    def test_quick_start_has_prerequisites(self):
        """Guide should list prerequisites."""
        guide = Path("docs/quick-start.md")
        content = guide.read_text()
        assert "Prerequisites" in content

    def test_quick_start_has_steps(self):
        """Guide should have numbered steps."""
        guide = Path("docs/quick-start.md")
        content = guide.read_text()
        assert "## Step" in content or "Step 1:" in content

    def test_quick_start_has_commands(self):
        """Guide should have copy-paste commands."""
        guide = Path("docs/quick-start.md")
        content = guide.read_text()
        assert "```bash" in content or "helm install" in content

    def test_quick_start_under_15_min(self):
        """Guide should mention 15 minutes."""
        guide = Path("docs/quick-start.md")
        content = guide.read_text()
        assert "15" in content and "minute" in content.lower()

    def test_quick_start_has_troubleshooting(self):
        """Guide should have troubleshooting."""
        guide = Path("docs/quick-start.md")
        content = guide.read_text()
        assert "Troubleshooting" in content


class TestPhase2Completeness:
    """Test Phase 2 documentation completeness."""

    def test_all_guides_exist(self):
        """All Phase 2 guides should exist."""
        guides = [
            "docs/recipes/data-quality/great-expectations-guide.md",
            "docs/operations/compatibility-matrix.md",
            "docs/operations/disaster-recovery.md",
            "docs/quick-start.md"
        ]
        for guide in guides:
            assert Path(guide).exists(), f"Missing: {guide}"

    def test_guides_are_markdown(self):
        """All guides should be markdown."""
        guides = [
            "docs/recipes/data-quality/great-expectations-guide.md",
            "docs/operations/compatibility-matrix.md",
            "docs/operations/disaster-recovery.md",
            "docs/quick-start.md"
        ]
        for guide in guides:
            assert Path(guide).suffix == ".md"
