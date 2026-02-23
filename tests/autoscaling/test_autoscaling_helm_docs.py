"""Tests for Helm rendering and autoscaling documentation."""

import subprocess
from pathlib import Path

import pytest


class TestHelmRender:
    """Test Helm rendering with autoscaling enabled."""

    def test_render_with_cluster_autoscaler(self) -> None:
        """Should render Cluster Autoscaler when enabled."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-test",
                "charts/spark-4.1",
                "--set",
                "autoscaling.clusterAutoscaler.enabled=true",
                "--show-only",
                "templates/autoscaling/cluster-autoscaler.yaml",
            ],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        assert "kind: ConfigMap" in result.stdout
        assert "spark-cluster-autoscaler-config" in result.stdout

    def test_render_with_keda(self) -> None:
        """Should render KEDA when enabled."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-test",
                "charts/spark-4.1",
                "--set",
                "autoscaling.keda.enabled=true",
                "--set",
                "autoscaling.keda.s3.bucket=test-bucket",
                "--set",
                "autoscaling.keda.s3.accessKey=test",
                "--set",
                "autoscaling.keda.s3.secretKey=test",
                "--show-only",
                "templates/autoscaling/keda-scaledobject.yaml",
            ],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        assert "kind: ScaledObject" in result.stdout

    def test_render_without_autoscaling(self) -> None:
        """Should not render autoscaling when disabled."""
        result = subprocess.run(
            [
                "helm",
                "template",
                "spark-test",
                "charts/spark-4.1",
                "--show-only",
                "templates/autoscaling/cluster-autoscaler.yaml",
            ],
            capture_output=True,
            text=True,
        )

        assert "kind: ConfigMap" not in result.stdout


class TestDocumentation:
    """Test auto-scaling documentation."""

    def test_auto_scaling_guide_exists(self) -> None:
        """Auto-scaling guide should exist."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        assert guide.exists()

    def test_auto_scaling_guide_has_sections(self) -> None:
        """Guide should have required sections."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        content = guide.read_text()

        required_sections = [
            "# Auto-Scaling Guide",
            "## Dynamic Allocation",
            "## Cluster Autoscaler",
            "## KEDA",
            "## Cost-Optimized Preset",
            "## Rightsizing Calculator",
            "## Spot Instance Considerations",
            "## Cost Optimization Best Practices",
        ]

        for section in required_sections:
            assert section in content

    def test_auto_scaling_guide_has_examples(self) -> None:
        """Guide should have configuration examples."""
        guide = Path("docs/recipes/cost-optimization/auto-scaling-guide.md")
        content = guide.read_text()

        assert "```yaml" in content
        assert "dynamicAllocation:" in content
        assert "autoscaling:" in content
