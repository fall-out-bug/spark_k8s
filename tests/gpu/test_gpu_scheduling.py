"""GPU scheduling and Jupyter configuration tests."""

from pathlib import Path

import pytest


class TestGPUScheduling:
    """Test GPU scheduling configuration."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_node_selector_for_gpu(self, preset_file: Path) -> None:
        """Should have node selector for GPU nodes."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        ns = values["connect"]["nodeSelector"]
        keys = [str(k).lower() for k in ns]
        assert any("gpu" in k or "nvidia" in k for k in keys)

    def test_tolerations_for_gpu_taints(self, preset_file: Path) -> None:
        """Should have tolerations for GPU taints."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        tols = values["connect"]["tolerations"]
        assert len(tols) > 0
        assert any(t.get("key", "") in ["nvidia.com/gpu", "gpu"] for t in tols)


class TestJupyterGPU:
    """Test Jupyter GPU configuration."""

    @pytest.fixture
    def preset_file(self) -> Path:
        """Path to GPU preset."""
        return Path("charts/spark-4.1/presets/gpu-values.yaml")

    def test_jupyter_has_gpu_resources(self, preset_file: Path) -> None:
        """Jupyter should have GPU resources."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        gpu = values["jupyter"]["resources"]["limits"].get("nvidia.com/gpu", "0")
        assert gpu != "0" and gpu != 0

    def test_jupyter_has_cuda_env(self, preset_file: Path) -> None:
        """Jupyter should have CUDA environment variables."""
        import yaml

        with open(preset_file) as f:
            values = yaml.safe_load(f)
        env = values["jupyter"].get("env", {})
        content = str(env).lower()
        assert "cuda" in content
