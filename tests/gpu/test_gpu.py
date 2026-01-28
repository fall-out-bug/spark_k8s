"""Tests for GPU support configuration."""

import os
import pytest
from pathlib import Path


class TestGPUPreset:
    """Test GPU preset configuration."""

    @pytest.fixture
    def preset_file(self):
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_gpu_preset_exists(self, preset_file):
        """GPU preset should exist."""
        assert preset_file.exists()

    def test_gpu_preset_valid_yaml(self, preset_file):
        """Preset should be valid YAML."""
        import yaml
        with open(preset_file) as f:
            yaml.safe_load(f)

    def test_gpu_preset_has_rapids_config(self, preset_file):
        """Preset should have RAPIDS configuration."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "rapids" in str(values).lower()
        assert "sparkConf" in values["connect"]

    def test_gpu_preset_has_gpu_resources(self, preset_file):
        """Preset should have GPU resources."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "nvidia.com/gpu" in str(values["connect"]["resources"])

    def test_gpu_preset_has_node_selector(self, preset_file):
        """Preset should have GPU node selector."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "nodeSelector" in values["connect"]

    def test_gpu_preset_has_tolerations(self, preset_file):
        """Preset should have GPU tolerations."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "tolerations" in values["connect"]

    def test_gpu_preset_fallback_enabled(self, preset_file):
        """Preset should have CPU fallback enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        fallback = values["connect"]["sparkConf"].get("spark.rapids.sql.fallback.enabled", "false")
        assert fallback == "true"


class TestGPUDockerfile:
    """Test GPU Dockerfile."""

    @pytest.fixture
    def dockerfile(self):
        """Path to GPU Dockerfile."""
        return Path("docker/spark-4.1/gpu/Dockerfile")

    def test_dockerfile_exists(self, dockerfile):
        """Dockerfile should exist."""
        assert dockerfile.exists()

    def test_dockerfile_has_cuda_base(self, dockerfile):
        """Dockerfile should use CUDA base image."""
        content = dockerfile.read_text()
        assert "cuda" in content.lower()

    def test_dockerfile_has_rapids(self, dockerfile):
        """Dockerfile should install RAPIDS."""
        content = dockerfile.read_text()
        assert "rapids" in content.lower() or "cudf" in content.lower()

    def test_dockerfile_has_spark(self, dockerfile):
        """Dockerfile should install Spark."""
        content = dockerfile.read_text()
        assert "spark" in content.lower()


class TestGPUDiscoveryScript:
    """Test GPU discovery script."""

    @pytest.fixture
    def script(self):
        """Path to GPU discovery script."""
        return Path("scripts/gpu-discovery.sh")

    def test_script_exists(self, script):
        """Discovery script should exist."""
        assert script.exists()

    def test_script_executable(self, script):
        """Script should be executable."""
        import stat
        st = script.stat()
        assert st.st_mode & stat.S_IXUSR != 0

    def test_script_has_shebang(self, script):
        """Script should have bash shebang."""
        content = script.read_text()
        assert content.startswith("#!/bin/bash")

    def test_script_outputs_json(self, script):
        """Script should output JSON format."""
        content = script.read_text()
        # Script outputs JSON with GPU addresses (with bash escaping)
        assert 'name":"gpu"' in content or '"name":' in content or 'name\\":' in content

    def test_script_checks_nvidia(self, script):
        """Script should check for NVIDIA GPUs."""
        content = script.read_text()
        assert "nvidia-smi" in content or "/dev/nvidia" in content

    def test_script_handles_amd(self, script):
        """Script should check for AMD GPUs."""
        content = script.read_text()
        assert "rocm-smi" in content or "amd" in content.lower()


class TestGPUExample:
    """Test GPU example notebook."""

    @pytest.fixture
    def example(self):
        """Path to GPU example."""
        return Path("examples/gpu/gpu_operations_notebook.py")

    def test_example_exists(self, example):
        """GPU example should exist."""
        assert example.exists()

    def test_example_valid_python(self, example):
        """Example should be valid Python."""
        import ast
        with open(example) as f:
            ast.parse(f.read())

    def test_example_imports_pyspark(self, example):
        """Example should import PySpark."""
        content = example.read_text()
        assert "from pyspark" in content or "import pyspark" in content

    def test_example_has_gpu_config(self, example):
        """Example should configure GPU."""
        content = example.read_text()
        assert "rapids" in content.lower() or "gpu" in content.lower()

    def test_example_has_operations(self, example):
        """Example should demonstrate operations."""
        content = example.read_text()
        assert any(op in content for op in ["agg", "groupBy", "join", "filter", "sort"])


class TestGPUDocumentation:
    """Test GPU documentation."""

    def test_gpu_guide_exists(self):
        """GPU guide should exist."""
        guide = Path("docs/recipes/gpu/gpu-guide.md")
        assert guide.exists()

    def test_gpu_guide_has_required_sections(self):
        """Guide should have required sections."""
        guide = Path("docs/recipes/gpu/gpu-guide.md")
        content = guide.read_text()

        required_sections = [
            "# GPU Support Guide",
            "## Prerequisites",
            "## Quick Start",
            "## Configuration",
            "## Supported Operations",
            "## Performance Considerations",
            "## Troubleshooting",
        ]

        for section in required_sections:
            assert section in content

    def test_gpu_guide_has_examples(self):
        """Guide should have code examples."""
        guide = Path("docs/recipes/gpu/gpu-guide.md")
        content = guide.read_text()
        assert "```" in content
        assert "helm install" in content or "spark-submit" in content

    def test_gpu_guide_has_rapids_config(self):
        """Guide should mention RAPIDS configuration."""
        guide = Path("docs/recipes/gpu/gpu-guide.md")
        content = guide.read_text()
        assert "rapids" in content.lower()
        assert "spark.rapids" in content


class TestHelmRenderGPU:
    """Test Helm rendering with GPU preset."""

    def test_render_with_gpu_preset(self):
        """Should render GPU resources when using GPU preset."""
        import subprocess

        result = subprocess.run(
            [
                "helm", "template", "spark-gpu", "charts/spark-4.1",
                "-f", "charts/spark-4.1/presets/gpu-values.yaml",
                "--show-only", "templates/spark-connect.yaml"
            ],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        # Should have GPU resources
        assert "nvidia.com/gpu" in result.stdout


class TestRAPIDSConfiguration:
    """Test RAPIDS plugin configuration."""

    @pytest.fixture
    def preset_file(self):
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_rapids_plugin_enabled(self, preset_file):
        """RAPIDS plugin should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        plugin = values["connect"]["sparkConf"].get("spark.plugins", "")
        assert "SQLPlugin" in plugin or "rapids" in plugin.lower()

    def test_rapids_sql_enabled(self, preset_file):
        """RAPIDS SQL should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        rapids_enabled = values["connect"]["sparkConf"].get(
            "spark.rapids.sql.enabled", "false"
        )
        assert rapids_enabled == "true"

    def test_rapids_fallback_enabled(self, preset_file):
        """RAPIDS fallback should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        fallback = values["connect"]["sparkConf"].get(
            "spark.rapids.sql.fallback.enabled", "false"
        )
        assert fallback == "true"

    def test_rapids_memory_configured(self, preset_file):
        """RAPIDS memory should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        spark_conf = values["connect"]["sparkConf"]
        memory_keys = [k for k in spark_conf.keys() if "rapids.memory" in k]
        assert len(memory_keys) > 0

    def test_rapids_formats_enabled(self, preset_file):
        """RAPIDS format support should be enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        spark_conf = values["connect"]["sparkConf"]
        parquet_read = spark_conf.get("spark.rapids.sql.format.parquet.read.enabled", "false")
        assert parquet_read == "true"


class TestGPUResources:
    """Test GPU resource configuration."""

    @pytest.fixture
    def preset_file(self):
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_executor_gpu_count_configured(self, preset_file):
        """Executor should have GPU count configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        executor = values["connect"]["executor"]
        assert "gpu" in executor
        assert executor["gpu"]["enabled"] is True
        assert "count" in executor["gpu"]

    def test_driver_no_gpu(self, preset_file):
        """Driver should not require GPU."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        # Driver resources should have 0 GPUs or no GPU config
        driver_resources = values["connect"]["resources"]
        gpu = driver_resources.get("limits", {}).get("nvidia.com/gpu", "0")
        assert gpu == "0" or gpu == 0

    def test_gpu_discovery_script_configured(self, preset_file):
        """GPU discovery script should be configured."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        spark_conf = values["connect"]["sparkConf"]
        discovery_script = spark_conf.get("spark.executor.resource.gpu.discoveryScript", "")
        assert "gpu-discovery.sh" in discovery_script


class TestGPUScheduling:
    """Test GPU scheduling configuration."""

    @pytest.fixture
    def preset_file(self):
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_node_selector_for_gpu(self, preset_file):
        """Should have node selector for GPU nodes."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        node_selector = values["connect"]["nodeSelector"]
        assert any("gpu" in str(k).lower() or "nvidia" in str(k).lower()
                   for k in node_selector.keys())

    def test_tolerations_for_gpu_taints(self, preset_file):
        """Should have tolerations for GPU taints."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        tolerations = values["connect"]["tolerations"]
        assert len(tolerations) > 0
        assert any(tol.get("key", "") in ["nvidia.com/gpu", "gpu"]
                   for tol in tolerations)


class TestJupyterGPU:
    """Test Jupyter GPU configuration."""

    @pytest.fixture
    def preset_file(self):
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_jupyter_has_gpu_resources(self, preset_file):
        """Jupyter should have GPU resources."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        jupyter = values["jupyter"]
        gpu = jupyter["resources"]["limits"].get("nvidia.com/gpu", "0")
        assert gpu != "0" and gpu != 0

    def test_jupyter_has_cuda_env(self, preset_file):
        """Jupyter should have CUDA environment variables."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)

        jupyter = values["jupyter"]
        env_vars = jupyter.get("env", {})
        assert any("cuda" in str(k).lower() or "cuda" in str(v).lower()
                   for k, v in env_vars.items())
