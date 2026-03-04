"""Guard tests: demo preset must maintain minimum worker config.

Prevents regression where workers get downgraded to 1 replica / 200m CPU.
Uses helm template to validate rendered output against preset.
"""

import json
import subprocess
from pathlib import Path

import yaml

PRESET = "charts/spark-3.5/presets/demo-full-spark-infra.yaml"
CHART = "charts/spark-3.5"


def _load_preset() -> dict:
    return yaml.safe_load(Path(PRESET).read_text())


def _helm_template_preset() -> str:
    result = subprocess.run(
        [
            "helm",
            "template",
            "spark-infra",
            CHART,
            "-n",
            "spark-infra",
            "-f",
            PRESET,
            "--set",
            "global.s3.accessKey=test",
            "--set",
            "global.s3.secretKey=test",
            "--set",
            "spark-base.postgresql.auth.password=test",
            "--set",
            "standalone.airflow.postgresql.auth.password=test",
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    return result.stdout


class TestDemoPresetGuard:
    """Ensure demo preset has production-worthy configuration."""

    def test_preset_exists(self) -> None:
        assert Path(PRESET).exists()

    def test_worker_replicas_at_least_2(self) -> None:
        preset = _load_preset()
        replicas = preset["standalone"]["worker"]["replicas"]
        assert replicas >= 2, f"Worker replicas={replicas}, must be >= 2"

    def test_worker_memory_request_at_least_2gi(self) -> None:
        preset = _load_preset()
        mem = preset["standalone"]["worker"]["resources"]["requests"]["memory"]
        assert mem.rstrip("Gi") != "1", f"Worker memory request={mem}, too low"
        gi = int(mem.replace("Gi", "").replace("Mi", ""))
        if "Mi" in mem:
            gi = gi // 1024
        assert gi >= 2, f"Worker memory request={mem}, must be >= 2Gi"

    def test_worker_cpu_request_at_least_500m(self) -> None:
        preset = _load_preset()
        cpu = preset["standalone"]["worker"]["resources"]["requests"]["cpu"]
        cpu_str = str(cpu)
        if cpu_str.endswith("m"):
            millicores = int(cpu_str.rstrip("m"))
        else:
            millicores = int(float(cpu_str) * 1000)
        assert millicores >= 500, f"Worker CPU request={cpu}, must be >= 500m"

    def test_worker_spark_cores_at_least_2(self) -> None:
        preset = _load_preset()
        cores = preset["standalone"]["worker"]["sparkConf"]["spark.worker.cores"]
        assert int(str(cores)) >= 2, f"spark.worker.cores={cores}, must be >= 2"

    def test_worker_spark_memory_at_least_2g(self) -> None:
        preset = _load_preset()
        mem = preset["standalone"]["worker"]["sparkConf"]["spark.worker.memory"]
        gi = int(mem.rstrip("g"))
        assert gi >= 2, f"spark.worker.memory={mem}, must be >= 2g"

    def test_helm_template_renders_2_workers(self) -> None:
        output = _helm_template_preset()
        docs = list(yaml.safe_load_all(output))
        worker_deploys = [
            d for d in docs if d and d.get("kind") == "Deployment" and "worker" in d.get("metadata", {}).get("name", "")
        ]
        assert len(worker_deploys) == 1, "Expected exactly 1 worker Deployment"
        replicas = worker_deploys[0]["spec"]["replicas"]
        assert replicas >= 2, f"Rendered worker replicas={replicas}, must be >= 2"

    def test_preset_uses_parent_chart(self) -> None:
        """Preset header must reference spark-3.5 (parent), not spark-standalone."""
        content = Path(PRESET).read_text()
        assert "charts/spark-3.5" in content
        assert "spark-standalone" not in content.split("\n")[2]

    def test_all_core_components_enabled(self) -> None:
        preset = _load_preset()
        assert preset["standalone"]["enabled"] is True
        assert preset["standalone"]["master"]["enabled"] is True
        assert preset["standalone"]["worker"]["enabled"] is True
        assert preset["standalone"]["airflow"]["enabled"] is True
        assert preset["jupyter"]["enabled"] is True
        assert preset["historyServer"]["enabled"] is True
        assert preset["hiveMetastore"]["enabled"] is True
        assert preset["spark-base"]["minio"]["enabled"] is True
        assert preset["spark-base"]["postgresql"]["enabled"] is True
