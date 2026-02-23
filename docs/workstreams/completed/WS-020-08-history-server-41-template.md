---
ws_id: 020-08
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-03"]
---

## WS-020-08: History Server 4.1.0 Template

### 🎯 Goal

**What must WORK after completing this WS:**
- History Server 4.1.0 deployment template
- Reads event logs from S3 (version-specific prefix)
- Separate from Spark 3.5 History Server

**Acceptance Criteria:**
- [x] AC1: templates/history-server.yaml (Deployment, Service)
- [x] AC2: Image: Spark 4.1.0 (or spark-custom:4.1.0)
- [x] AC3: Event log path: s3a://spark-logs/4.1/events (configurable)
- [x] AC4: values: historyServer.enabled, image, eventLogDir
- [x] AC5: helm template with historyServer.enabled=true passes

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-03 (Spark 4.1.0 Docker image).

### Input

- charts/spark-4.1/
- charts/spark-3.5/templates/history-server.yaml

### Scope

~200 LOC. See docs/workstreams/INDEX.md Feature F04.
