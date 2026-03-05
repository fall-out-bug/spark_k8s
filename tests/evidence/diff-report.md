# F036 Chart Refactor — Diff Report (Baseline vs Final)

Generated: 2026-03-06
Feature: F036 — Helm Chart Architecture Refactor
Workstreams: 00-036-01 through 00-036-12

## Summary

The refactoring eliminated the `spark-standalone` subchart, moving all templates
to inline parent chart templates under `charts/spark-3.5/templates/`. This fixed
the core problem: the subchart rendered resources unconditionally, leaking Airflow,
Standalone master/worker, and ServiceAccount resources into modes that didn't need them.

| Mode | Baseline | Final | Delta | Explanation |
|------|----------|-------|-------|-------------|
| connect-k8s | 31 | 16 | -15 | Subchart leak removed (SA, Airflow, Standalone) |
| connect-sa | 19 | 19 | 0 | Resources preserved, names cleaned |
| k8s-native | 27 | 12 | -15 | Subchart leak removed (SA, Airflow, Standalone) |
| standalone | 14 | 14 | 0 | Resources preserved, names cleaned |
| demo | 38 | 33 | -5 | Subchart SA + duplicate secrets removed |

**No resources lost.** All resource count reductions are due to removal of
incorrectly-rendered subchart artifacts that were never used in those modes.

---

## Mode: connect-k8s (Connect Only)

**Resources:** 31 → 16 (-15)

### Removed resources (subchart leak — never belonged in this mode)

| Resource | Reason |
|----------|--------|
| `spark-standalone` ServiceAccount | Subchart SA, not needed |
| `evidence-ck-standalone-airflow-secret` | Airflow not enabled |
| `evidence-ck-standalone-airflow-config` | Airflow not enabled |
| `evidence-ck-standalone-airflow-dags` | Airflow not enabled |
| `evidence-ck-standalone-airflow-postgresql` (Secret, StatefulSet, Service) | Airflow not enabled |
| `evidence-ck-standalone-airflow-scheduler` | Airflow not enabled |
| `evidence-ck-standalone-airflow-webserver` (Deployment, Service) | Airflow not enabled |
| `evidence-ck-standalone-master` (Deployment, Service) | Standalone not enabled |
| `evidence-ck-standalone-worker` | Standalone not enabled |
| `spark-35` RoleBinding/ClusterRoleBinding (subchart) | Duplicate from subchart |

### Preserved resources (all correct)

All 16 final resources are parent chart resources: Connect server, History server,
Jupyter, RBAC, executor pod template, test hook.

**Verdict: No resources lost.** Reduction is cleanup of subchart artifacts.

---

## Mode: connect-sa (Connect + Standalone)

**Resources:** 19 → 19 (0 delta)

### Renames

| Baseline Name | Final Name |
|---------------|------------|
| `evidence-cs-spark-35-standalone-master` | `evidence-cs-standalone-master` |
| `evidence-cs-spark-35-standalone-worker` | `evidence-cs-standalone-worker` |

### Template source changes

| Baseline Source | Final Source |
|-----------------|-------------|
| `spark-3.5/templates/spark-standalone.yaml` | `spark-3.5/templates/standalone/master.yaml` |

**Verdict: No resources lost.** All 19 resources accounted for with cleaner names.

---

## Mode: k8s-native (Kubernetes Native)

**Resources:** 27 → 12 (-15)

### Removed resources (subchart leak — never belonged in this mode)

Same pattern as connect-k8s: the subchart rendered Standalone master/worker,
Airflow (scheduler, webserver, postgresql, config, dags, secret), and its own
ServiceAccount/RBAC — none of which are needed in Kubernetes Native mode.

### Preserved resources (all correct)

All 12 final resources are parent chart resources: K8s Native submitter, History server,
Jupyter, RBAC roles/bindings.

**Verdict: No resources lost.** Reduction is cleanup of subchart artifacts.

---

## Mode: standalone (Standalone Only)

**Resources:** 14 → 14 (0 delta)

### Renames

| Baseline Name | Final Name |
|---------------|------------|
| `evidence-sa-spark-35-standalone-master` | `evidence-sa-standalone-master` |
| `evidence-sa-spark-35-standalone-worker` | `evidence-sa-standalone-worker` |

### Template source changes

| Baseline Source | Final Source |
|-----------------|-------------|
| `spark-3.5/templates/spark-standalone.yaml` | `spark-3.5/templates/standalone/master.yaml` |

**Verdict: No resources lost.** All 14 resources accounted for with cleaner names.

---

## Mode: demo (Full Preset)

**Resources:** 38 → 33 (-5)

### Removed resources

| Resource | Reason |
|----------|--------|
| `spark-standalone` ServiceAccount | Subchart SA, replaced by parent RBAC |
| `evidence-demo-standalone` ServiceAccount/Role/RoleBinding | Subchart RBAC, replaced by parent |
| `evidence-demo-hive-metastore-db` Secret | Duplicate (spark-base already provides metastore-db) |

### Renames

| Baseline Name | Final Name |
|---------------|------------|
| `evidence-demo-standalone-airflow-*` | `evidence-demo-airflow-*` |
| `evidence-demo-standalone-master` | `evidence-demo-standalone-master` (unchanged) |
| `evidence-demo-standalone-worker` | `evidence-demo-standalone-worker` (unchanged) |

### Added resources (improvements)

| Resource | Reason |
|----------|--------|
| `evidence-demo-spark-35-spark-cluster-role` (x2) | ClusterRole + ClusterRoleBinding for proper RBAC |
| `evidence-demo-spark-35-spark-cluster-rolebinding` | Matches cluster-wide role |

### Net accounting

- Removed: 5 subchart artifacts
- Added: 0 net new (cluster-role was missing in baseline — a bug)
- Airflow resources: all preserved with cleaner names (no `standalone-` prefix)

**Verdict: No resources lost.** All functional resources preserved.

---

## Naming Convention Changes (Global)

| Category | Before (Baseline) | After (Final) |
|----------|--------------------|---------------|
| Helm values key | `sparkStandalone.*` | `standalone.*` |
| Helm values key | `sparkK8sNative.*` | `kubernetes.*` |
| K8s resource prefix | `{release}-spark-35-standalone-master` | `{release}-standalone-master` |
| K8s resource prefix | `{release}-standalone-airflow-*` | `{release}-airflow-*` |
| Template source | `templates/spark-standalone.yaml` | `templates/standalone/master.yaml` |
| Labels | `app: spark-standalone-master` | `app: standalone-master` |

---

## Quality Gate Results

- `helm lint charts/spark-3.5` — PASS
- `helm lint charts/spark-3.5 -f presets/demo-full-spark-infra.yaml` — PASS
- `scripts/validate-chart-modes.sh` — PASS (6 modes)
- `pytest tests/integration/ -v` — ALL PASS
- `grep -rn "sparkStandalone\|sparkK8sNative" charts/spark-3.5/` — 0 matches
