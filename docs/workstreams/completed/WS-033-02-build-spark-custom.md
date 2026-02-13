---
ws_id: 033-02
feature: F24
status: completed
size: MEDIUM
project_id: 00
github_issue: spark_k8s-ds8.2
assignee: null
depends_on: ["033-01"]
---

## WS-033-02: Build Automation for spark-custom

### 🎯 Goal

**What must WORK after completing this WS:**
- GitHub Action builds `spark-custom:4.1.0` and pushes to GHCR
- Trigger: tag, push to main, or scheduled

**Acceptance Criteria:**
- [ ] AC1: Workflow triggers on tag (v*), push to main, workflow_dispatch
- [ ] AC2: Multi-stage build for size optimization
- [ ] AC3: Trivy security scan (fail on HIGH/CRITICAL optional)
- [ ] AC4: Push to ghcr.io/fall-out-bug/spark-k8s/spark-custom (or equivalent)
- [ ] AC5: Image tag matches Spark version (4.1.0)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-033-01 (GHCR setup).

### Input

- docker/spark-4.1/Dockerfile or docker/runtime/spark/
- .github/workflows/

### Scope

~150 LOC (YAML + Dockerfile tweaks). See docs/workstreams/INDEX.md Feature F24.
