"""GPU config, RAPIDS, resources, and documentation tests."""

from pathlib import Path

import pytest


class TestGPUExample:
    """Test GPU example notebook."""

    @pytest.fixture
    def example(self) -> Path:
        """Path to GPU example."""
        return Path("examples/gpu/gpu_operations_notebook.py")

    def test_example_exists(self, example: Path) -> None:
        """GPU example should exist."""
        assert example.exists()

    def test_example_valid_python(self, example: Path) -> None:
        """Example should be valid Python."""
        import ast
        ast.parse(example.read_text())

    def test_example_imports_pyspark(self, example: Path) -> None:
        """Example should import PySpark."""
        content = example.read_text()
        assert "from pyspark" in content or "import pyspark" in content

    def test_example_has_gpu_config(self, example: Path) -> None:
        """Example should configure GPU."""
        content = example.read_text().lower()
        assert "rapids" in content or "gpu" in content

    def test_example_has_operations(self, example: Path) -> None:
        """Example should demonstrate operations."""
        content = example.read_text()
        ops = ["agg", "groupBy", "join", "filter", "sort"]
        assert any(op in content for op in ops)


class TestGPUDocumentation:
    """Test GPU documentation."""

    def test_gpu_guide_exists(self) -> None:
        """GPU guide should exist."""
        assert Path("docs/recipes/gpu/gpu-guide.md").exists()

    def test_gpu_guide_has_required_sections(self) -> None:
        """Guide should have required sections."""
        content = Path("docs/recipes/gpu/gpu-guide.md").read_text()
        required = [
            "# GPU Support Guide", "## Prerequisites", "## Quick Start",
            "## Configuration", "## Supported Operations",
            "## Performance Considerations", "## Troubleshooting",
        ]
        for section in required:
            assert section in content

    def test_gpu_guide_has_examples(self) -> None:
        """Guide should have code examples."""
        content = Path("docs/recipes/gpu/gpu-guide.md").read_text()
        assert "```" in content
        assert "helm install" in content or "spark-submit" in content

    def test_gpu_guide_has_rapids_config(self) -> None:
        """Guide should mention RAPIDS configuration."""
        content = Path("docs/recipes/gpu/gpu-guide.md").read_text().lower()
        assert "rapids" in content and "spark.rapids" in content


class TestHelmRenderGPU:
    """Test Helm rendering with GPU preset."""

    def test_render_with_gpu_preset(self) -> None:
        """Should render GPU resources when using GPU preset."""
        import subprocess
        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/spark-connect.yaml"
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "nvidia.com/gpu" in result.stdout


class TestRAPIDSConfiguration:
    """Test RAPIDS plugin configuration."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_rapids_plugin_enabled(self, preset_file: Path) -> None:
        """RAPIDS plugin should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        plugin = values["connect"]["sparkConf"].get("spark.plugins", "")
        assert "SQLPlugin" in plugin or "rapids" in plugin.lower()

    def test_rapids_sql_enabled(self, preset_file: Path) -> None:
        """RAPIDS SQL should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        enabled = values["connect"]["sparkConf"].get("spark.rapids.sql.enabled", "false")
        assert enabled == "true"

    def test_rapids_fallback_enabled(self, preset_file: Path) -> None:
        """RAPIDS fallback should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        fallback = values["connect"]["sparkConf"].get(
            "spark.rapids.sql.fallback.enabled", "false"
        )
        assert fallback == "true"

    def test_rapids_memory_configured(self, preset_file: Path) -> None:
        """RAPIDS memory should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        keys = [k for k in values["connect"]["sparkConf"] if "rapids.memory" in k]
        assert len(keys) > 0

    def test_rapids_formats_enabled(self, preset_file: Path) -> None:
        """RAPIDS format support should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        parquet = values["connect"]["sparkConf"].get(
            "spark.rapids.sql.format.parquet.read.enabled", "false"
        )
        assert parquet == "true"


class TestGPUResources:
    """Test GPU resource configuration."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_executor_gpu_count_configured(self, preset_file: Path) -> None:
        """Executor should have GPU count configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        executor = values["connect"]["executor"]
        assert "gpu" in executor and executor["gpu"]["enabled"] is True

    def test_driver_no_gpu(self, preset_file: Path) -> None:
        """Driver should not require GPU."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        gpu = values["connect"]["resources"].get("limits", {}).get("nvidia.com/gpu", "0")
        assert gpu == "0" or gpu == 0

    def test_gpu_discovery_script_configured(self, preset_file: Path) -> None:
        """GPU discovery script should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        script = values["connect"]["sparkConf"].get(
            "spark.executor.resource.gpu.discoveryScript", ""
        )
        assert "gpu-discovery.sh" in script
