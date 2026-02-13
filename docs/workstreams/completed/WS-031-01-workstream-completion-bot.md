---
ws_id: 031-01
feature: F22
status: completed
size: SMALL
project_id: 00
github_issue: spark_k8s-703.1
assignee: null
depends_on: []
---

## WS-031-01: Workstream Completion Bot

### 🎯 Goal

**What must WORK after completing this WS:**
- When a PR merges that moves workstream(s) to `docs/workstreams/completed/`, a GitHub Action posts a comment with a summary of completed WS
- Operators and contributors see progress without manual checks

**Acceptance Criteria:**
- [x] AC1: GitHub Action triggers on push to default branch when `docs/workstreams/completed/*.md` changes
- [x] AC2: Action parses completed WS files (frontmatter: ws_id, feature, title)
- [x] AC3: Comment posted to triggering PR (or commit) with: WS IDs, feature, brief summary
- [x] AC4: Action uses `GITHUB_TOKEN` (no external secrets for basic flow)
- [x] AC5: Action runs within timeout-minutes, fails gracefully on parse errors

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/workstreams/completed/` (WS markdown files)
- `.github/workflows/` (existing structure)

### Scope

~150 LOC (YAML + optional script). See docs/workstreams/INDEX.md Feature F22.
