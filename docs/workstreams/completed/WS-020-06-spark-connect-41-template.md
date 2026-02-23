---
ws_id: 020-06
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-05"]
---

## WS-020-06: Spark Connect 4.1.0 Template

### 🎯 Goal

**What must WORK after completing this WS:**
- Spark Connect 4.1.0 deployment template (Deployment, Service, ConfigMap)
- K8s native executor config, dynamic allocation, shuffle tracking
- gRPC server on port 15002

**Acceptance Criteria:**
- [x] AC1: templates/spark-connect.yaml (Deployment for Connect server)
- [x] AC2: templates/spark-connect-configmap.yaml (spark-defaults, executor pod template path)
- [x] AC3: values: connect.enabled, connect.grpc.port, dynamicAllocation, kubernetes.executor
- [x] AC4: Executor pod template ConfigMap for K8s native
- [x] AC5: helm template with connect.enabled=true produces valid manifests

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-05 (spark-4.1 chart skeleton).

### Input

- charts/spark-4.1/
- charts/spark-3.5/templates/spark-connect*.yaml
- docs/drafts/idea-spark-410-charts.md

### Scope

~360 LOC. See docs/workstreams/INDEX.md Feature F04.
