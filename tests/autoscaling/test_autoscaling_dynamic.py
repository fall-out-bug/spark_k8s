"""Tests for Dynamic Allocation settings."""

from pathlib import Path

import pytest


class TestDynamicAllocation:
    """Test Dynamic Allocation settings."""

    @pytest.fixture
    def values_file(self) -> Path:
        """Path to values file."""
        return Path("charts/spark-4.1/values.yaml")

    @pytest.fixture
    def values_content(self, values_file: Path) -> dict:
        """Values file content."""
        import yaml

        with open(values_file) as f:
            return yaml.safe_load(f)

    def test_dynamic_allocation_enabled_by_default(self, values_content: dict) -> None:
        """Dynamic allocation should be enabled by default."""
        assert values_content["connect"]["dynamicAllocation"]["enabled"] is True

    def test_dynamic_allocation_min_executors_configured(
        self, values_content: dict
    ) -> None:
        """Min executors should be configured."""
        assert "minExecutors" in values_content["connect"]["dynamicAllocation"]
        assert values_content["connect"]["dynamicAllocation"]["minExecutors"] >= 0

    def test_dynamic_allocation_max_executors_configured(
        self, values_content: dict
    ) -> None:
        """Max executors should be configured."""
        assert "maxExecutors" in values_content["connect"]["dynamicAllocation"]
        assert values_content["connect"]["dynamicAllocation"]["maxExecutors"] > 0

    def test_max_executors_greater_than_min(self, values_content: dict) -> None:
        """Max executors should be greater than min executors."""
        da = values_content["connect"]["dynamicAllocation"]
        assert da["maxExecutors"] > da["minExecutors"]


class TestAutoscalingValues:
    """Test autoscaling values in values.yaml."""

    @pytest.fixture
    def values_file(self) -> Path:
        """Path to values file."""
        return Path("charts/spark-4.1/values.yaml")

    @pytest.fixture
    def values_content(self, values_file: Path) -> dict:
        """Values file content."""
        import yaml

        with open(values_file) as f:
            return yaml.safe_load(f)

    def test_autoscaling_section_exists(self, values_content: dict) -> None:
        """Autoscaling section should exist."""
        assert "autoscaling" in values_content

    def test_cluster_autoscaler_disabled_by_default(self, values_content: dict) -> None:
        """Cluster Autoscaler should be disabled by default."""
        assert values_content["autoscaling"]["clusterAutoscaler"]["enabled"] is False

    def test_keda_disabled_by_default(self, values_content: dict) -> None:
        """KEDA should be disabled by default."""
        assert values_content["autoscaling"]["keda"]["enabled"] is False

    def test_cluster_autoscaler_has_scale_down_config(
        self, values_content: dict
    ) -> None:
        """Cluster Autoscaler should have scale-down config."""
        ca = values_content["autoscaling"]["clusterAutoscaler"]
        assert "scaleDown" in ca
        assert "enabled" in ca["scaleDown"]
        assert "unneededTime" in ca["scaleDown"]

    def test_keda_has_s3_config(self, values_content: dict) -> None:
        """KEDA should have S3 configuration."""
        keda = values_content["autoscaling"]["keda"]
        assert "s3" in keda
        assert "bucket" in keda["s3"]
        assert "prefix" in keda["s3"]
