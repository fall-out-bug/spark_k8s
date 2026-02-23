---
ws_id: 020-21
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-11", "020-13"]
---

## WS-020-21: Celeborn Guide EN

### 🎯 Goal

**What must WORK after completing this WS:**
- Guide: when and how to use Apache Celeborn
- Use cases, sizing, troubleshooting
- English

**Acceptance Criteria:**
- [x] AC1: docs/guides/CELEBORN-GUIDE.md
- [x] AC2: When to use (large shuffle, spot instances, dynamic allocation)
- [x] AC3: When to skip (dev, small datasets, Standalone)
- [x] AC4: Sizing (masters, workers, storage)
- [x] AC5: Enable in values, verify integration
- [x] AC6: Troubleshooting section

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-11 (Celeborn chart), WS-020-13 (integration configs).

### Input

- charts/celeborn/ or celeborn templates
- docs/drafts/idea-spark-410-charts.md (Apache Celeborn)

### Scope

~250 LOC. See docs/workstreams/INDEX.md Feature F04.
