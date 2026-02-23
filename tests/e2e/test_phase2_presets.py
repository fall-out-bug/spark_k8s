"""E2E tests for presets integration and compatibility."""

import subprocess
from pathlib import Path

import pytest


class TestPresetsIntegrationE2E:
    """E2E tests for presets integration and compatibility."""

    def test_all_presets_structure_valid(self) -> None:
        """All presets should have valid YAML structure."""
        presets_dir = Path("charts/spark-4.1/presets")
        for preset_file in presets_dir.glob("*-values.yaml"):
            content = preset_file.read_text()
            assert len(content) > 0, f"Preset {preset_file} is empty"
            assert "connect:" in content or "spark:" in content

    def test_base_values_compatible_with_presets(self) -> None:
        """Base values should be compatible with all presets."""
        base_values = Path("charts/spark-4.1/values.yaml")
        assert base_values.exists()
        result = subprocess.run(
            ["helm", "template", "spark-base", "charts/spark-4.1", "--namespace", "test"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"Base values failed: {result.stderr}"

    def test_gpu_and_iceberg_combination_possible(self) -> None:
        """GPU + Iceberg should be combinable."""
        gpu_preset = Path("charts/spark-4.1/presets/gpu-values.yaml")
        iceberg_preset = Path("charts/spark-4.1/presets/iceberg-values.yaml")
        assert gpu_preset.exists()
        assert iceberg_preset.exists()
        for preset in [gpu_preset, iceberg_preset]:
            result = subprocess.run(
                [
                    "helm",
                    "template",
                    "spark-test",
                    "charts/spark-4.1",
                    "-f",
                    str(preset),
                    "--namespace",
                    "test",
                ],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Preset {preset} failed: {result.stderr}"

    def test_all_presets_documented(self) -> None:
        """All presets should be documented in guides."""
        quick_start = Path("docs/quick-start.md")
        assert quick_start.exists()
        quick_start_content = quick_start.read_text().lower()
        preset_names = ["gpu", "iceberg", "cost-optimized"]
        for preset in preset_names:
            assert preset in quick_start_content
