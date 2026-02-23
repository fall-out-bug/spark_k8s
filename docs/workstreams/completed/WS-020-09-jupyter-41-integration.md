---
ws_id: 020-09
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-04", "020-06"]
---

## WS-020-09: Jupyter 4.1.0 Integration

### 🎯 Goal

**What must WORK after completing this WS:**
- Jupyter deployment uses jupyter-spark:4.1 image
- Connects to Spark Connect 4.1.0 server
- Scenario values files (jupyter-connect-k8s-4.1.0.yaml etc.)

**Acceptance Criteria:**
- [x] AC1: templates/jupyter.yaml uses Jupyter 4.1 image
- [x] AC2: Spark Connect client config (sc://connect-svc:15002)
- [x] AC3: Scenario files: jupyter-connect-k8s-4.1.0.yaml, jupyter-connect-standalone-4.1.0.yaml
- [x] AC4: helm template with jupyter.enabled=true passes
- [x] AC5: Jupyter pod can connect to Spark Connect and run PySpark

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-04 (Jupyter 4.1 image), WS-020-06 (Spark Connect 4.1 template).

### Input

- charts/spark-4.1/
- docker/jupyter-spark-4.1/
- charts/spark-3.5/templates/jupyter.yaml

### Scope

~150 LOC. See docs/workstreams/INDEX.md Feature F04.
