"""Tests for cost-optimized preset and rightsizing calculator."""

from pathlib import Path

import pytest


class TestCostOptimizedPreset:
    """Test cost-optimized preset."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to cost-optimized preset."""
        return Path("charts/spark-4.1/presets/cost-optimized-values.yaml")

    def test_cost_preset_exists(self, preset_file: Path) -> None:
        """Cost-optimized preset should exist."""
        assert preset_file.exists()

    def test_cost_preset_valid_yaml(self, preset_file: Path) -> None:
        """Preset should be valid YAML."""
        import yaml

        with open(preset_file) as f:
            yaml.safe_load(f)

    def test_cost_preset_has_spot_config(self, preset_file: Path) -> None:
        """Preset should have spot instance configuration."""
        content = preset_file.read_text()
        assert "spot" in content.lower() or "preemptible" in content.lower()

    def test_cost_preset_has_node_selector(self, preset_file: Path) -> None:
        """Preset should have node selector for spot."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "nodeSelector" in values["connect"]

    def test_cost_preset_has_tolerations(self, preset_file: Path) -> None:
        """Preset should have tolerations for spot."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "tolerations" in values["connect"]

    def test_cost_preset_aggressive_dynamic_allocation(
        self, preset_file: Path
    ) -> None:
        """Preset should use aggressive dynamic allocation."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        da = values["connect"]["dynamicAllocation"]
        assert da["enabled"] is True
        assert da["minExecutors"] == 0


class TestRightsizingCalculator:
    """Test rightsizing calculator script."""

    @pytest.fixture
    def calculator_script(self) -> Path:
        """Path to calculator script."""
        return Path("scripts/rightsizing_calculator.py")

    def test_calculator_exists(self, calculator_script: Path) -> None:
        """Calculator script should exist."""
        assert calculator_script.exists()

    def test_calculator_executable(self, calculator_script: Path) -> None:
        """Calculator script should be executable."""
        import stat

        st = calculator_script.stat()
        assert st.st_mode & stat.S_IXUSR != 0

    def test_calculator_valid_python(self, calculator_script: Path) -> None:
        """Calculator should be valid Python."""
        import ast

        with open(calculator_script) as f:
            ast.parse(f.read())

    def test_calculator_has_main_function(self, calculator_script: Path) -> None:
        """Calculator should have main function."""
        content = calculator_script.read_text()
        assert "def main()" in content

    def test_calculator_accepts_data_size(self, calculator_script: Path) -> None:
        """Calculator should accept data-size argument."""
        content = calculator_script.read_text()
        assert "--data-size" in content
