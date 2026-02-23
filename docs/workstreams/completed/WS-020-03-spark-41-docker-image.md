---
ws_id: 020-03
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-020-03: Spark 4.1.0 Docker Image

### 🎯 Goal

**What must WORK after completing this WS:**
- Docker image `spark-custom:4.1.0` builds and runs Spark Connect
- Image includes Connect, Kubernetes, Hadoop Cloud, Hive profiles
- Non-root user, PSS-compatible

**Acceptance Criteria:**
- [x] AC1: `docker/spark-4.1/Dockerfile` (or equivalent path) exists
- [x] AC2: Multi-stage build: builder (Spark dist) + runtime (slim base)
- [x] AC3: Spark 4.1.0 with -Pconnect -Pkubernetes -Phadoop-3 -Phadoop-cloud -Phive
- [x] AC4: Non-root user (e.g. 185:185)
- [x] AC5: `docker build -t spark-custom:4.1.0 .` succeeds
- [x] AC6: Image runs Spark Connect gRPC server

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/drafts/idea-spark-410-charts.md` (Docker Images section)
- `docker/spark-3.5/` for reference

### Scope

~270 LOC. See `docs/workstreams/INDEX.md` Feature F04.
