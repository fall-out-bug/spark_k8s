---
ws_id: 033-03
feature: F24
status: completed
size: MEDIUM
project_id: 00
github_issue: spark_k8s-ds8.3
assignee: null
depends_on: ["033-01"]
---

## WS-033-03: Build Automation for jupyter-spark

### 🎯 Goal

**What must WORK after completing this WS:**
- GitHub Action builds `jupyter-spark:4.1.0` and pushes to GHCR
- Image includes Spark Connect client, Python deps, sample notebooks

**Acceptance Criteria:**
- [ ] AC1: Workflow triggers on tag, push to main, workflow_dispatch
- [ ] AC2: Image includes Spark Connect client, Python deps
- [ ] AC3: Sample notebooks included (or documented mount)
- [ ] AC4: Trivy security scan
- [ ] AC5: Push to ghcr.io/fall-out-bug/spark-k8s/jupyter-spark

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-033-01 (GHCR setup).

### Input

- docker/jupyter-4.1/ or docker/runtime/jupyter/
- .github/workflows/

### Scope

~150 LOC (YAML + Dockerfile). See docs/workstreams/INDEX.md Feature F24.
