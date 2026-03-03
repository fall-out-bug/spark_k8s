## WS-001-01: Chart Skeleton

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- Helm chart `spark-standalone` installable with `helm install`
- Basic structure: Chart.yaml, values.yaml, _helpers.tpl
- RBAC and ServiceAccount for Spark workloads
- Secrets template for S3 credentials
- Base ConfigMap for Spark configuration

**Acceptance Criteria:**
- [ ] `helm lint charts/spark-standalone` passes
- [ ] `helm template charts/spark-standalone` renders without errors
- [ ] ServiceAccount `spark-standalone` created
- [ ] RBAC roles allow pod creation (for workers)
- [ ] Secrets template references S3 credentials from values

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

This is the foundation workstream for the new `spark-standalone` Helm chart. It creates the basic chart structure that all subsequent workstreams will build upon. The chart will be separate from existing `spark-platform` (Spark Connect) chart.

### Dependency

Independent (first WS)

### Input Files

- `charts/spark-platform/Chart.yaml` — reference for chart metadata structure
- `charts/spark-platform/templates/_helpers.tpl` — reference for helper templates
- `charts/spark-platform/templates/rbac.yaml` — reference for RBAC patterns
- `charts/spark-platform/values.yaml` — reference for values structure

### Steps

1. Create `charts/spark-standalone/Chart.yaml` with metadata
2. Create `charts/spark-standalone/values.yaml` with all component configurations
3. Create `charts/spark-standalone/templates/_helpers.tpl` with helper functions
4. Create `charts/spark-standalone/templates/rbac.yaml` with ServiceAccount + Roles
5. Create `charts/spark-standalone/templates/secrets.yaml` for S3 credentials
6. Create `charts/spark-standalone/templates/configmap.yaml` for base Spark config
7. Run `helm lint` to validate

### Code

```yaml
# Chart.yaml
apiVersion: v2
name: spark-standalone
description: Apache Spark Standalone cluster with Airflow and MLflow
type: application
version: 0.1.0
appVersion: "3.5.7"
keywords:
  - spark
  - spark-standalone
  - airflow
  - mlflow
maintainers:
  - name: Data Platform Team
```

```yaml
# values.yaml (structure)
global:
  imageRegistry: ""
  imagePullSecrets: []

s3:
  endpoint: "http://minio:9000"
  accessKey: "minioadmin"
  secretKey: "minioadmin"
  pathStyleAccess: true

sparkMaster:
  enabled: true
  # ... (detailed in WS-001-02)

sparkWorker:
  enabled: true
  replicas: 2
  # ... (detailed in WS-001-03)

shuffleService:
  enabled: true
  # ... (detailed in WS-001-04)

hiveMetastore:
  enabled: true
  # ... (detailed in WS-001-05)

airflow:
  enabled: true
  # ... (detailed in WS-001-06)

mlflow:
  enabled: true
  # ... (detailed in WS-001-07)

ingress:
  enabled: true
  # ... (detailed in WS-001-08)

security:
  podSecurityStandards: true
  # ... (detailed in WS-001-09)

serviceAccount:
  create: true
  name: spark-standalone

rbac:
  create: true
```

### Expected Result

```
charts/spark-standalone/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── rbac.yaml
    ├── secrets.yaml
    └── configmap.yaml
```

### Scope Estimate

- Files: 6 created
- Lines: ~400 (SMALL)
- Tokens: ~1200

### Completion Criteria

```bash
# Lint chart
helm lint charts/spark-standalone

# Template renders
helm template test charts/spark-standalone --debug

# Check RBAC resources
helm template test charts/spark-standalone | grep -A5 "kind: ServiceAccount"
helm template test charts/spark-standalone | grep -A10 "kind: Role"
```

### Constraints

- DO NOT create component deployments (master, worker, etc.) — that's for subsequent WS
- DO NOT add security contexts yet — that's WS-001-09
- DO use existing `spark-platform` as reference but keep charts independent

---

### Execution Report

**Executed by:** GPT-5.2 (agent)
**Date:** 2026-01-15

#### Goal Status

- [x] AC1: `helm lint charts/spark-standalone` passes — ✅
- [x] AC2: `helm template charts/spark-standalone` renders without errors — ✅
- [x] AC3: ServiceAccount `spark-standalone` created — ✅
- [x] AC4: RBAC roles allow pod creation (for workers) — ✅ (Role includes `pods` create/get/list/watch/delete/patch)
- [x] AC5: Secrets template references S3 credentials from values — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-standalone/Chart.yaml` | created | ~16 |
| `charts/spark-standalone/values.yaml` | created | ~45 |
| `charts/spark-standalone/templates/_helpers.tpl` | created | ~80 |
| `charts/spark-standalone/templates/rbac.yaml` | created | ~70 |
| `charts/spark-standalone/templates/secrets.yaml` | created | ~12 |
| `charts/spark-standalone/templates/configmap.yaml` | created | ~55 |
| `docs/workstreams/backlog/WS-001-01-chart-skeleton.md` | modified | ~45 |

#### Completed Steps

- [x] Step 1: Create `charts/spark-standalone/Chart.yaml`
- [x] Step 2: Create `charts/spark-standalone/values.yaml`
- [x] Step 3: Create `charts/spark-standalone/templates/_helpers.tpl`
- [x] Step 4: Create `charts/spark-standalone/templates/rbac.yaml`
- [x] Step 5: Create `charts/spark-standalone/templates/secrets.yaml`
- [x] Step 6: Create `charts/spark-standalone/templates/configmap.yaml`
- [x] Step 7: Validate with Helm (`lint` + `template`)

#### Self-Check Results

```bash
$ helm lint charts/spark-standalone
==> Linting charts/spark-standalone
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed

$ helm template test charts/spark-standalone --debug > /tmp/spark-standalone-render.yaml
# Rendered successfully (no errors)
```

#### Issues

- Изначально hooks отсутствовали в репозитории; после добавления hooks потребовалось привести заголовок цели к ожидаемому формату `### 🎯 ...` для прохождения `pre-build.sh`.

---

### Review Result

**Reviewed by:** GPT-5.2 (agent)
**Date:** 2026-01-16

#### Metrics Summary

| Check | Status |
|-------|--------|
| Completion Criteria | ✅ |
| Tests & Coverage | ✅ (Helm lint/template; coverage N/A for Helm repo) |
| Regression | ✅ (validated via later feature smoke scripts) |
| AI-Readiness | ✅ |

**Verdict:** ✅ APPROVED
