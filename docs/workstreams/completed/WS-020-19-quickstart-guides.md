---
ws_id: 020-19
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-06", "020-07", "020-08", "020-09", "020-10"]
---

## WS-020-19: Quickstart Guides EN+RU

### 🎯 Goal

**What must WORK after completing this WS:**
- Quickstart guide: deploy Spark 4.1.0 in 5 minutes
- EN and RU versions
- Links to scenario values, helm install commands

**Acceptance Criteria:**
- [x] AC1: docs/guides/SPARK-4.1-QUICKSTART.md (EN)
- [x] AC2: docs/guides/SPARK-4.1-QUICKSTART-RU.md (RU)
- [x] AC3: Step-by-step: helm install, verify Connect, run first job
- [x] AC4: Links to jupyter-connect-k8s-4.1.0.yaml and similar
- [x] AC5: Troubleshooting section
- [x] AC6: Bilingual (EN/RU)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-06 to WS-020-10 (core components).

### Input

- charts/spark-4.1/
- docs/guides/ structure
- docs/drafts/idea-spark-410-charts.md (Documentation)

### Scope

~300 LOC. See docs/workstreams/INDEX.md Feature F04.
