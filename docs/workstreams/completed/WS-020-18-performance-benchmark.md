---
ws_id: 020-18
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-14", "020-15"]
---

## WS-020-18: Performance Benchmark

### 🎯 Goal

**What must WORK after completing this WS:**
- Benchmark script comparing Spark 3.5.7 vs 4.1.0
- TPC-DS subset or equivalent workload
- Metrics: execution time, shuffle, memory; with/without Celeborn

**Acceptance Criteria:**
- [x] AC1: scripts/benchmark-spark-versions.sh
- [x] AC2: Workload: TPC-DS subset or defined query set
- [x] AC3: Metrics: query execution time, shuffle read/write, memory
- [x] AC4: Compare 3.5.7 vs 4.1.0 (same workload)
- [x] AC5: Optional: 4.1.0 with vs without Celeborn
- [x] AC6: Results written to file or stdout

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-14 (smoke test), WS-020-15 (coexistence test).

### Input

- charts/spark-3.5/
- charts/spark-4.1/
- docs/drafts/idea-spark-410-charts.md

### Scope

~300 LOC. See docs/workstreams/INDEX.md Feature F04.
