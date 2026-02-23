---
ws_id: 020-24
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-020-24: ADRs + Values Overlays

### 🎯 Goal

**What must WORK after completing this WS:**
- ADRs document Spark 4.1 architecture decisions
- Values overlays for common scenarios (dev, prod, multi-arch)
- Reusable presets for spark-4.1 chart

**Acceptance Criteria:**
- [x] AC1: `docs/adr/` ADR for Spark 4.1 chart structure (or extend existing)
- [x] AC2: ADR for multi-version coexistence (3.5 + 4.1)
- [x] AC3: `charts/spark-4.1/presets/` or values overlays (dev, prod)
- [x] AC4: values-common.yaml or shared overlay referenced
- [x] AC5: README or docs link overlays to use cases

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/drafts/idea-spark-410-charts.md`
- `charts/spark-3.5/presets/` for reference

### Scope

~430 LOC. See `docs/workstreams/INDEX.md` Feature F04.
