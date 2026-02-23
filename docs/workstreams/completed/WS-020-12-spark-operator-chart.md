---
ws_id: 020-12
feature: F04
status: backlog
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-020-12: Spark Operator Chart

### 🎯 Goal

**What must WORK after completing this WS:**
- Kubernetes Spark Operator (v1beta2 API) Helm chart
- CRD SparkApplication, webhook, RBAC
- Supports Spark 4.1.0 declarative jobs

**Acceptance Criteria:**
- [x] AC1: `charts/spark-operator/` or equivalent exists
- [x] AC2: SparkApplication CRD (v1beta2)
- [x] AC3: Operator deployment with Spark 4.1.0 support
- [x] AC4: Webhook for validation (optional)
- [x] AC5: RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
- [x] AC6: Example SparkApplication manifest in values or docs
- [x] AC7: `helm template` passes

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/drafts/idea-spark-410-charts.md` (Spark Operator section)
- Existing operator usage in repo (e.g. WS-008-03)

### Scope

~860 LOC. See `docs/workstreams/INDEX.md` Feature F04.
