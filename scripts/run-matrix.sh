#!/usr/bin/env bash
# Matrix test runner: deploy → smoke → e2e → load per scenario
# EXECUTES commands, never checks file existence.
# Usage: run-matrix.sh --filter "id=SCENARIO-0009" all
#        run-matrix.sh --filter "gpu=false,platform=k8s" deploy smoke

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MATRIX_FILE="${PROJECT_ROOT}/tests/test-matrix.yaml"
RESULTS_DIR="${PROJECT_ROOT}/tests/results"

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
FILTER=""
LEVELS=""
DRY_RUN=""
SHARED_INFRA=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter) FILTER="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --shared-infra) SHARED_INFRA=1; shift ;;
        all) LEVELS="deploy smoke e2e load"; shift ;;
        deploy|smoke|e2e|load)
            LEVELS="${LEVELS:+$LEVELS }$1"
            shift
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [[ -z "$LEVELS" ]]; then
    echo "Usage: $0 --filter 'id=SCENARIO-0009' all"
    echo "       $0 --filter 'gpu=false' deploy smoke"
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# -----------------------------------------------------------------------------
# Main: Python does the heavy lifting (parse YAML, filter, helm, kubectl)
# -----------------------------------------------------------------------------
exec python3 - "$MATRIX_FILE" "$FILTER" "$LEVELS" "$RESULTS_DIR" "$PROJECT_ROOT" "${DRY_RUN:-}" "${SHARED_INFRA:-}" << 'PYMAIN'
import sys
import json
import subprocess
import os
import re
import time

def parse_helm_values(helm_str):
    """Convert helm_values string to list of --set key=value args."""
    if not helm_str:
        return []
    s = helm_str.replace("\\n", " ").replace("\\", "").strip()
    args = []
    parts = re.split(r"\s+--set\s+", s)
    for part in parts:
        part = part.strip().strip('"')
        if not part or "=" not in part:
            continue
        args.extend(["--set", part])
    return args

def main():
    import yaml
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
    scenarios = data.get("scenarios", [])
    filter_str = sys.argv[2]
    levels = sys.argv[3].split()
    results_dir = sys.argv[4]
    project_root = sys.argv[5]
    dry_run = len(sys.argv) > 6 and sys.argv[6] == "1"
    shared_infra = len(sys.argv) > 7 and sys.argv[7] == "1"

    shared_infra_ns = os.environ.get("SHARED_INFRA_NS", "spark-infra")
    shared_infra_values = os.path.join(project_root, "tests", "shared-infra-values.yaml")

    filters = {}
    if filter_str:
        for part in filter_str.split(","):
            part = part.strip()
            if "=" in part:
                k, v = part.split("=", 1)
                filters[k.strip()] = v.strip()

    def matches(s):
        for k, v in filters.items():
            if k == "id":
                if s.get("id") != v:
                    return False
            else:
                val = s.get(k)
                if val is None:
                    return False
                if isinstance(val, bool):
                    if v.lower() in ("true", "1", "yes") and not val:
                        return False
                    if v.lower() in ("false", "0", "no") and val:
                        return False
                elif str(val) != str(v):
                    return False
        return True

    filtered = [s for s in scenarios if matches(s)]
    if not filtered:
        print("No scenarios match filter", file=sys.stderr)
        sys.exit(1)
    print(f"Running {len(filtered)} scenarios: {', '.join(levels)}", flush=True)

    def get_runtime_image(spark_ver, gpu, iceberg):
        """Return image tag from pyramid: gpu -> -gpu, iceberg -> -iceberg, both -> -gpu-iceberg."""
        tag = str(spark_ver)
        if gpu:
            tag += "-gpu"
        if iceberg:
            tag += "-iceberg"
        return tag

    any_failed = False
    total = len(filtered)
    for idx, s in enumerate(filtered, 1):
        sid = s["id"]
        print(f"[{idx}/{total}] {sid}: starting...", flush=True)
        ns = f"spark-matrix-{sid.lower()}"
        release = sid.lower().replace("-", "")
        spark_ver = str(s.get("spark_version", "3.5.7"))
        # connect=true: spark-4.1 or spark-3.5; connect=false: spark-3.5 only (standalone or k8s-native)
        is_connect = s.get("connect", True)
        k8s_mode = s.get("k8s_mode", "native")
        if is_connect and spark_ver.startswith("4.1"):
            chart = f"{project_root}/charts/spark-4.1"
        else:
            chart = f"{project_root}/charts/spark-3.5"
        helm_args = parse_helm_values(s.get("helm_values", ""))
        img_tag = get_runtime_image(spark_ver, s.get("gpu", False), s.get("iceberg", False))
        if is_connect:
            helm_args.extend(["--set", f"connect.image.repository=spark-custom", "--set", f"connect.image.tag={img_tag}"])
        elif k8s_mode == "native":
            helm_args.extend(["--set", f"kubernetes.image.repository=spark-custom", "--set", f"kubernetes.image.tag={img_tag}"])
        else:
            helm_args.extend([
                "--set", f"standalone.image.repository=spark-custom", "--set", f"standalone.image.tag={img_tag}",
            ])
        # DEPLOY_MODE: connect | k8s-native | standalone
        deploy_mode = "connect" if is_connect else ("k8s-native" if k8s_mode == "native" else "standalone")
        # Shared infra: override MinIO, History, Hive, S3, OTEL (append so overrides scenario)
        if shared_infra and os.path.exists(shared_infra_values):
            helm_args = ["-f", shared_infra_values] + helm_args
            helm_args.extend([
                "--set", "core.minio.enabled=false",
                "--set", "historyServer.enabled=false",
                "--set", "core.hiveMetastore.enabled=false",
                "--set", f"global.s3.endpoint=http://minio.{shared_infra_ns}.svc.cluster.local:9000",
                "--set", "global.s3.accessKey=minioadmin",
                "--set", "global.s3.secretKey=minioadmin",
                "--set", "connect.eventLog.enabled=true",
                "--set", "connect.eventLog.dir=s3a://spark-logs/events",
                "--set", "connect.openTelemetry.enabled=true",
                "--set", f"connect.openTelemetry.endpoint=http://otel-collector.observability.svc.cluster.local:4317",
            ])

        result = {"id": sid, "deploy": "SKIP", "smoke": "SKIP", "e2e": "SKIP", "load": "SKIP", "history": "SKIP"}
        failed = False

        if dry_run:
            cmd = ["helm", "install", release, chart, "-n", ns, "--create-namespace", "--timeout", "10m", "--wait"] + helm_args
            exec_target = "connect-pod" if deploy_mode == "connect" else ("k8s-native-submitter" if deploy_mode == "k8s-native" else "worker-pod")
            print(f"[dry-run] {sid}: helm install {release} {chart} -n {ns} ... ({len(helm_args)} --set args)")
            if "smoke" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <{exec_target}> -- spark-submit smoke_1k.py")
            if "e2e" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <{exec_target}> -- spark-submit e2e_10k.py")
            if "load" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <{exec_target}> -- spark-submit load_s3.py")
            out = os.path.join(results_dir, f"scenario-{sid}.json")
            with open(out, "w") as f:
                json.dump({**result, "dry_run": True}, f, indent=2)
            continue

        try:
            if "deploy" in levels:
                print(f"  {sid}: deploy...", flush=True)
                deploy_script = os.path.join(project_root, "scripts", "tests", "lib", "deploy.sh")
                deploy_timeout = os.environ.get("DEPLOY_TIMEOUT", "300")
                deploy_env = {**os.environ, "DEPLOY_TIMEOUT": deploy_timeout, "DEPLOY_MODE": deploy_mode}
                r = subprocess.run(
                    ["bash", deploy_script, release, chart, ns] + helm_args,
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env=deploy_env,
                )
                if r.returncode != 0:
                    result["deploy"] = "FAIL"
                    result["deploy_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["deploy"] = "PASS"
                print(f"  {sid}: deploy {result['deploy']}", flush=True)

            if not failed and "smoke" in levels:
                print(f"  {sid}: smoke...", flush=True)
                smoke_script = os.path.join(project_root, "scripts", "tests", "smoke", "run-smoke-against-release.sh")
                smoke_env = {**os.environ, "NAMESPACE": ns, "RELEASE": release, "DEPLOY_MODE": deploy_mode}
                if deploy_mode == "k8s-native":
                    smoke_env["SPARK_IMAGE"] = f"spark-custom:{img_tag}"
                if shared_infra:
                    smoke_env["SHARED_INFRA_NS"] = shared_infra_ns
                r = subprocess.run(
                    ["bash", smoke_script],
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env=smoke_env,
                )
                if r.returncode != 0:
                    result["smoke"] = "FAIL"
                    result["smoke_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["smoke"] = "PASS"
                print(f"  {sid}: smoke {result['smoke']}", flush=True)

            if not failed and "e2e" in levels:
                print(f"  {sid}: e2e...", flush=True)
                e2e_script = os.path.join(project_root, "scripts", "tests", "e2e", "run-e2e-against-release.sh")
                e2e_env = {**os.environ, "NAMESPACE": ns, "RELEASE": release, "DEPLOY_MODE": deploy_mode}
                if deploy_mode == "k8s-native":
                    e2e_env["SPARK_IMAGE"] = f"spark-custom:{img_tag}"
                if shared_infra:
                    e2e_env["SHARED_INFRA_NS"] = shared_infra_ns
                r = subprocess.run(
                    ["bash", e2e_script],
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env=e2e_env,
                )
                if r.returncode != 0:
                    result["e2e"] = "FAIL"
                    result["e2e_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["e2e"] = "PASS"
                print(f"  {sid}: e2e {result['e2e']}", flush=True)

            if not failed and "load" in levels:
                print(f"  {sid}: load...", flush=True)
                load_script = os.path.join(project_root, "scripts", "tests", "load", "run-load-against-release.sh")
                load_env = {**os.environ, "NAMESPACE": ns, "RELEASE": release, "DEPLOY_MODE": deploy_mode}
                if deploy_mode == "k8s-native":
                    load_env["SPARK_IMAGE"] = f"spark-custom:{img_tag}"
                if shared_infra:
                    load_env["SHARED_INFRA_NS"] = shared_infra_ns
                r = subprocess.run(
                    ["bash", load_script],
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env=load_env,
                )
                if r.returncode != 0:
                    result["load"] = "FAIL"
                    result["load_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["load"] = "PASS"
                print(f"  {sid}: load {result['load']}", flush=True)
                if result["load"] == "PASS":
                    # After load: validate application visible in History Server
                    history_script = os.path.join(project_root, "scripts", "tests", "load", "run-validate-history-after-load.sh")
                    history_env = {**os.environ, "NAMESPACE": ns, "RELEASE": release}
                    if shared_infra:
                        history_env["SHARED_INFRA_NS"] = shared_infra_ns
                    r2 = subprocess.run(
                        ["bash", history_script],
                        capture_output=True,
                        text=True,
                        cwd=project_root,
                        env=history_env,
                    )
                    if r2.returncode != 0:
                        result["history"] = "FAIL"
                        result["history_error"] = (r2.stderr or r2.stdout or "")[:500]
                        failed = True
                    else:
                        result["history"] = "PASS"
                    print(f"  {sid}: history {result['history']}", flush=True)

        finally:
            # Cleanup: helm uninstall then delete namespace. Must complete before next scenario.
            r_helm = subprocess.run(
                ["helm", "uninstall", release, "-n", ns, "--wait"],
                capture_output=True,
                text=True,
            )
            if r_helm.returncode != 0 and "release: not found" not in (r_helm.stderr or "").lower():
                print(f"[cleanup] {sid}: helm uninstall warning: {r_helm.stderr or r_helm.stdout}", file=sys.stderr)
            r_ns = subprocess.run(
                ["kubectl", "delete", "namespace", ns, "--timeout=120s", "--ignore-not-found=true"],
                capture_output=True,
                text=True,
            )
            if r_ns.returncode != 0:
                print(f"[cleanup] {sid}: kubectl delete namespace warning: {r_ns.stderr}", file=sys.stderr)
            # Wait for namespace to be fully gone before next scenario (avoid Terminating accumulation)
            for _ in range(60):
                r = subprocess.run(
                    ["kubectl", "get", "namespace", ns],
                    capture_output=True,
                    text=True,
                )
                if r.returncode != 0:
                    break
                time.sleep(2)

        out = os.path.join(results_dir, f"scenario-{sid}.json")
        with open(out, "w") as f:
            json.dump(result, f, indent=2)
        print(json.dumps(result))

        if failed:
            any_failed = True

    if any_failed:
        sys.exit(1)

if __name__ == "__main__":
    main()
PYMAIN
