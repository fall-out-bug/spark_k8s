---
ws_id: 020-14
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-06", "020-07", "020-08", "020-09", "020-10"]
---

## WS-020-14: Smoke Test Script

### 🎯 Goal

**What must WORK after completing this WS:**
- Smoke test script for Spark 4.1.0 deployment
- SparkPi, Hive table, Jupyter notebook, History Server API
- CI-runnable

**Acceptance Criteria:**
- [x] AC1: scripts/test-spark-4.1-smoke.sh (or tests/smoke/scenarios/*)
- [x] AC2: SparkPi job submission (spark-submit or Connect client)
- [x] AC3: Hive table create/query
- [x] AC4: Jupyter notebook execution (optional or via API)
- [x] AC5: History Server API query for event logs
- [x] AC6: Script exits 0 on success, non-zero on failure

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-06, 07, 08, 09, 10 (core Spark 4.1 components).

### Input

- charts/spark-4.1/
- tests/smoke/ structure
- docs/drafts/idea-spark-410-charts.md (Testing Strategy)

### Scope

~200 LOC. See docs/workstreams/INDEX.md Feature F04.
