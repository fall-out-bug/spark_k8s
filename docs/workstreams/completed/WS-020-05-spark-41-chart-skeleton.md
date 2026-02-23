---
ws_id: 020-05
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-01"]
---

## WS-020-05: spark-4.1 Chart Skeleton

### 🎯 Goal

**What must WORK after completing this WS:**
- charts/spark-4.1/ exists with Chart.yaml, values.yaml, templates/
- Depends on spark-base
- Basic structure for Connect, Hive, History, Jupyter

**Acceptance Criteria:**
- [x] AC1: charts/spark-4.1/Chart.yaml (appVersion 4.1.0)
- [x] AC2: charts/spark-4.1/values.yaml with connect, hiveMetastore, historyServer, jupyter sections
- [x] AC3: charts/spark-4.1 depends on spark-base
- [x] AC4: templates/_helpers.tpl with spark-4.1 fullname
- [x] AC5: helm template test charts/spark-4.1 passes (minimal output OK)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-01 (Create spark-base chart).

### Input

- charts/spark-base/
- charts/spark-3.5/ (structure reference)

### Scope

~595 LOC. See docs/workstreams/INDEX.md Feature F04.
