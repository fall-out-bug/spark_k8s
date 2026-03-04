"""Guard tests: demo preset must maintain minimum worker config.

Prevents regression where workers get downgraded to 1 replica / 200m CPU.
Uses helm template to validate rendered output against preset.
"""

import re
import subprocess
from pathlib import Path

import yaml

PRESET = "charts/spark-3.5/presets/demo-full-spark-infra.yaml"
CHART = "charts/spark-3.5"
STANDALONE_VALUES = "charts/spark-3.5/charts/spark-standalone/values.yaml"
EXPORTER_YAML = "tests/observability/demo-metrics-exporter.yaml"
PORTFORWARD_SCRIPT = "tests/observability/start-ui-portforwards.sh"
RELEASE_NAME = "spark-infra"


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

    def test_worker_replicas_at_least_3(self) -> None:
        preset = _load_preset()
        replicas = preset["standalone"]["worker"]["replicas"]
        assert replicas >= 3, f"Worker replicas={replicas}, must be >= 3"

    def test_worker_memory_request_at_least_8gi(self) -> None:
        preset = _load_preset()
        mem = preset["standalone"]["worker"]["resources"]["requests"]["memory"]
        gi = int(mem.replace("Gi", "").replace("Mi", ""))
        if "Mi" in mem:
            gi = gi // 1024
        assert gi >= 8, f"Worker memory request={mem}, must be >= 8Gi"

    def test_worker_cpu_request_at_least_800m(self) -> None:
        preset = _load_preset()
        cpu = preset["standalone"]["worker"]["resources"]["requests"]["cpu"]
        cpu_str = str(cpu)
        if cpu_str.endswith("m"):
            millicores = int(cpu_str.rstrip("m"))
        else:
            millicores = int(float(cpu_str) * 1000)
        assert millicores >= 800, f"Worker CPU request={cpu}, must be >= 800m"

    def test_worker_spark_cores_at_least_2(self) -> None:
        preset = _load_preset()
        cores = preset["standalone"]["worker"]["sparkConf"]["spark.worker.cores"]
        assert int(str(cores)) >= 2, f"spark.worker.cores={cores}, must be >= 2"

    def test_worker_spark_memory_at_least_10g(self) -> None:
        preset = _load_preset()
        mem = preset["standalone"]["worker"]["sparkConf"]["spark.worker.memory"]
        gi = int(mem.rstrip("g"))
        assert gi >= 10, f"spark.worker.memory={mem}, must be >= 10g"

    def test_helm_template_renders_3_workers(self) -> None:
        output = _helm_template_preset()
        docs = list(yaml.safe_load_all(output))
        worker_deploys = [
            d for d in docs if d and d.get("kind") == "Deployment" and "worker" in d.get("metadata", {}).get("name", "")
        ]
        assert len(worker_deploys) == 1, "Expected exactly 1 worker Deployment"
        replicas = worker_deploys[0]["spec"]["replicas"]
        assert replicas >= 3, f"Rendered worker replicas={replicas}, must be >= 3"

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

    def test_all_services_have_explicit_resources(self) -> None:
        """Every service in preset must have explicit resources to prevent drift."""
        preset = _load_preset()
        services = {
            "standalone.master": preset["standalone"]["master"],
            "standalone.worker": preset["standalone"]["worker"],
            "standalone.airflow.webserver": preset["standalone"]["airflow"]["webserver"],
            "standalone.airflow.scheduler": preset["standalone"]["airflow"]["scheduler"],
            "standalone.airflow.postgresql": preset["standalone"]["airflow"]["postgresql"],
            "jupyter": preset["jupyter"],
            "historyServer": preset["historyServer"],
            "hiveMetastore": preset["hiveMetastore"],
            "spark-base.minio": preset["spark-base"]["minio"],
            "spark-base.postgresql": preset["spark-base"]["postgresql"],
        }
        for name, cfg in services.items():
            assert "resources" in cfg, f"{name} missing explicit 'resources' block"
            res = cfg["resources"]
            assert "requests" in res, f"{name} missing resources.requests"
            assert "limits" in res, f"{name} missing resources.limits"
            assert "cpu" in res["requests"], f"{name} missing requests.cpu"
            assert "memory" in res["requests"], f"{name} missing requests.memory"

    def test_total_cpu_requests_fit_node(self) -> None:
        """Total CPU requests from preset must leave headroom for system pods."""
        preset = _load_preset()

        def parse_cpu(v: str) -> int:
            v = str(v)
            return int(v.rstrip("m")) if v.endswith("m") else int(float(v) * 1000)

        total = 0
        for svc in [
            preset["standalone"]["master"],
            preset["standalone"]["airflow"]["webserver"],
            preset["standalone"]["airflow"]["scheduler"],
            preset["standalone"]["airflow"]["postgresql"],
            preset["jupyter"],
            preset["historyServer"],
            preset["hiveMetastore"],
            preset["spark-base"]["minio"],
            preset["spark-base"]["postgresql"],
        ]:
            total += parse_cpu(svc["resources"]["requests"]["cpu"])

        worker_cpu = parse_cpu(preset["standalone"]["worker"]["resources"]["requests"]["cpu"])
        worker_replicas = preset["standalone"]["worker"]["replicas"]
        total += worker_cpu * worker_replicas

        node_cpu = 6000
        system_reserve = 1100
        assert total <= node_cpu - system_reserve, (
            f"Total CPU requests {total}m exceed budget {node_cpu - system_reserve}m "
            f"(node {node_cpu}m - system {system_reserve}m)"
        )

    def test_preset_overrides_chart_defaults_for_workers(self) -> None:
        """Rendered worker Deployment with preset must meet guard minimums."""
        output = _helm_template_preset()
        docs = list(yaml.safe_load_all(output))
        worker_deploys = [
            d for d in docs if d and d.get("kind") == "Deployment" and "worker" in d.get("metadata", {}).get("name", "")
        ]
        assert len(worker_deploys) == 1
        container = worker_deploys[0]["spec"]["template"]["spec"]["containers"][0]
        cpu_req = str(container["resources"]["requests"]["cpu"])
        mem_req = str(container["resources"]["requests"]["memory"])
        cpu_m = int(cpu_req.rstrip("m")) if cpu_req.endswith("m") else int(float(cpu_req) * 1000)
        mem_gi = int(mem_req.replace("Gi", "")) if "Gi" in mem_req else int(mem_req.replace("Mi", "")) // 1024
        assert cpu_m >= 800, f"Rendered worker CPU={cpu_req}, need >=800m"
        assert mem_gi >= 8, f"Rendered worker memory={mem_req}, need >=8Gi"

    def test_postgresql_passwords_set_in_preset(self) -> None:
        """Preset must have non-empty PostgreSQL passwords to avoid auth failures."""
        preset = _load_preset()
        spark_pw = preset["spark-base"]["postgresql"]["auth"]["password"]
        assert spark_pw, "spark-base.postgresql.auth.password is empty"
        airflow_pw = preset["standalone"]["airflow"]["postgresql"]["auth"]["password"]
        assert airflow_pw, "standalone.airflow.postgresql.auth.password is empty"

    def test_metastore_database_matches_postgresql(self) -> None:
        """Hive Metastore database name must exist in PostgreSQL databases list."""
        preset = _load_preset()
        meta_db = preset["hiveMetastore"]["database"]["name"]
        pg_dbs = preset["spark-base"]["postgresql"]["databases"]
        assert meta_db in pg_dbs, (
            f"hiveMetastore.database.name='{meta_db}' not in " f"spark-base.postgresql.databases={pg_dbs}"
        )

    def test_exporter_endpoints_match_release(self) -> None:
        """demo-metrics-exporter must reference spark-infra services, not old names."""
        content = Path(EXPORTER_YAML).read_text()
        bad = re.findall(r"spark-shared-[a-z-]+", content)
        assert not bad, f"Exporter references old release name: {bad}"
        assert f"{RELEASE_NAME}-standalone-master" in content
        assert f"{RELEASE_NAME}-spark-35-history" in content

    def test_portforward_services_exist_in_rendered_output(self) -> None:
        """Every service referenced in port-forward script must exist in helm template."""
        output = _helm_template_preset()
        docs = list(yaml.safe_load_all(output))
        rendered_services = {d["metadata"]["name"] for d in docs if d and d.get("kind") == "Service"}
        pf_content = Path(PORTFORWARD_SCRIPT).read_text()
        pf_services = re.findall(r"svc/(spark-infra-[a-z0-9-]+)", pf_content)
        missing = [s for s in pf_services if s not in rendered_services]
        assert not missing, (
            f"Port-forward references services not in rendered chart: {missing}. "
            f"Available: {sorted(rendered_services)}"
        )

    def test_preset_and_defaults_worker_keys_align(self) -> None:
        """Preset worker keys must exist in chart defaults (catch typos like replica vs replicas)."""
        preset = _load_preset()
        defaults = yaml.safe_load(Path(STANDALONE_VALUES).read_text())
        preset_worker_keys = set(preset["standalone"]["worker"].keys())
        defaults_worker_keys = set(defaults["worker"].keys())
        unknown = preset_worker_keys - defaults_worker_keys
        assert not unknown, (
            f"Preset has worker keys not in defaults: {unknown}. " f"Possible typo or missing chart support."
        )
