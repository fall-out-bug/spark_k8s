---
ws_id: 031-04
feature: F22
status: completed
size: SMALL
project_id: 00
github_issue: spark_k8s-703.4
assignee: null
depends_on: ["031-01", "031-02"]
---

## WS-031-04: Metrics Dashboard

### 🎯 Goal

**What must WORK after completing this WS:**
- Simple visibility into workstream completion rate and feature progress
- Dashboard can be GitHub Pages, static HTML, or link to external (e.g. Grafana)

**Acceptance Criteria:**
- [x] AC1: Metrics source: parse `docs/workstreams/INDEX.md` + `completed/` for counts
- [x] AC2: At least one of: (a) GitHub Pages page with completion stats, (b) JSON artifact for external dashboards, (c) Badge/shield for README
- [x] AC3: Metrics include: total WS, completed WS, per-feature completion %
- [x] AC4: Update on push to default branch or weekly
- [x] AC5: No external services required for basic (a) or (b)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-031-01, WS-031-02 (reuse parsing; ROADMAP as source).

### Input

- `docs/workstreams/INDEX.md`
- `docs/workstreams/completed/`
- `ROADMAP.md`

### Scope

~100 LOC. See docs/workstreams/INDEX.md Feature F22. Priority: P3.
