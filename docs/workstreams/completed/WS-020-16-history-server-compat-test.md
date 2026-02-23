---
ws_id: 020-16
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-08", "020-15"]
---

## WS-020-16: History Server Compat Test

### 🎯 Goal

**What must WORK after completing this WS:**
- History Server 4.1.0 reads event logs from 3.5.7 and 4.1.0 jobs
- Compatibility status documented
- Test script validates

**Acceptance Criteria:**
- [x] AC1: scripts/test-history-server-compat.sh
- [x] AC2: Run Spark 3.5.7 job → write event logs to S3
- [x] AC3: Run Spark 4.1.0 job → write event logs to S3
- [x] AC4: Query 4.1.0 History Server for both log sets
- [x] AC5: Document compatibility status in docs/guides/
- [x] AC6: If incompatible, document workaround or limitation

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-08 (History Server 4.1), WS-020-15 (coexistence test).

### Input

- charts/spark-4.1/
- docs/drafts/idea-spark-410-charts.md

### Scope

~180 LOC. See docs/workstreams/INDEX.md Feature F04.
