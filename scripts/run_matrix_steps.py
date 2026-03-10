import json
import os
import subprocess
import time


def _run(script, env, project_root):
    return subprocess.run(["bash", script], capture_output=True, text=True, cwd=project_root, env=env)


def _capture_failure(result, field, status, failed):
    if result.returncode == 0:
        status[field] = "PASS"
        return failed
    full = (result.stderr or "") + (result.stdout or "")
    if full:
        print(full, file=os.sys.stderr, flush=True)
    status[field] = "FAIL"
    status[f"{field}_error"] = full[:500]
    return True


def _cleanup(release, namespace):
    uninstall = subprocess.run(
        ["helm", "uninstall", release, "-n", namespace, "--wait"], capture_output=True, text=True
    )
    if uninstall.returncode != 0 and "release: not found" not in (uninstall.stderr or "").lower():
        print(
            f"[cleanup] {release}: helm uninstall warning: {uninstall.stderr or uninstall.stdout}", file=os.sys.stderr
        )
    delete_ns = subprocess.run(
        ["kubectl", "delete", "namespace", namespace, "--timeout=120s", "--ignore-not-found=true"],
        capture_output=True,
        text=True,
    )
    if delete_ns.returncode != 0:
        print(f"[cleanup] {release}: kubectl delete namespace warning: {delete_ns.stderr}", file=os.sys.stderr)
    for _ in range(60):
        if subprocess.run(["kubectl", "get", "namespace", namespace], capture_output=True, text=True).returncode != 0:
            break
        time.sleep(2)


def run_scenario(
    idx,
    total,
    scenario,
    levels,
    results_dir,
    project_root,
    dry_run,
    shared_infra,
    shared_infra_ns,
    chart,
    helm_args,
    img_tag,
    deploy_mode,
):
    sid = scenario["id"]
    namespace = f"spark-matrix-{sid.lower()}"
    release = sid.lower().replace("-", "")
    print(f"[{idx}/{total}] {sid}: starting...", flush=True)
    result = {"id": sid, "deploy": "SKIP", "smoke": "SKIP", "e2e": "SKIP", "load": "SKIP", "history": "SKIP"}
    failed = False
    if dry_run:
        exec_target = (
            "connect-pod"
            if deploy_mode == "connect"
            else ("k8s-native-submitter" if deploy_mode == "k8s-native" else "worker-pod")
        )
        print(f"[dry-run] {sid}: helm install {release} {chart} -n {namespace} ... ({len(helm_args)} --set args)")
        if "smoke" in levels:
            print(f"[dry-run] {sid}: kubectl exec -n {namespace} <{exec_target}> -- spark-submit smoke_1k.py")
        if "e2e" in levels:
            print(f"[dry-run] {sid}: kubectl exec -n {namespace} <{exec_target}> -- spark-submit e2e_10k.py")
        if "load" in levels:
            print(f"[dry-run] {sid}: kubectl exec -n {namespace} <{exec_target}> -- spark-submit load_s3.py")
        with open(os.path.join(results_dir, f"scenario-{sid}.json"), "w") as fh:
            json.dump({**result, "dry_run": True}, fh, indent=2)
        return False
    try:
        if "deploy" in levels:
            print(f"  {sid}: deploy...", flush=True)
            deploy_env = {
                **os.environ,
                "DEPLOY_TIMEOUT": os.environ.get("DEPLOY_TIMEOUT", "300"),
                "DEPLOY_MODE": deploy_mode,
            }
            deploy_script = os.path.join(project_root, "scripts", "tests", "lib", "deploy.sh")
            deploy = subprocess.run(
                ["bash", deploy_script, release, chart, namespace] + helm_args,
                capture_output=True,
                text=True,
                cwd=project_root,
                env=deploy_env,
            )
            failed = _capture_failure(deploy, "deploy", result, failed)
            print(f"  {sid}: deploy {result['deploy']}", flush=True)
        if not failed and "smoke" in levels:
            print(f"  {sid}: smoke...", flush=True)
            env = {**os.environ, "NAMESPACE": namespace, "RELEASE": release, "DEPLOY_MODE": deploy_mode}
            if deploy_mode == "k8s-native":
                env["SPARK_IMAGE"] = f"spark-custom:{img_tag}"
            if shared_infra:
                env["SHARED_INFRA_NS"] = shared_infra_ns
            failed = _capture_failure(
                _run(
                    os.path.join(project_root, "scripts", "tests", "smoke", "run-smoke-against-release.sh"),
                    env,
                    project_root,
                ),
                "smoke",
                result,
                failed,
            )
            print(f"  {sid}: smoke {result['smoke']}", flush=True)
        if not failed and "e2e" in levels:
            print(f"  {sid}: e2e...", flush=True)
            env = {**os.environ, "NAMESPACE": namespace, "RELEASE": release, "DEPLOY_MODE": deploy_mode}
            if deploy_mode == "k8s-native":
                env["SPARK_IMAGE"] = f"spark-custom:{img_tag}"
            if shared_infra:
                env["SHARED_INFRA_NS"] = shared_infra_ns
            failed = _capture_failure(
                _run(
                    os.path.join(project_root, "scripts", "tests", "e2e", "run-e2e-against-release.sh"),
                    env,
                    project_root,
                ),
                "e2e",
                result,
                failed,
            )
            print(f"  {sid}: e2e {result['e2e']}", flush=True)
        if not failed and "load" in levels:
            print(f"  {sid}: load...", flush=True)
            env = {**os.environ, "NAMESPACE": namespace, "RELEASE": release, "DEPLOY_MODE": deploy_mode}
            if deploy_mode == "k8s-native":
                env["SPARK_IMAGE"] = f"spark-custom:{img_tag}"
            if shared_infra:
                env["SHARED_INFRA_NS"] = shared_infra_ns
            failed = _capture_failure(
                _run(
                    os.path.join(project_root, "scripts", "tests", "load", "run-load-against-release.sh"),
                    env,
                    project_root,
                ),
                "load",
                result,
                failed,
            )
            print(f"  {sid}: load {result['load']}", flush=True)
            if result["load"] == "PASS":
                history_env = {**os.environ, "NAMESPACE": namespace, "RELEASE": release}
                if shared_infra:
                    history_env["SHARED_INFRA_NS"] = shared_infra_ns
                failed = _capture_failure(
                    _run(
                        os.path.join(project_root, "scripts", "tests", "load", "run-validate-history-after-load.sh"),
                        history_env,
                        project_root,
                    ),
                    "history",
                    result,
                    failed,
                )
                print(f"  {sid}: history {result['history']}", flush=True)
    finally:
        _cleanup(release, namespace)
    with open(os.path.join(results_dir, f"scenario-{sid}.json"), "w") as fh:
        json.dump(result, fh, indent=2)
    print(json.dumps(result))
    return failed
