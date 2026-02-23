---
ws_id: 020-13
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-06", "020-11", "020-12"]
---

## WS-020-13: Integration Configs

### 🎯 Goal

**What must WORK after completing this WS:**
- Integration configs for Spark Connect + Celeborn + Spark Operator
- Values overlays for combined scenarios
- Celeborn shuffle client config in executor

**Acceptance Criteria:**
- [x] AC1: values for Connect + Celeborn (when both enabled)
- [x] AC2: values for Connect + Operator (when both enabled)
- [x] AC3: Executor pod template includes Celeborn client config when celeborn.enabled
- [x] AC4: Scenario file: jupyter-connect-k8s-celeborn-4.1.0.yaml (or equivalent)
- [x] AC5: helm template passes for integration scenarios

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-06 (Spark Connect), WS-020-11 (Celeborn), WS-020-12 (Spark Operator).

### Input

- charts/spark-4.1/
- charts/celeborn/ or celeborn templates

### Scope

~130 LOC. See docs/workstreams/INDEX.md Feature F04.
