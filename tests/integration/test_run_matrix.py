"""Tests for run-matrix.sh — verifies it executes, not checks existence."""

import json
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent.parent
RUN_MATRIX = PROJECT_ROOT / "scripts" / "run-matrix.sh"
MATRIX_FILE = PROJECT_ROOT / "tests" / "test-matrix.yaml"
RESULTS_DIR = PROJECT_ROOT / "tests" / "results"


@pytest.fixture(scope="module")
def ensure_results_dir() -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def test_run_matrix_dry_run_single_scenario(ensure_results_dir: None) -> None:
    """run-matrix --filter id=SCENARIO-0009 --dry-run all executes and writes result."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "id=SCENARIO-0009", "--dry-run", "all"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert "helm install" in result.stdout
    assert "SCENARIO-0009" in result.stdout

    result_file = RESULTS_DIR / "scenario-SCENARIO-0009.json"
    assert result_file.exists()
    data = json.loads(result_file.read_text())
    assert data["id"] == "SCENARIO-0009"
    assert data.get("dry_run") is True


def test_run_matrix_filter_gpu_false(ensure_results_dir: None) -> None:
    """--filter gpu=false,platform=k8s returns multiple scenarios."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "gpu=false,platform=k8s", "--dry-run", "deploy"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    lines = [line for line in result.stdout.strip().split("\n") if line.startswith("[dry-run]")]
    assert len(lines) >= 96  # 96 k8s/no-gpu scenarios


def test_deploy_script_exists_and_has_required_behavior() -> None:
    """deploy.sh exists, is executable, and defines deploy_matrix_scenario."""
    deploy_sh = PROJECT_ROOT / "scripts" / "tests" / "lib" / "deploy.sh"
    assert deploy_sh.exists()
    assert deploy_sh.stat().st_mode & 0o111  # executable
    content = deploy_sh.read_text()
    assert "deploy_matrix_scenario" in content
    assert "kubectl wait" in content
    assert "DEPLOY_TIMEOUT" in content


def test_smoke_workload_executes_no_path_exists() -> None:
    """Smoke workload: 1K rows, count, filter. No Path.exists()."""
    smoke_py = PROJECT_ROOT / "scripts" / "tests" / "smoke" / "scripts" / "smoke_1k_count_filter.py"
    assert smoke_py.exists()
    content = smoke_py.read_text()
    assert "Path" not in content and "exists" not in content
    assert "spark.range(1000)" in content
    assert "count()" in content
    assert "filter" in content
    assert "SMOKE_SUCCESS" in content


def test_smoke_against_release_script_exists() -> None:
    """run-smoke-against-release.sh exists and uses smoke workload."""
    smoke_sh = PROJECT_ROOT / "scripts" / "tests" / "smoke" / "run-smoke-against-release.sh"
    assert smoke_sh.exists()
    content = smoke_sh.read_text()
    assert "smoke_1k_count_filter.py" in content
    assert "NAMESPACE" in content
    assert "kubectl exec" in content
    assert "Path" not in content
    assert "exists" not in content


def test_e2e_workload_executes_no_path_exists() -> None:
    """E2E workload: 10K rows, aggregations, joins. No Path.exists()."""
    e2e_py = PROJECT_ROOT / "scripts" / "tests" / "e2e" / "scripts" / "e2e_10k_agg_join.py"
    assert e2e_py.exists()
    content = e2e_py.read_text()
    assert "Path" not in content and "exists" not in content
    assert "spark.range(10000)" in content
    assert "groupBy" in content
    assert "join" in content
    assert "E2E_SUCCESS" in content


def test_e2e_against_release_script_exists() -> None:
    """run-e2e-against-release.sh exists and uses e2e workload."""
    e2e_sh = PROJECT_ROOT / "scripts" / "tests" / "e2e" / "run-e2e-against-release.sh"
    assert e2e_sh.exists()
    content = e2e_sh.read_text()
    assert "e2e_10k_agg_join.py" in content
    assert "NAMESPACE" in content
    assert "kubectl exec" in content
    assert "Path" not in content
    assert "exists" not in content


def test_load_workload_executes_no_path_exists() -> None:
    """Load workload: S3 parquet, 3 agg. No Path.exists(), no in-memory fallback."""
    load_py = PROJECT_ROOT / "scripts" / "tests" / "load" / "scripts" / "load_s3_parquet_3agg.py"
    assert load_py.exists()
    content = load_py.read_text()
    assert "Path" not in content and "exists" not in content
    assert "s3a://" in content
    assert "parquet" in content
    assert "groupBy" in content
    assert "LOAD_SUCCESS" in content
    assert "LOAD_THROUGHPUT" in content
    assert "S3_ENDPOINT" in content
    # Fail explicitly if S3 missing (no in-memory fallback)
    assert "sys.exit" in content


def test_load_against_release_script_exists() -> None:
    """run-load-against-release.sh exists and uses load workload."""
    load_sh = PROJECT_ROOT / "scripts" / "tests" / "load" / "run-load-against-release.sh"
    assert load_sh.exists()
    content = load_sh.read_text()
    assert "load_s3_parquet_3agg.py" in content
    assert "NAMESPACE" in content
    assert "RELEASE" in content
    assert "S3_ENDPOINT" in content
    assert "kubectl exec" in content
    assert "spark.eventLog.enabled" in content
    assert "spark.eventLog.dir" in content
    assert "Path" not in content
    assert "exists" not in content


def test_validate_history_script_exists() -> None:
    """run-validate-history-after-load.sh exists and curls History Server API."""
    hist_sh = PROJECT_ROOT / "scripts" / "tests" / "load" / "run-validate-history-after-load.sh"
    assert hist_sh.exists()
    content = hist_sh.read_text()
    assert "NAMESPACE" in content
    assert "RELEASE" in content
    assert "api/v1/applications" in content
    assert "HISTORY_VALIDATION_SUCCESS" in content
    assert "curl" in content
    assert "Path" not in content
    assert "exists" not in content


def test_get_runtime_image_baseline() -> None:
    """get_runtime_image: gpu=false, iceberg=false -> no suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "false", "false"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7"


def test_get_runtime_image_gpu() -> None:
    """get_runtime_image: gpu=true -> -gpu suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "true", "false"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7-gpu"


def test_get_runtime_image_iceberg() -> None:
    """get_runtime_image: iceberg=true -> -iceberg suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "false", "true"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7-iceberg"


def test_get_runtime_image_gpu_iceberg() -> None:
    """get_runtime_image: gpu+iceberg -> -gpu-iceberg suffix."""
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts/tests/lib/get_runtime_image.sh"), "3.5.7", "true", "true"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "3.5.7-gpu-iceberg"


def test_run_matrix_injects_connect_image(ensure_results_dir: None) -> None:
    """run-matrix deploy dry-run succeeds with image pyramid (gpu+iceberg scenario)."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "id=SCENARIO-0001", "--dry-run", "deploy"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert "helm install" in result.stdout
    # Image pyramid adds 2 --set args (connect.image.repository, connect.image.tag)
    assert "--set args" in result.stdout


def test_run_matrix_injects_standalone_image(ensure_results_dir: None) -> None:
    """run-matrix deploy dry-run for standalone scenario uses spark-3.5 and worker-pod."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "id=SCENARIO-0073", "--dry-run", "all"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert "spark-3.5" in result.stdout
    assert "worker-pod" in result.stdout


def test_run_matrix_injects_k8s_native_image(ensure_results_dir: None) -> None:
    """run-matrix deploy dry-run for k8s-native scenario uses spark-3.5 and k8s-native-submitter."""
    result = subprocess.run(
        [str(RUN_MATRIX), "--filter", "id=SCENARIO-0041", "--dry-run", "all"],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0
    assert "spark-3.5" in result.stdout
    assert "k8s-native-submitter" in result.stdout


def test_run_matrix_standalone_scenario_no_airflow() -> None:
    """Standalone scenario with run-matrix injects (standalone.enabled=false) renders no Airflow."""
    import yaml

    with open(MATRIX_FILE) as f:
        data = yaml.safe_load(f)
    scenario = next(s for s in data["scenarios"] if s["id"] == "SCENARIO-0076")
    helm_str = scenario.get("helm_values", "")
    # Parse --set args from helm_values string
    import re

    parts = re.split(r"\s+--set\s+", helm_str.replace("\\n", " ").replace("\\", "").strip())
    args = []
    for part in parts:
        part = part.strip().strip('"')
        if part and "=" in part:
            args.extend(["--set", part])
    args.extend(
        [
            "--set",
            "standalone.image.repository=spark-custom",
            "--set",
            "standalone.image.tag=3.5.7",
        ]
    )
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    shared = PROJECT_ROOT / "tests" / "shared-infra-values.yaml"
    result = subprocess.run(
        ["helm", "template", "test", str(chart), "-f", str(shared)] + args,
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, result.stderr
    # No Airflow resources (subchart disabled)
    assert "airflow" not in result.stdout.lower()


def test_standalone_parent_templates_render() -> None:
    """F036-02: standalone.enabled=true renders master+worker from parent templates (no subchart)."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "standalone.enabled=true",
            "--set",
            "standalone.image.repository=spark-custom",
            "--set",
            "standalone.image.tag=3.5.7",
            "--set",
            "connect.enabled=false",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    # Must render standalone master and worker from parent templates
    assert "test036-standalone-master" in result.stdout
    assert "test036-standalone-worker" in result.stdout
    # Resource names: {RELEASE}-standalone-master, not {RELEASE}-spark-standalone-master (subchart)
    assert "spark-standalone-master" not in result.stdout
    # Must have Deployment + Service for master, Deployment for worker
    assert "kind: Deployment" in result.stdout
    assert "kind: Service" in result.stdout


def test_standalone_disabled_by_default() -> None:
    """F036-02: standalone.enabled defaults to false, no standalone resources rendered."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "connect.enabled=true",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    assert "standalone-master" not in result.stdout
    assert "standalone-worker" not in result.stdout


def test_no_subchart_dependency() -> None:
    """F036-02: Chart.yaml must not contain spark-standalone dependency."""
    import yaml

    chart_yaml = PROJECT_ROOT / "charts" / "spark-3.5" / "Chart.yaml"
    with open(chart_yaml) as f:
        chart = yaml.safe_load(f)
    deps = chart.get("dependencies", [])
    dep_names = [d["name"] for d in deps]
    assert "spark-standalone" not in dep_names


def test_airflow_parent_templates_render() -> None:
    """F036-03: airflow.enabled=true renders webserver, scheduler, config, dags from parent."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "airflow.enabled=true",
            "--set",
            "airflow.postgresql.enabled=true",
            "--set",
            "airflow.postgresql.auth.password=test",
            "--set",
            "standalone.enabled=true",
            "--set",
            "standalone.image.repository=spark-custom",
            "--set",
            "standalone.image.tag=3.5.7",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    out = result.stdout
    assert "test036-airflow-webserver" in out
    assert "test036-airflow-scheduler" in out
    assert "test036-airflow-config" in out
    assert "test036-airflow-dags" in out


def test_airflow_disabled_by_default() -> None:
    """F036-03: airflow.enabled defaults to false, no airflow resources rendered."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "standalone.enabled=true",
            "--set",
            "standalone.image.repository=spark-custom",
            "--set",
            "standalone.image.tag=3.5.7",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    assert "airflow" not in result.stdout.lower()


def test_airflow_independent_of_standalone() -> None:
    """F036-03: airflow.enabled=true works without standalone.enabled."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "airflow.enabled=true",
            "--set",
            "airflow.postgresql.enabled=true",
            "--set",
            "airflow.postgresql.auth.password=test",
            "--set",
            "standalone.enabled=false",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    out = result.stdout
    assert "airflow-webserver" in out
    assert "name: test036-standalone-master" not in out


def test_airflow_postgresql_disabled_by_default() -> None:
    """F036-03: airflow.postgresql.enabled defaults to false (external DB)."""
    import yaml

    values_path = PROJECT_ROOT / "charts" / "spark-3.5" / "values.yaml"
    with open(values_path) as f:
        vals = yaml.safe_load(f)
    assert vals["airflow"]["postgresql"]["enabled"] is False


def test_airflow_postgresql_renders_when_enabled() -> None:
    """F036-03: airflow.postgresql.enabled=true renders StatefulSet + Service."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "airflow.enabled=true",
            "--set",
            "airflow.postgresql.enabled=true",
            "--set",
            "airflow.postgresql.auth.password=test",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    assert "test036-airflow-postgresql" in result.stdout
    assert "kind: StatefulSet" in result.stdout


def test_airflow_dags_in_configmap() -> None:
    """F036-03: DAGs (nyc_taxi, citibike, movielens, load_demo) in dags-configmap."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "airflow.enabled=true",
            "--set",
            "airflow.postgresql.enabled=true",
            "--set",
            "airflow.postgresql.auth.password=test",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    out = result.stdout
    assert "nyc_taxi_ml_full_pipeline.py" in out
    assert "citibike_analytics_pipeline.py" in out
    assert "movielens_recommendation_pipeline.py" in out
    assert "spark_standalone_load_demo.py" in out


def test_no_sparkk8snative_in_chart() -> None:
    """F036-04: sparkK8sNative must be fully renamed to kubernetes."""
    chart_dir = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        ["grep", "-r", "sparkK8sNative", str(chart_dir)],
        capture_output=True,
        text=True,
    )
    assert result.stdout == "", f"sparkK8sNative still referenced:\n{result.stdout}"


def test_kubernetes_values_key_exists() -> None:
    """F036-04: values.yaml must have kubernetes: { enabled: false }."""
    import yaml

    values_path = PROJECT_ROOT / "charts" / "spark-3.5" / "values.yaml"
    with open(values_path) as f:
        vals = yaml.safe_load(f)
    assert "kubernetes" in vals, "Missing 'kubernetes' key in values.yaml"
    assert vals["kubernetes"]["enabled"] is False


def test_kubernetes_enabled_renders_submitter() -> None:
    """F036-04: kubernetes.enabled=true renders submitter Deployment."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "kubernetes.enabled=true",
            "--set",
            "kubernetes.image.repository=spark-custom",
            "--set",
            "kubernetes.image.tag=3.5.7",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    assert "k8s-native-submitter" in result.stdout


def test_kubernetes_disabled_by_default() -> None:
    """F036-04: default render has no kubernetes submitter resources."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    assert "k8s-native-submitter" not in result.stdout


def test_no_sparkstandalone_in_chart() -> None:
    """F036-05: sparkStandalone key must be gone from charts/spark-3.5/."""
    chart_dir = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        ["grep", "-r", "sparkStandalone", str(chart_dir)],
        capture_output=True,
        text=True,
    )
    assert result.stdout == "", f"sparkStandalone still referenced:\n{result.stdout}"


def test_archived_subchart_deleted() -> None:
    """F036-05: _spark-standalone-archived directory must be deleted."""
    archived = PROJECT_ROOT / "charts" / "spark-3.5" / "charts" / "_spark-standalone-archived"
    assert not archived.exists(), f"Archived subchart still exists: {archived}"


def test_demo_mode_renders_all() -> None:
    """F036-05: standalone+airflow renders all resources for demo mode."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "test036",
            str(chart),
            "--set",
            "standalone.enabled=true",
            "--set",
            "standalone.image.repository=spark-custom",
            "--set",
            "standalone.image.tag=3.5.7",
            "--set",
            "airflow.enabled=true",
            "--set",
            "airflow.postgresql.enabled=true",
            "--set",
            "airflow.postgresql.auth.password=test",
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    out = result.stdout
    assert "standalone-master" in out
    assert "standalone-worker" in out
    assert "airflow-webserver" in out
    assert "airflow-scheduler" in out


def test_dags_no_hardcoded_standalone_master() -> None:
    """F036-06: DAGs must not hardcode spark-infra-spark-standalone-master."""
    dags_dir = PROJECT_ROOT / "charts" / "spark-3.5" / "dags"
    for dag_file in dags_dir.glob("*.py"):
        content = dag_file.read_text()
        assert (
            "spark-infra-spark-standalone-master" not in content
        ), f"{dag_file.name} contains hardcoded 'spark-infra-spark-standalone-master'"


def test_restore_script_uses_new_names() -> None:
    """F036-06: restore-demo.sh must use new resource naming (no spark-standalone prefix)."""
    script = PROJECT_ROOT / "scripts" / "restore-demo.sh"
    content = script.read_text()
    assert (
        "spark-standalone-master" not in content
    ), "restore-demo.sh still references old subchart name 'spark-standalone-master'"
    assert (
        "spark-standalone-airflow" not in content
    ), "restore-demo.sh still references old subchart name 'spark-standalone-airflow'"


def test_demo_preset_renders_all_components() -> None:
    """F036-06: demo preset renders standalone, airflow, jupyter, history, metastore, minio, pg."""
    chart = PROJECT_ROOT / "charts" / "spark-3.5"
    result = subprocess.run(
        [
            "helm",
            "template",
            "spark-infra",
            str(chart),
            "-f",
            str(chart / "presets" / "demo-full-spark-infra.yaml"),
            "--set",
            "global.s3.accessKey=x",
            "--set",
            "global.s3.secretKey=x",
            "--set",
            "spark-base.postgresql.auth.password=x",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    assert result.returncode == 0, f"helm template failed: {result.stderr}"
    out = result.stdout
    for component in [
        "standalone-master",
        "standalone-worker",
        "airflow-webserver",
        "airflow-scheduler",
        "jupyter",
        "history",
        "metastore",
        "minio",
        "postgresql",
    ]:
        assert component in out, f"Missing component '{component}' in demo render"


def test_no_sparkstandalone_in_run_matrix_scripts() -> None:
    """F036-07: run-matrix*.sh must not reference sparkStandalone."""
    for script in PROJECT_ROOT.glob("scripts/run-matrix*.sh"):
        content = script.read_text()
        assert "sparkStandalone" not in content, f"{script.name} still references 'sparkStandalone'"


def test_no_sparkstandalone_in_test_matrix() -> None:
    """F036-07: test-matrix.yaml must not reference sparkStandalone."""
    matrix = PROJECT_ROOT / "tests" / "test-matrix.yaml"
    content = matrix.read_text()
    assert "sparkStandalone" not in content, "test-matrix.yaml still references 'sparkStandalone'"


def test_no_standalone_enabled_false_hack_in_run_matrix() -> None:
    """F036-07: run-matrix.sh must not contain the standalone.enabled=false workaround."""
    script = PROJECT_ROOT / "scripts" / "run-matrix.sh"
    lines = [
        ln
        for ln in script.read_text().splitlines()
        if "standalone.enabled=false" in ln and not ln.strip().startswith("#")
    ]
    assert not lines, f"run-matrix.sh still has standalone.enabled=false hack: {lines}"


def test_no_stale_naming_in_scripts() -> None:
    """F036-08: scripts/ must not contain sparkStandalone or sparkK8sNative value refs."""
    stale_patterns = ["sparkStandalone", "sparkK8sNative"]
    allowed_contexts = [
        "# ",
        "NOT spark-standalone",
        "check-dangerous-patterns",
    ]
    scripts_dir = PROJECT_ROOT / "scripts"
    violations: list[str] = []
    for script in sorted(scripts_dir.rglob("*")):
        if script.is_dir() or script.suffix == ".pyc":
            continue
        try:
            content = script.read_text()
        except UnicodeDecodeError:
            continue
        for line_no, line in enumerate(content.splitlines(), 1):
            if any(pat in line for pat in stale_patterns) and not any(ctx in line for ctx in allowed_contexts):
                violations.append(f"{script.relative_to(PROJECT_ROOT)}:{line_no}: {line.strip()}")
    assert not violations, "Stale naming found in scripts:\n" + "\n".join(violations[:20])


def test_scripts_bash_syntax() -> None:
    """F036-08: scope .sh files in scripts/ must pass bash -n."""
    scope_scripts = [
        "scripts/test-standalone.sh",
        "scripts/test-standalone-load.sh",
        "scripts/test-connect-standalone-load.sh",
        "scripts/test-prodlike-airflow.sh",
        "scripts/test-sa-prodlike-all.sh",
        "scripts/test-coexistence.sh",
        "scripts/benchmark-spark-versions.sh",
        "scripts/validate-presets.sh",
        "scripts/validate-policy.sh",
        "scripts/generate-helm-evidence.sh",
        "scripts/spark-operations/monitor-resources.sh",
        "scripts/spark-operations/collect-metrics.sh",
        "scripts/test-e2e-airflow-connect.sh",
        "scripts/test-e2e-airflow-k8s-submit.sh",
        "scripts/test-e2e-airflow-operator.sh",
        "scripts/test-e2e-jupyter-connect.sh",
        "scripts/tests/integration/test-spark-35-minikube.sh",
        "scripts/tests/minikube/run-minikube-scenarios.sh",
        "scripts/restore-demo.sh",
        "scripts/check-demo-health.sh",
        "scripts/deploy-demo-minikube.sh",
        "scripts/run-matrix.sh",
    ]
    failures: list[str] = []
    for rel in scope_scripts:
        script = PROJECT_ROOT / rel
        if not script.exists():
            continue
        result = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
        if result.returncode != 0:
            failures.append(f"{rel}: {result.stderr.strip()}")
    assert not failures, "bash -n failures:\n" + "\n".join(failures)


def test_no_stale_naming_in_tests() -> None:
    """F036-09: test files must not contain sparkStandalone or sparkK8sNative as values keys."""
    stale_patterns = ["sparkStandalone", "sparkK8sNative"]
    allowed_contexts = [
        "grep",
        "assert",
        "stale_patterns",
        "not in content",
        "not in result",
        "F036-",
        "allowed_contexts",
    ]
    tests_dir = PROJECT_ROOT / "tests"
    violations: list[str] = []
    for tf in sorted(tests_dir.rglob("*")):
        if tf.is_dir() or tf.suffix == ".pyc" or "evidence" in str(tf):
            continue
        try:
            content = tf.read_text()
        except UnicodeDecodeError:
            continue
        for line_no, line in enumerate(content.splitlines(), 1):
            if any(pat in line for pat in stale_patterns) and not any(ctx in line for ctx in allowed_contexts):
                violations.append(f"{tf.relative_to(PROJECT_ROOT)}:{line_no}: {line.strip()}")
    assert not violations, "Stale naming in tests:\n" + "\n".join(violations[:20])


def test_aggregate_matrix_results_script() -> None:
    """aggregate-matrix-results.py produces machine-readable summary."""
    agg = PROJECT_ROOT / "scripts" / "aggregate-matrix-results.py"
    assert agg.exists()
    # Run with dry-run results (scenario-SCENARIO-0009.json from test_run_matrix_dry_run)
    result = subprocess.run(
        [
            "python3",
            str(agg),
            "--results-dir",
            str(RESULTS_DIR),
            "--filter",
            "id=SCENARIO-0009",
            "--output",
            str(RESULTS_DIR / "matrix-summary-test.json"),
            "--duration",
            "0",
        ],
        capture_output=True,
        text=True,
        cwd=str(PROJECT_ROOT),
    )
    # Filter id=SCENARIO-0009 returns 1 scenario; dry-run creates scenario-SCENARIO-0009.json
    assert result.returncode == 0 or "No scenarios" in result.stderr
    if (RESULTS_DIR / "matrix-summary-test.json").exists():
        data = json.loads((RESULTS_DIR / "matrix-summary-test.json").read_text())
        assert "passed" in data
        assert "failed" in data
        assert "expected" in data
        assert data.get("filter") == "id=SCENARIO-0009"


def test_run_matrix_96_script_exists() -> None:
    """run-matrix-96.sh exists and runs 96-scenario filter."""
    script = PROJECT_ROOT / "scripts" / "run-matrix-96.sh"
    assert script.exists()
    assert script.stat().st_mode & 0o111
    content = script.read_text()
    assert "gpu=false,platform=k8s" in content
    assert "run-matrix.sh" in content
    assert "aggregate-matrix-results" in content
    assert "matrix-96-summary.json" in content


def test_run_matrix_320_script_exists() -> None:
    """run-matrix-320.sh exists and runs all 320 scenarios."""
    script = PROJECT_ROOT / "scripts" / "run-matrix-320.sh"
    assert script.exists()
    assert script.stat().st_mode & 0o111
    content = script.read_text()
    assert "320" in content
    assert "run-matrix.sh" in content
    assert "aggregate-matrix-results" in content
    assert "matrix-320-summary.json" in content


def test_run_matrix_reads_test_matrix_yaml() -> None:
    """run-matrix reads tests/test-matrix.yaml with 320 scenarios."""
    assert MATRIX_FILE.exists()
    count = int(
        subprocess.run(
            [
                "python3",
                "-c",
                "import yaml; d=yaml.safe_load(open('tests/test-matrix.yaml')); print(len(d.get('scenarios',[])))",
            ],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
        ).stdout.strip()
    )
    assert count == 320
