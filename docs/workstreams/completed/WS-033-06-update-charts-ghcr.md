---
ws_id: 033-06
feature: F24
status: completed
size: MEDIUM
project_id: 00
github_issue: spark_k8s-ds8.6
assignee: null
depends_on: ["033-04", "033-05"]
---

## WS-033-06: Update Charts for GHCR Images

### 🎯 Goal

**What must WORK after completing this WS:**
- All Helm chart values.yaml use ghcr.io images by default
- Override path documented for custom builds

**Acceptance Criteria:**
- [ ] AC1: charts/spark-4.1/ values default to ghcr.io images
- [ ] AC2: charts/spark-3.5/ (if applicable) default to ghcr.io
- [ ] AC3: Document override: image.repository, image.tag for custom builds
- [ ] AC4: Examples and tutorials updated
- [ ] AC5: helm install works with default values (pull from GHCR)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-033-04 (multi-arch images), WS-033-05 (tagging strategy).

### Input

- charts/spark-4.1/values.yaml
- charts/spark-3.5/ (if applicable)
- docs/guides/

### Scope

~100 LOC. See docs/workstreams/INDEX.md Feature F24.
