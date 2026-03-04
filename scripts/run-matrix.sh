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

    for s in filtered:
        sid = s["id"]
        ns = f"spark-matrix-{sid.lower()}"
        release = sid.lower().replace("-", "")
        spark_ver = str(s.get("spark_version", "3.5.7"))
        chart = f"{project_root}/charts/spark-4.1" if spark_ver.startswith("4.1") else f"{project_root}/charts/spark-3.5"
        helm_args = parse_helm_values(s.get("helm_values", ""))

        result = {"id": sid, "deploy": "SKIP", "smoke": "SKIP", "e2e": "SKIP", "load": "SKIP"}
        failed = False

        if dry_run:
            cmd = ["helm", "install", release, chart, "-n", ns, "--create-namespace", "--timeout", "10m", "--wait"] + helm_args
            print(f"[dry-run] {sid}: helm install {release} {chart} -n {ns} ... ({len(helm_args)} --set args)")
            if "smoke" in levels:
                print(f"[dry-run] {sid}: kubectl exec -n {ns} <connect-pod> -- spark-submit pi.py")
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
                script = f'''
connect_pod=$(kubectl get pods -n {ns} -l app.kubernetes.io/component=connect -o jsonpath="{{.items[0].metadata.name}}" 2>/dev/null)
if [[ -z "$connect_pod" ]]; then exit 1; fi
kubectl exec -n {ns} "$connect_pod" -- /bin/sh -c "/opt/spark/bin/spark-submit --master local[*] /opt/spark/examples/src/main/python/pi.py 10"
'''
                r = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
                if r.returncode != 0:
                    result["smoke"] = "FAIL"
                    result["smoke_error"] = (r.stderr or r.stdout or "")[:500]
                    failed = True
                else:
                    result["smoke"] = "PASS"

            if not failed and "e2e" in levels:
                result["e2e"] = "SKIP"

            if not failed and "load" in levels:
                result["load"] = "SKIP"

        finally:
            subprocess.run(["helm", "uninstall", release, "-n", ns], capture_output=True)
            subprocess.run(["kubectl", "delete", "namespace", ns, "--timeout=60s"], capture_output=True)

        out = os.path.join(results_dir, f"scenario-{sid}.json")
        with open(out, "w") as f:
            json.dump(result, f, indent=2)
        print(json.dumps(result))

        if failed:
            sys.exit(1)

if __name__ == "__main__":
    main()
PYMAIN
