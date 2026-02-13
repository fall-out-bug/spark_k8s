---
ws_id: 031-02
feature: F22
status: completed
size: SMALL
project_id: 00
github_issue: spark_k8s-703.2
assignee: null
depends_on: []
---

## WS-031-02: ROADMAP Auto-Update

### 🎯 Goal

**What must WORK after completing this WS:**
- `ROADMAP.md` (or equivalent) exists and is updated automatically when workstreams complete
- Roadmap reflects current feature/WS status from `docs/workstreams/INDEX.md`

**Acceptance Criteria:**
- [x] AC1: `ROADMAP.md` created at repo root (or docs/) with feature list and status
- [x] AC2: GitHub Action updates ROADMAP when `docs/workstreams/INDEX.md` or `docs/workstreams/completed/` changes
- [x] AC3: ROADMAP format: feature ID, name, completed/total WS, status
- [x] AC4: Action runs on push to default branch (or scheduled daily)
- [x] AC5: No manual edits required for status updates

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/workstreams/INDEX.md`
- `docs/workstreams/completed/`
- `docs/workstreams/backlog/`

### Scope

~120 LOC (YAML + script). See docs/workstreams/INDEX.md Feature F22.
