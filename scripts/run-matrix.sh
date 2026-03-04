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
while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter) FILTER="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
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
exec python3 - "$MATRIX_FILE" "$FILTER" "$LEVELS" "$RESULTS_DIR" "$PROJECT_ROOT" "${DRY_RUN:-}" << 'PYMAIN'
import sys
import json
import subprocess
import os
import re

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

    def get_runtime_image(spark_ver, gpu, iceberg):
        """Return image tag from pyramid: gpu -> -gpu, iceberg -> -iceberg, both -> -gpu-iceberg."""
        tag = str(spark_ver)
        if gpu:
            tag += "-gpu"
        if iceberg:
            tag += "-iceberg"
        return tag

    any_failed = False
    for s in filtered:
        sid = s["id"]
        ns = f"spark-matrix-{sid.lower()}"
        release = sid.lower().replace("-", "")
        spark_ver = str(s.get("spark_version", "3.5.7"))
        chart = f"{project_root}/charts/spark-4.1" if spark_ver.startswith("4.1") else f"{project_root}/charts/spark-3.5"
        helm_args = parse_helm_values(s.get("helm_values", ""))
        # Inject runtime image from pyramid (gpu, iceberg dimensions)
        img_tag = get_runtime_image(spark_ver, s.get("gpu", False), s.get("iceberg", False))
        helm_args.extend(["--set", f"connect.image.repository=spark-custom", "--set", f"connect.image.tag={img_tag}"])

        result = {"id": sid, "deploy": "SKIP", "smoke": "SKIP", "e2e": "SKIP", "load": "SKIP", "history": "SKIP"}
        failed = False

        if dry_run:
            cmd = ["helm", "install", release, chart, "-n", ns, "--create-namespace", "--timeout", "10m", "--wait"] + helm_args
            print(f"[dry-run] {sid}: helm install {release} {chart} -n {ns} ... ({len(helm_args)} --set args)")
            if "smoke" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <connect-pod> -- spark-submit smoke_1k.py")
            if "e2e" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <connect-pod> -- spark-submit e2e_10k.py")
            if "load" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <connect-pod> -- spark-submit load_s3.py")
            out = os.path.join(results_dir, f"scenario-{sid}.json")
            with open(out, "w") as f:
                json.dump({**result, "dry_run": True}, f, indent=2)
            continue

        try:
            if "deploy" in levels:
                deploy_script = os.path.join(project_root, "scripts", "tests", "lib", "deploy.sh")
                deploy_timeout = os.environ.get("DEPLOY_TIMEOUT", "300")
                cmd = ["bash", deploy_script, release, chart, ns] + helm_args
                r = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env={**os.environ, "DEPLOY_TIMEOUT": deploy_timeout},
                )
                if r.returncode != 0:
                    result["deploy"] = "FAIL"
                    result["deploy_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["deploy"] = "PASS"

            if not failed and "smoke" in levels:
                smoke_script = os.path.join(project_root, "scripts", "tests", "smoke", "run-smoke-against-release.sh")
                r = subprocess.run(
                    ["bash", smoke_script],
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env={**os.environ, "NAMESPACE": ns},
                )
                if r.returncode != 0:
                    result["smoke"] = "FAIL"
                    result["smoke_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["smoke"] = "PASS"

            if not failed and "e2e" in levels:
                e2e_script = os.path.join(project_root, "scripts", "tests", "e2e", "run-e2e-against-release.sh")
                r = subprocess.run(
                    ["bash", e2e_script],
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env={**os.environ, "NAMESPACE": ns},
                )
                if r.returncode != 0:
                    result["e2e"] = "FAIL"
                    result["e2e_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["e2e"] = "PASS"

            if not failed and "load" in levels:
                load_script = os.path.join(project_root, "scripts", "tests", "load", "run-load-against-release.sh")
                r = subprocess.run(
                    ["bash", load_script],
                    capture_output=True,
                    text=True,
                    cwd=project_root,
                    env={**os.environ, "NAMESPACE": ns, "RELEASE": release},
                )
                if r.returncode != 0:
                    result["load"] = "FAIL"
                    result["load_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["load"] = "PASS"
                    # After load: validate application visible in History Server
                    history_script = os.path.join(project_root, "scripts", "tests", "load", "run-validate-history-after-load.sh")
                    r2 = subprocess.run(
                        ["bash", history_script],
                        capture_output=True,
                        text=True,
                        cwd=project_root,
                        env={**os.environ, "NAMESPACE": ns, "RELEASE": release},
                    )
                    if r2.returncode != 0:
                        result["history"] = "FAIL"
                        result["history_error"] = (r2.stderr or r2.stdout or "")[:500]
                        failed = True
                    else:
                        result["history"] = "PASS"

        finally:
            subprocess.run(["helm", "uninstall", release, "-n", ns], capture_output=True)
            subprocess.run(["kubectl", "delete", "namespace", ns, "--timeout=60s"], capture_output=True)

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
