"""GPU preset and Dockerfile tests."""

from pathlib import Path

import pytest


class TestGPUPreset:
    """Test GPU preset configuration."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_gpu_preset_exists(self, preset_file: Path) -> None:
        """GPU preset should exist."""
        assert preset_file.exists()

    def test_gpu_preset_valid_yaml(self, preset_file: Path) -> None:
        """Preset should be valid YAML."""
        import yaml
        with open(preset_file) as f:
            yaml.safe_load(f)

    def test_gpu_preset_has_rapids_config(self, preset_file: Path) -> None:
        """Preset should have RAPIDS configuration."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "rapids" in str(values).lower()
        assert "sparkConf" in values["connect"]

    def test_gpu_preset_has_gpu_resources(self, preset_file: Path) -> None:
        """Preset should have GPU resources."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "nvidia.com/gpu" in str(values["connect"]["resources"])

    def test_gpu_preset_has_node_selector(self, preset_file: Path) -> None:
        """Preset should have GPU node selector."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "nodeSelector" in values["connect"]

    def test_gpu_preset_has_tolerations(self, preset_file: Path) -> None:
        """Preset should have GPU tolerations."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        assert "tolerations" in values["connect"]

    def test_gpu_preset_fallback_enabled(self, preset_file: Path) -> None:
        """Preset should have CPU fallback enabled."""
        import yaml
        with open(preset_file) as f:
            values = yaml.safe_load(f)
        fallback = values["connect"]["sparkConf"].get(
            "spark.rapids.sql.fallback.enabled", "false"
        )
        assert fallback == "true"


class TestGPUDockerfile:
    """Test GPU Dockerfile."""

    @pytest.fixture
    def dockerfile(self) -> Path:
        """Path to GPU Dockerfile."""
        return Path("docker/spark-4.1/gpu/Dockerfile")

    def test_dockerfile_exists(self, dockerfile: Path) -> None:
        """Dockerfile should exist."""
        assert dockerfile.exists()

    def test_dockerfile_has_cuda_base(self, dockerfile: Path) -> None:
        """Dockerfile should use CUDA base image."""
        assert "cuda" in dockerfile.read_text().lower()

    def test_dockerfile_has_rapids(self, dockerfile: Path) -> None:
        """Dockerfile should install RAPIDS."""
        content = dockerfile.read_text().lower()
        assert "rapids" in content or "cudf" in content

    def test_dockerfile_has_spark(self, dockerfile: Path) -> None:
        """Dockerfile should install Spark."""
        assert "spark" in dockerfile.read_text().lower()


class TestGPUDiscoveryScript:
    """Test GPU discovery script."""

    @pytest.fixture
    def script(self) -> Path:
        """Path to GPU discovery script."""
        return Path("scripts/gpu-discovery.sh")

    def test_script_exists(self, script: Path) -> None:
        """Discovery script should exist."""
        assert script.exists()

    def test_script_executable(self, script: Path) -> None:
        """Script should be executable."""
        import stat
        assert script.stat().st_mode & stat.S_IXUSR != 0

    def test_script_has_shebang(self, script: Path) -> None:
        """Script should have bash shebang."""
        assert script.read_text().startswith("#!/bin/bash")

    def test_script_outputs_json(self, script: Path) -> None:
        """Script should output JSON format."""
        content = script.read_text()
        assert 'name":"gpu"' in content or '"name":' in content or 'name\\":' in content

    def test_script_checks_nvidia(self, script: Path) -> None:
        """Script should check for NVIDIA GPUs."""
        content = script.read_text()
        assert "nvidia-smi" in content or "/dev/nvidia" in content

    def test_script_handles_amd(self, script: Path) -> None:
        """Script should check for AMD GPUs."""
        content = script.read_text().lower()
        assert "rocm-smi" in content or "amd" in content
