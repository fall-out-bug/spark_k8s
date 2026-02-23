---
ws_id: 020-23
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-15", "020-20"]
---

## WS-020-23: Multi-Version Guide EN+RU

### 🎯 Goal

**What must WORK after completing this WS:**
- Guide: running Spark 3.5.7 and 4.1.0 together
- Architecture, isolation, migration path
- EN and RU versions

**Acceptance Criteria:**
- [x] AC1: docs/guides/MULTI-VERSION-DEPLOYMENT.md (EN)
- [x] AC2: docs/guides/MULTI-VERSION-DEPLOYMENT-RU.md (RU)
- [x] AC3: Architecture: separate Hive, History, namespaces or labels
- [x] AC4: Isolation (no cross-version conflicts)
- [x] AC5: Migration path (3.5 → 4.1)
- [x] AC6: Bilingual (EN/RU)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-15 (coexistence test), WS-020-20 (production guides).

### Input

- charts/spark-3.5/
- charts/spark-4.1/
- docs/drafts/idea-spark-410-charts.md

### Scope

~400 LOC. See docs/workstreams/INDEX.md Feature F04.
