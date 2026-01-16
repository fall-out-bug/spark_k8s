# Validation Runbook

**Tested on:** Minikube  
**Prepared for:** OpenShift-like constraints (PSS `restricted` / SCC `restricted`)

## Overview

This guide documents the smoke test scripts provided in the repository and what "green" means for each test.

## Smoke Test Scripts

### `scripts/test-spark-standalone.sh`

**Purpose:** End-to-end validation of Spark Standalone cluster (master + workers).

**Usage:**
```bash
./scripts/test-spark-standalone.sh <namespace> <release-name>

# Example:
./scripts/test-spark-standalone.sh spark-sa spark-standalone
```

**What It Tests:**
1. Pods are ready (master + workers)
2. Spark Master UI responds (HTTP 200 on port 8080)
3. At least 1 worker registered with master
4. SparkPi job completes successfully (via `spark-submit`)
5. Optional services exist (Airflow, MLflow) if enabled

**Expected Output:**
```
=== Testing Spark Standalone Chart (spark-standalone in spark-sa) ===
1) Checking pods are ready...
   Master pod: spark-standalone-master-xxx
2) Checking Spark Master UI responds...
   OK
3) Checking at least 1 worker registered (best-effort)...
   OK (workers field present)
4) Running SparkPi via spark-submit (best-effort)...
   OK
5) Checking Airflow and MLflow services exist (if enabled)...
   OK
=== Done ===
```

**Exit Code:** `0` on success, non-zero on failure.

### `scripts/test-prodlike-airflow.sh`

**Purpose:** Trigger and wait for Airflow DAG runs in a "prod-like" environment.

**Usage:**
```bash
./scripts/test-prodlike-airflow.sh <namespace> <release-name> [dag1] [dag2] ...

# Example:
./scripts/test-prodlike-airflow.sh spark-sa-prodlike spark-prodlike \
  example_bash_operator spark_etl_synthetic
```

**Environment Variables:**
- `TIMEOUT_SECONDS` — Max wait time per DAG (default: `900`)
- `POLL_SECONDS` — Poll interval (default: `10`)

**What It Tests:**
1. Airflow scheduler deployment is ready
2. Airflow CLI is reachable
3. DAGs are triggered and reach `success` state

**Expected Output:**
```
=== Airflow prod-like DAG tests (spark-prodlike in spark-sa-prodlike) ===
1) Waiting for scheduler deployment...
   Scheduler pod: spark-prodlike-spark-standalone-airflow-scheduler-xxx
2) Sanity: airflow CLI reachable...
   OK
3) Triggering DAG: example_bash_operator (run_id=prodlike-20260116-120000-example_bash_operator)
4) Waiting for DAG completion (timeout=900s, poll=10s)...
   example_bash_operator prodlike-20260116-120000-example_bash_operator: success
...
=== Done ===
```

**Exit Code:** `0` if all DAGs reach `success`, `1` if any DAG fails, `2` on timeout.

### `scripts/test-sa-prodlike-all.sh`

**Purpose:** Combined smoke test (Spark E2E + Airflow DAGs).

**Usage:**
```bash
./scripts/test-sa-prodlike-all.sh <namespace> <release-name>

# Example:
./scripts/test-sa-prodlike-all.sh spark-sa-prodlike spark-prodlike
```

**What It Tests:**
1. Runs `test-spark-standalone.sh` (Spark cluster health + SparkPi)
2. Runs `test-prodlike-airflow.sh` (Airflow DAGs: `example_bash_operator`, `spark_etl_synthetic`)

**Expected Output:**
```
=== SA prod-like ALL tests (spark-prodlike in spark-sa-prodlike) ===

1) Spark Standalone E2E...
[... output from test-spark-standalone.sh ...]

2) Airflow prod-like DAG tests...
[... output from test-prodlike-airflow.sh ...]

=== ALL OK ===
```

**Exit Code:** `0` if all tests pass, non-zero if any test fails.

## Known Failure Modes

### SparkPi Job Fails

**Symptoms:**
- `test-spark-standalone.sh` step 4 fails
- Error: `Connection refused: localhost:7077` or `No route to host`

**Troubleshooting:**
```bash
# Check master service
kubectl get svc -n <namespace> <release>-spark-standalone-master

# Check master pod logs
kubectl logs -n <namespace> deploy/<release>-spark-standalone-master | tail -50

# Verify worker registration
kubectl exec -n <namespace> <master-pod> -- \
  curl -fsS http://localhost:8080/json/ | jq '.workers'
```

**Common Fixes:**
- Ensure `sparkMaster.service.ports.spark: 7077` in values
- Verify workers can reach master service DNS name
- Check network policies (if enabled)

### Airflow DAG Stuck in "running" or "queued"

**Symptoms:**
- `test-prodlike-airflow.sh` times out
- DAG never reaches `success` or `failed`

**Troubleshooting:**
```bash
# Check scheduler logs
kubectl logs -n <namespace> deploy/<release>-spark-standalone-airflow-scheduler | tail -100

# Check worker pods (if KubernetesExecutor)
kubectl get pods -n <namespace> -l app=airflow-worker

# Check DAG task logs via Airflow UI
kubectl port-forward svc/<release>-spark-standalone-airflow-webserver 8080:8080 -n <namespace>
# Open http://localhost:8080 and check task logs
```

**Common Fixes:**
- Verify `airflow.fernetKey` is set (shared across pods)
- Check KubernetesExecutor worker image matches Airflow image
- Verify RBAC permissions for worker pods
- Check resource limits (worker pods may be OOMKilled)

### Workers Not Registering

**Symptoms:**
- `test-spark-standalone.sh` step 3 shows "WARN: /json/ did not include workers field"
- Master UI shows 0 workers

**Troubleshooting:**
```bash
# Check worker pods
kubectl get pods -n <namespace> -l app=spark-worker

# Check worker logs
kubectl logs -n <namespace> deploy/<release>-spark-standalone-worker | tail -50

# Verify master service DNS
kubectl exec -n <namespace> <worker-pod> -- nslookup <release>-spark-standalone-master
```

**Common Fixes:**
- Ensure `sparkMaster.enabled: true`
- Verify worker can resolve master service name
- Check network policies (if enabled)

## Quick Validation Checklist

Before considering a deployment "green":

- [ ] `helm lint charts/spark-standalone` passes
- [ ] All pods are `Running` (no `CrashLoopBackOff`, `Pending`)
- [ ] `test-spark-standalone.sh` passes
- [ ] If Airflow enabled: `test-prodlike-airflow.sh` passes
- [ ] No unexpected restarts (check `kubectl get pods -w`)

## Reference

- **Chart guides:** [`docs/guides/en/charts/`](charts/)
- **OpenShift notes:** [`docs/guides/en/openshift-notes.md`](openshift-notes.md)
- **Repository map:** [`docs/PROJECT_MAP.md`](../../PROJECT_MAP.md)
