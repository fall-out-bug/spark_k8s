---
ws_id: 019-13
feature: F19
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["019-06"]
---

## WS-019-13: API Documentation (Helm Values)

### 🎯 Goal

**What must WORK after completing this WS:**
- API documentation for Helm charts is generated from chart source (values.yaml, Chart.yaml)
- All values.yaml options documented with type, default, and example where applicable
- Script to regenerate docs from charts exists; versioned docs per chart version referenced

**Acceptance Criteria:**
- [x] AC1: Script or tool generates values reference from spark-3.5 and/or spark-4.1 chart (e.g. helm schema export or parsed values)
- [x] AC2: docs/reference/values-reference.md (or per-chart file) includes parameters from current chart with description, type, default
- [x] AC3: Default values and constraints (e.g. memory format, allowed enums) documented
- [x] AC4: README or reference index links to chart-specific docs when multiple charts exist
- [x] AC5: Generation is repeatable (script in scripts/docs/ or similar)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-019-06 (Migration Guides) — completed.

### Input

- `charts/spark-3.5/values.yaml`
- `charts/spark-3.5/Chart.yaml`
- Existing `docs/reference/values-reference.md`

### Deliverables

- `scripts/docs/generate-values-reference.sh` (or equivalent)
- Updated `docs/reference/values-reference.md` or `docs/reference/spark-3.5-values.md` generated from chart
- Optional: versioned doc note in reference README
