---
ws_id: 020-10
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-01"]
---

## WS-020-10: RBAC + Service Templates

### 🎯 Goal

**What must WORK after completing this WS:**
- RBAC (ServiceAccount, Role, RoleBinding) for spark-4.1
- Shared with spark-base or chart-specific
- Service templates for Connect, Hive, History, Jupyter

**Acceptance Criteria:**
- [x] AC1: ServiceAccount for Spark 4.1 components
- [x] AC2: Role with required permissions (pods, configmaps, secrets, events)
- [x] AC3: RoleBinding linking ServiceAccount to Role
- [x] AC4: Services for Connect, Hive Metastore, History Server, Jupyter
- [x] AC5: helm template passes; pods can use ServiceAccount

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-01 (Create spark-base chart).

### Input

- charts/spark-base/
- charts/spark-3.5/templates/rbac.yaml

### Scope

~100 LOC. See docs/workstreams/INDEX.md Feature F04.
