---
ws_id: 020-15
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-02", "020-14"]
---

## WS-020-15: Coexistence Test

### 🎯 Goal

**What must WORK after completing this WS:**
- Both Spark 3.5.7 and 4.1.0 deployed in same cluster
- Isolated Hive Metastores, separate History Servers
- No cross-version conflicts

**Acceptance Criteria:**
- [x] AC1: scripts/test-coexistence.sh
- [x] AC2: Deploy spark-3.5 and spark-4.1 in same namespace (or separate)
- [x] AC3: Verify separate Hive Metastore instances (different DBs)
- [x] AC4: Verify separate History Servers (different S3 prefixes)
- [x] AC5: Submit job to 3.5, submit job to 4.1 — both succeed
- [x] AC6: Document coexistence in docs/guides/

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-02 (refactor spark-3.5), WS-020-14 (smoke test).

### Input

- charts/spark-3.5/
- charts/spark-4.1/
- docs/drafts/idea-spark-410-charts.md

### Scope

~180 LOC. See docs/workstreams/INDEX.md Feature F04.
