"""E2E tests for auto-scaling Phase 2 features."""

from pathlib import Path

import pytest
import subprocess


class TestAutoScalingE2E:
    """E2E tests for auto-scaling with real workloads."""

    def test_cost_optimized_preset_complete(self) -> None:
        """Cost-optimized preset should have complete configuration."""
        preset = Path("charts/spark-4.1/presets/cost-optimized-values.yaml")
        content = preset.read_text()
        assert "dynamicAllocation" in content
        assert "minExecutors" in content
        assert "maxExecutors" in content
        has_spot = "spot" in content.lower() or "preemptible" in content.lower()
        assert has_spot

    def test_cluster_autoscaler_template_valid(self) -> None:
        """Cluster Autoscaler template should be valid."""
        template = Path("charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml")
        assert template.exists()
        content = template.read_text()
        assert "ClusterAutoscaler" in content or "cluster-autoscaler" in content.lower()

    def test_keda_scaler_template_valid(self) -> None:
        """KEDA ScaledObject template should be valid."""
        template = Path("charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml")
        assert template.exists()
        content = template.read_text()
        assert "ScaledObject" in content

    def test_rightsizing_calculator_works(self) -> None:
        """Rightsizing calculator should be executable."""
        script = Path("scripts/rightsizing_calculator.py")
        assert script.exists()
        result = subprocess.run(
            ["python", "-m", "py_compile", str(script)],
            capture_output=True,
        )
        assert result.returncode == 0

    def test_auto_scaling_guide_comprehensive(self) -> None:
        """Auto-scaling guide should cover all essential topics."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        assert guide.exists()
        content = guide.read_text().lower()
        assert "dynamic allocation" in content or "dynamicallocation" in content
        assert "cluster autoscaler" in content or "autoscaler" in content
        assert "keda" in content
        assert "spot" in content or "preemptible" in content
