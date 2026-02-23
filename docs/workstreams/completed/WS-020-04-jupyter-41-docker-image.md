---
ws_id: 020-04
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-020-04: Jupyter 4.1.0 Docker Image

### 🎯 Goal

**What must WORK after completing this WS:**
- Docker image for Jupyter + Spark 4.1.0 client
- Based on official `apache/spark-py:4.1.0` with minimal customization
- JupyterLab connects to Spark Connect server

**Acceptance Criteria:**
- [x] AC1: `docker/jupyter-spark-4.1/Dockerfile` (or equivalent) exists
- [x] AC2: Base: apache/spark-py:4.1.0
- [x] AC3: JupyterLab installed (jupyterlab, pyspark==4.1.0)
- [x] AC4: Spark Connect client config copied (spark_config.py or equivalent)
- [x] AC5: Non-root user
- [x] AC6: `docker build` succeeds; container runs JupyterLab

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/drafts/idea-spark-410-charts.md` (Jupyter Image section)
- `docker/` structure for spark-3.5 Jupyter

### Scope

~345 LOC. See `docs/workstreams/INDEX.md` Feature F04.
