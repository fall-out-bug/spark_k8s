"""Tests for Cluster Autoscaler and KEDA templates."""

from pathlib import Path

import pytest


class TestClusterAutoscaler:
    """Test Cluster Autoscaler templates."""

    @pytest.fixture
    def template_file(self) -> Path:
        """Path to cluster autoscaler template."""
        return Path("charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml")

    def test_cluster_autoscaler_template_exists(self, template_file: Path) -> None:
        """Cluster Autoscaler template should exist."""
        assert template_file.exists()

    def test_cluster_autoscaler_template_valid_yaml(
        self, template_file: Path
    ) -> None:
        """Cluster Autoscaler template should be valid YAML template."""
        content = template_file.read_text()
        assert len(content) > 0
        assert "apiVersion" in content

    def test_cluster_autoscaler_has_configmap(self, template_file: Path) -> None:
        """Template should create ConfigMap."""
        content = template_file.read_text()
        assert "kind: ConfigMap" in content
        assert "spark-cluster-autoscaler-config" in content

    def test_cluster_autoscaler_has_rbac(self, template_file: Path) -> None:
        """Template should create RBAC resources."""
        content = template_file.read_text()
        assert "kind: ClusterRole" in content
        assert "kind: ClusterRoleBinding" in content

    def test_cluster_autoscaler_conditional(self, template_file: Path) -> None:
        """Template should be conditional on enabled flag."""
        content = template_file.read_text()
        assert "{{- if .Values.autoscaling.clusterAutoscaler.enabled }}" in content


class TestKEDAScaler:
    """Test KEDA ScaledObject templates."""

    @pytest.fixture
    def template_file(self) -> Path:
        """Path to KEDA template."""
        return Path("charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml")

    def test_keda_template_exists(self, template_file: Path) -> None:
        """KEDA template should exist."""
        assert template_file.exists()

    def test_keda_template_valid_yaml(self, template_file: Path) -> None:
        """KEDA template should be valid YAML template."""
        content = template_file.read_text()
        assert len(content) > 0
        assert "apiVersion" in content

    def test_keda_has_scaledobject(self, template_file: Path) -> None:
        """Template should create ScaledObject."""
        content = template_file.read_text()
        assert "kind: ScaledObject" in content
        assert "spark-connect-s3-scaler" in content

    def test_keda_has_s3_trigger(self, template_file: Path) -> None:
        """Template should have S3 trigger."""
        content = template_file.read_text()
        assert "type: aws-s3" in content
        assert "s3Bucket" in content

    def test_keda_conditional(self, template_file: Path) -> None:
        """Template should be conditional on enabled flag."""
        content = template_file.read_text()
        assert "autoscaling.keda" in content and "enabled" in content
