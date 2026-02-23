"""E2E tests for Phase 2 documentation and metrics."""

from pathlib import Path

import pytest


class TestPhase2DocumentationE2E:
    """E2E tests for Phase 2 documentation completeness."""

    def test_quick_start_exists(self) -> None:
        """Quick start guide should exist and be comprehensive."""
        quick_start = Path("docs/quick-start.md")
        assert quick_start.exists()
        content = quick_start.read_text().lower()
        assert "15" in content or "quick" in content
        assert "install" in content or "deploy" in content
        assert "example" in content

    def test_compatibility_matrix_exists(self) -> None:
        """Compatibility matrix should exist."""
        matrix = Path("docs/operations/compatibility-matrix.md")
        assert matrix.exists()
        content = matrix.read_text().lower()
        assert "spark" in content
        assert "version" in content

    def test_disaster_recovery_exists(self) -> None:
        """Disaster recovery guide should exist."""
        dr = Path("docs/operations/disaster-recovery.md")
        assert dr.exists()
        content = dr.read_text().lower()
        assert "backup" in content
        assert "restore" in content

    def test_great_expectations_guide_exists(self) -> None:
        """Great Expectations guide should exist."""
        ge_guide = Path("docs/recipes/data-quality/great-expectations-guide.md")
        assert ge_guide.exists()
        content = ge_guide.read_text().lower()
        assert "great expectations" in content or "ge" in content
        assert "validation" in content


class TestPhase2Metrics:
    """Collect and report Phase 2 implementation metrics."""

    def test_phase2_file_count(self) -> None:
        """Phase 2 should have created expected number of files."""
        phase2_files = [
            "charts/spark-4.1/presets/gpu-values.yaml",
            "charts/spark-4.1/presets/iceberg-values.yaml",
            "charts/spark-4.1/presets/cost-optimized-values.yaml",
            "charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml",
            "charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml",
            "docker/spark-4.1/gpu/Dockerfile",
            "scripts/gpu-discovery.sh",
            "scripts/rightsizing_calculator.py",
            "examples/gpu/gpu_operations_notebook.py",
            "examples/iceberg/iceberg_examples.py",
            "docs/quick-start.md",
            "docs/recipes/gpu/gpu-guide.md",
            "docs/recipes/data-management/iceberg-guide.md",
            "docs/recipes/cost-optimization/auto-scaling-guide.md",
            "docs/operations/compatibility-matrix.md",
            "docs/operations/disaster-recovery.md",
            "docs/recipes/data-quality/great-expectations-guide.md",
        ]
        existing = sum(1 for f in phase2_files if Path(f).exists())
        assert existing >= 15, f"Expected at least 15 Phase 2 files, found {existing}"

    def test_phase2_test_count(self) -> None:
        """Phase 2 should have comprehensive test coverage."""
        test_files = [
            "tests/autoscaling/test_autoscaling_dynamic.py",
            "tests/gpu/test_gpu_preset.py",
            "tests/iceberg/test_iceberg_preset.py",
            "tests/documentation/test_phase2_docs.py",
            "tests/integration/test_phase2_features.py",
            "tests/e2e/test_phase2_gpu_iceberg.py",
        ]
        existing = sum(1 for f in test_files if Path(f).exists())
        assert existing >= 5, f"Expected at least 5 Phase 2 test files, found {existing}"

    def test_phase2_total_lines_of_code(self) -> None:
        """Phase 2 implementation should have significant code."""
        total_loc = 0
        for path in [
            "scripts/rightsizing_calculator.py",
            "scripts/gpu-discovery.sh",
            "docs/quick-start.md",
            "docs/recipes/gpu/gpu-guide.md",
            "docs/recipes/data-management/iceberg-guide.md",
        ]:
            p = Path(path)
            if p.exists():
                total_loc += len(p.read_text().splitlines())
        assert total_loc >= 300, f"Expected at least 300 LOC in Phase 2, found {total_loc}"
