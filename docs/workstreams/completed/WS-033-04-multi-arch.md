---
ws_id: 033-04
feature: F24
status: completed
size: MEDIUM
project_id: 00
github_issue: spark_k8s-ds8.4
assignee: null
depends_on: ["033-02", "033-03"]
---

## WS-033-04: Multi-arch Support

### 🎯 Goal

**What must WORK after completing this WS:**
- Images built for amd64 and arm64
- Architecture detection for quick-start

**Acceptance Criteria:**
- [ ] AC1: docker buildx or matrix for amd64, arm64
- [ ] AC2: Both spark-custom and jupyter-spark multi-arch
- [ ] AC3: Manifest list (multi-arch) pushed to GHCR
- [ ] AC4: Document architecture-specific considerations
- [ ] AC5: quick-start.sh (if exists) detects arch for correct image pull

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-033-02, WS-033-03 (both image builds).

### Input

- .github/workflows/ (build workflows)
- scripts/quick-start.sh (if exists)

### Scope

~120 LOC. See docs/workstreams/INDEX.md Feature F24. Priority: P2.
