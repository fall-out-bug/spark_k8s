## WS-001-11: Prod-like Airflow tests (KubernetesExecutor + Spark Standalone)

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- A “prod-like” Helm values profile that enables Spark Standalone HA (PVC) and runs Airflow reliably under PSS hardening.
- Airflow DAG `spark_etl_synthetic` completes successfully against the Spark Standalone cluster and writes output to MinIO (S3A).

**Acceptance Criteria:**
- [ ] `charts/spark-standalone/values-prod-like.yaml` exists and documents intended use
- [ ] Airflow runs with `KubernetesExecutor` without read-only filesystem failures
- [ ] DAGs are discoverable without “recursive loop” errors
- [ ] Airflow Variables decrypt consistently across scheduler/webserver/worker pods (shared Fernet key)
- [ ] `spark_etl_synthetic` run reaches `success` in “prod-like” namespace
- [ ] Spark job runs with executor sizing compatible with a small local cluster (no WAITING due to 4Gi defaults)

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

This workstream focuses on validating and hardening Airflow execution in a “prod-like” setup:
PSS-enabled pods, KubernetesExecutor task pods, and Spark Standalone driver connectivity to workers.

### Dependency

WS-001-10 (Example DAGs & Tests)

### Input Files

- `charts/spark-standalone/templates/airflow/configmap.yaml`
- `charts/spark-standalone/templates/airflow/*`
- `charts/spark-standalone/values-prod-like.yaml`

### Steps

1. Add shared Fernet key support (Secret + env wiring) so Variables decrypt correctly across pods
2. Ensure KubernetesExecutor worker pods use Airflow image and a shared pod template
3. Ensure DAGs are copied into a real directory (avoid ConfigMap symlink recursion)
4. Update Spark submit command in DAG to pass S3A + driver host + executor sizing overrides
5. Deploy prod-like release and run:
   - `example_bash_operator`
   - `spark_etl_synthetic`

### Completion Criteria (manual)

```bash
kubectl create ns spark-sa-prodlike || true
helm upgrade --install spark-prodlike charts/spark-standalone \
  -n spark-sa-prodlike \
  -f charts/spark-standalone/values-prod-like.yaml \
  --set ingress.enabled=false

# Trigger ETL DAG (from scheduler or webserver)
kubectl exec -n spark-sa-prodlike deploy/spark-prodlike-spark-standalone-airflow-scheduler -- \
  airflow dags trigger spark_etl_synthetic

kubectl exec -n spark-sa-prodlike deploy/spark-prodlike-spark-standalone-airflow-scheduler -- \
  airflow dags list-runs -d spark_etl_synthetic
```

---

### Execution Report

**Executed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### 🎯 Goal Status

- [x] `charts/spark-standalone/values-prod-like.yaml` exists and documents intended use — ✅
- [x] Airflow runs with `KubernetesExecutor` without read-only filesystem failures — ✅
- [x] DAGs are discoverable without “recursive loop” errors — ✅
- [x] Airflow Variables decrypt consistently across scheduler/webserver/worker pods (shared Fernet key) — ✅
- [x] `spark_etl_synthetic` run reaches `success` in “prod-like” namespace — ✅
- [x] Spark job runs with executor sizing compatible with a small local cluster — ✅

**Goal Achieved:** ✅ YES

#### Verification (runtime)

```bash
helm upgrade --install spark-prodlike charts/spark-standalone \
  -n spark-sa-prodlike \
  -f charts/spark-standalone/values-prod-like.yaml \
  --set ingress.enabled=false

./scripts/test-sa-prodlike-all.sh spark-sa-prodlike spark-prodlike
```

---

### Review Result

**Reviewed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### Metrics Summary

| Check | Status |
|-------|--------|
| Completion Criteria | ✅ |
| Tests & Coverage | ✅ (Helm lint + runtime smoke scripts; coverage N/A for Helm repo) |
| Regression | ✅ (`scripts/test-sa-prodlike-all.sh`) |
| AI-Readiness | ✅ |
| Security (PSS) | ✅ |

**Verdict:** ✅ APPROVED

