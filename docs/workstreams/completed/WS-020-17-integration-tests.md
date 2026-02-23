---
ws_id: 020-17
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-09", "020-11", "020-12"]
---

## WS-020-17: Integration Tests

### 🎯 Goal

**What must WORK after completing this WS:**
- Integration tests for Spark Connect + Jupyter, + Celeborn, + Operator
- Combinations validated
- CI-runnable

**Acceptance Criteria:**
- [x] AC1: Test: Spark Connect 4.1 + Jupyter
- [x] AC2: Test: Spark Connect 4.1 + Celeborn (when enabled)
- [x] AC3: Test: Spark Operator 4.1 + K8s native executors
- [x] AC4: Test: Spark Operator 4.1 + Celeborn
- [x] AC5: Scripts or pytest in tests/integration/
- [x] AC6: Tests pass in CI or documented manual run

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-09 (Jupyter integration), WS-020-11 (Celeborn), WS-020-12 (Spark Operator).

### Input

- charts/spark-4.1/
- docs/drafts/idea-spark-410-charts.md (Integration Tests)

### Scope

~200 LOC. See docs/workstreams/INDEX.md Feature F04.
