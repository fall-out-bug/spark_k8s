# Review Complete: F28 — Chart Architecture DRY

**Verdict:** ❌ CHANGES REQUESTED

**Date:** 2026-02-13
**Reviewer:** review-agent (Claude)

---

## WS Status

| WS | Title | Goal | AI-Readiness | Git Commit | Verdict |
|----|-------|------|-------------|------------|---------|
| WS-028-01 | Unify Values + Extract to spark-base | ✅ 9/9 AC | 🔴 249+228 LOC | ✅ fe47b9a | ❌ CHANGES REQUESTED |
| WS-028-02 | Consolidate RBAC + Remove Legacy | ✅ 9/9 AC | ✅ max 30 LOC | ✅ 76dec34 | ✅ APPROVED |
| WS-028-03 | values.schema.json + Helm Tests | ✅ 7/7 AC | ✅ max 30 LOC | 🔴 Not committed | ❌ CHANGES REQUESTED |

---

## Blockers

### 1. WS-028-01: File size violations (spark_k8s-8td, spark_k8s-vj6)

**Problem:** Two files in `charts/spark-base/templates/core/` exceed 200 LOC:
- `postgresql-deployment.yaml` — 249 LOC (Secret + ConfigMap + StatefulSet + Job)
- `hive-metastore-deployment.yaml` — 228 LOC (Secret + Job + Deployment)

**How to fix:** Split each into separate files per K8s resource:
- `postgresql-secret.yaml`, `postgresql-configmap.yaml`, `postgresql-statefulset.yaml`, `postgresql-init-job.yaml`
- `hive-metastore-secret.yaml`, `hive-metastore-init-job.yaml`, `hive-metastore-deployment.yaml`

### 2. WS-028-03: Deliverables not committed (spark_k8s-nxq)

**Problem:** All WS-028-03 files are untracked:
- `charts/spark-4.1/values.schema.json`
- `charts/spark-3.5/values.schema.json`
- `charts/spark-4.1/templates/tests/test-connect-grpc.yaml`
- `charts/spark-3.5/templates/tests/test-connect-grpc.yaml`
- `docs/workstreams/completed/WS-028-03.md`

**How to fix:** `git add` and commit with conventional commit format.

---

## Non-Blocking Issues (Filed as Beads)

| # | Severity | Issue | Bead |
|---|----------|-------|------|
| 1 | MEDIUM | ClusterRole/Role have identical permission rules | spark_k8s-0l1 |
| 2 | MEDIUM | values.schema.json covers <10% of values surface | spark_k8s-7jk |
| 3 | MEDIUM | Schema inconsistency between 3.5 and 4.1 | spark_k8s-7jk |

---

## What Went Well

1. **ADR-028** — Clear decision record documenting the unified values approach
2. **YAML anchor pattern** (`core: &core` → `spark-base.core: *core`) — elegant values propagation
3. **RBAC consolidation** — Clean merge from 82 LOC rbac.yaml + 35 LOC role.yaml into organized directory
4. **KEDA rename** — Clarifies distinct autoscaling purposes (operator vs connect)
5. **Net deletion** — WS-028-01: -419/+363 LOC, WS-028-02: -473/+143 LOC = significant duplication reduction
6. **Schema validation works** — Catches wrong types and missing required fields
7. **Helm test template** — Proper hook annotations, PSS-aware security context

---

## Pre-existing Issues (Not F28)

| Issue | Origin | Status |
|-------|--------|--------|
| PSS baseline test fails (no security context rendered) | F14 (spark-base PSS disabled by default) | Known |
| `test_scenarios_exist.py` matrix test fails | Untracked file from another agent | Not committed |

---

## Helm Validation Results

| Check | spark-4.1 | spark-3.5 |
|-------|-----------|-----------|
| `helm lint` | ✅ | ✅ |
| `helm template` (default) | ✅ | ✅ |
| `helm template` (core-baseline preset) | ✅ | N/A |
| Schema: rejects wrong type | ✅ `replicas=abc` fails | ✅ `replicas=abc` fails |
| Schema: rejects empty repository | ✅ `minLength` enforcement | ⚠️ No `minLength` constraint |

---

## Next Steps

**CHANGES REQUESTED — fix before re-review:**

1. Split `postgresql-deployment.yaml` into 4 files (spark_k8s-8td)
2. Split `hive-metastore-deployment.yaml` into 3 files (spark_k8s-vj6)
3. Commit WS-028-03 deliverables to git (spark_k8s-nxq)
4. Re-run `/review F28`

**After APPROVED:**
1. Generate UAT guide
2. `/deploy F28`
