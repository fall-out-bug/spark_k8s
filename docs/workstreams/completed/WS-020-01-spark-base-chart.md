---
ws_id: 020-01
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-020-01: Create spark-base Chart

### 🎯 Goal

**What must WORK after completing this WS:**
- Shared `spark-base` Helm chart exists with RBAC, MinIO, PostgreSQL, config templates
- spark-3.5 and spark-4.1 can use it as dependency
- `helm template` passes for spark-base

**Acceptance Criteria:**
- [x] AC1: `charts/spark-base/Chart.yaml` exists with name spark-base
- [x] AC2: `charts/spark-base/values.yaml` with global.postgresql, global.s3, secrets
- [x] AC3: `charts/spark-base/templates/rbac.yaml` (ServiceAccount, Role, RoleBinding)
- [x] AC4: `charts/spark-base/templates/minio.yaml` (optional, conditional)
- [x] AC5: `charts/spark-base/templates/postgresql.yaml` (optional, conditional)
- [x] AC6: `charts/spark-base/templates/_helpers.tpl` shared template functions
- [x] AC7: `helm template test charts/spark-base` passes

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/drafts/idea-spark-410-charts.md`
- Existing `charts/spark-3.5/` structure for reference

### Scope

~545 LOC. See `docs/workstreams/INDEX.md` Feature F04.
