import os
import re
import subprocess
import sys


def parse_helm_values(helm_str):
    if not helm_str:
        return []
    cleaned = helm_str.replace("\\n", " ").replace("\\", "").strip()
    args = []
    for part in re.split(r"\s+--set\s+", cleaned):
        part = part.strip().strip('"')
        if part and "=" in part:
            args.extend(["--set", part])
    return args


def parse_filters(filter_str):
    filters = {}
    if not filter_str:
        return filters
    for part in filter_str.split(","):
        part = part.strip()
        if "=" in part:
            key, value = part.split("=", 1)
            filters[key.strip()] = value.strip()
    return filters


def matches_filters(scenario, filters):
    for key, value in filters.items():
        actual = scenario.get(key)
        if key == "id":
            if actual != value:
                return False
            continue
        if actual is None:
            return False
        if isinstance(actual, bool):
            lowered = value.lower()
            if lowered in {"true", "1", "yes"} and not actual:
                return False
            if lowered in {"false", "0", "no"} and actual:
                return False
        elif str(actual) != str(value):
            return False
    return True


def get_runtime_image(spark_ver, gpu, iceberg):
    tag = str(spark_ver)
    if gpu:
        tag += "-gpu"
    if iceberg:
        tag += "-iceberg"
    return tag


def ensure_shared_infra_ready(project_root, dry_run, shared_infra, shared_infra_ns, allow_shared_with_demo):
    if dry_run or not shared_infra:
        return
    health_script = os.path.join(project_root, "scripts", "check-demo-health.sh")
    if os.path.exists(health_script):
        health = subprocess.run(["bash", health_script, "--quiet"], capture_output=True, text=True, cwd=project_root)
        if health.returncode != 0:
            print(
                "Shared infra health check failed. Run ./scripts/restore-demo.sh or ./scripts/deploy-shared-infra-minikube.sh first.",
                file=sys.stderr,
            )
            if health.stdout:
                print(health.stdout, file=sys.stderr)
            if health.stderr:
                print(health.stderr, file=sys.stderr)
            sys.exit(1)
    if allow_shared_with_demo:
        return
    selectors = [
        "app.kubernetes.io/component=standalone-worker",
        "app.kubernetes.io/component=airflow-webserver",
        "app.kubernetes.io/component=jupyter",
    ]
    for selector in selectors:
        exists = subprocess.run(
            ["kubectl", "get", "deployment", "-n", shared_infra_ns, "-l", selector, "--no-headers"],
            capture_output=True,
            text=True,
        )
        if exists.returncode == 0 and exists.stdout.strip():
            print(
                "Shared infra namespace has demo workloads that consume matrix capacity. "
                "Run ./scripts/deploy-shared-infra-minikube.sh before matrix or set MATRIX_ALLOW_DEMO_INFRA=1 to bypass.",
                file=sys.stderr,
            )
            print(f"Detected selector: {selector}", file=sys.stderr)
            sys.exit(1)


def scenario_plan(scenario, project_root, shared_infra, shared_infra_values, shared_infra_ns):
    spark_ver = str(scenario.get("spark_version", "3.5.7"))
    is_connect = scenario.get("connect", True)
    k8s_mode = scenario.get("k8s_mode", "native")
    chart = (
        f"{project_root}/charts/spark-4.1"
        if is_connect and spark_ver.startswith("4.1") and k8s_mode != "standalone"
        else f"{project_root}/charts/spark-3.5"
    )
    helm_args = parse_helm_values(scenario.get("helm_values", ""))
    img_tag = get_runtime_image(spark_ver, scenario.get("gpu", False), scenario.get("iceberg", False))
    helm_args.extend(["--set", "jupyter.enabled=false"])
    if is_connect and k8s_mode == "standalone":
        helm_args.extend(["--set", "connect.backendMode=standalone"])
    if scenario.get("openlineage") and not spark_ver.startswith("4.1"):
        helm_args.extend(["--set", "features.openLineage.enabled=true"])
    if is_connect:
        helm_args.extend(["--set", "connect.image.repository=spark-custom", "--set", f"connect.image.tag={img_tag}"])
        if k8s_mode == "standalone":
            helm_args.extend(
                ["--set", "standalone.image.repository=spark-custom", "--set", f"standalone.image.tag={img_tag}"]
            )
    elif k8s_mode == "native":
        helm_args.extend(
            ["--set", "kubernetes.image.repository=spark-custom", "--set", f"kubernetes.image.tag={img_tag}"]
        )
    else:
        helm_args.extend(
            ["--set", "standalone.image.repository=spark-custom", "--set", f"standalone.image.tag={img_tag}"]
        )
    deploy_mode = "connect" if is_connect else ("k8s-native" if k8s_mode == "native" else "standalone")
    if shared_infra and os.path.exists(shared_infra_values):
        helm_args = ["-f", shared_infra_values] + helm_args
        helm_args.extend(
            [
                "--set",
                "core.minio.enabled=false",
                "--set",
                "spark-base.minio.enabled=false",
                "--set",
                "spark-base.core.minio.enabled=false",
                "--set",
                "historyServer.enabled=false",
                "--set",
                "core.hiveMetastore.enabled=false",
                "--set",
                "hiveMetastore.enabled=false",
                "--set",
                "spark-base.hiveMetastore.enabled=false",
                "--set",
                "spark-base.core.hiveMetastore.enabled=false",
                "--set",
                "monitoring.prometheus.enabled=false",
                "--set",
                "monitoring.grafana.enabled=false",
                "--set",
                f"global.s3.endpoint=http://minio.{shared_infra_ns}.svc.cluster.local:9000",
                "--set",
                "global.s3.accessKey=minioadmin",
                "--set",
                "global.s3.secretKey=minioadmin",
                "--set",
                "connect.eventLog.enabled=true",
                "--set",
                "connect.eventLog.dir=s3a://spark-logs/events",
                "--set",
                "connect.openTelemetry.enabled=false",
            ]
        )
    return chart, helm_args, img_tag, deploy_mode
