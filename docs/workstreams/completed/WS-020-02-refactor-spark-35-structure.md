---
ws_id: 020-02
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-01"]
---

## WS-020-02: Refactor to spark-3.5 Structure

### 🎯 Goal

**What must WORK after completing this WS:**
- spark-3.5 chart uses spark-base as dependency
- Shared components (RBAC, MinIO, PostgreSQL) extracted to spark-base
- No duplication; helm template passes

**Acceptance Criteria:**
- [x] AC1: charts/spark-3.5/Chart.yaml depends on spark-base
- [x] AC2: spark-3.5 templates use spark-base helpers where applicable
- [x] AC3: Duplicate RBAC/minio/postgresql removed from spark-3.5
- [x] AC4: helm template test charts/spark-3.5 passes
- [x] AC5: Existing spark-3.5 scenarios (jupyter, airflow, k8s, standalone) unchanged functionally

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-01 (Create spark-base chart).

### Input

- charts/spark-base/
- charts/spark-3.5/

### Scope

~500 LOC. See docs/workstreams/INDEX.md Feature F04.
