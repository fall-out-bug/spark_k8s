---
ws_id: 020-11
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-020-11: Celeborn Chart

### 🎯 Goal

**What must WORK after completing this WS:**
- Optional Apache Celeborn (disaggregated shuffle) Helm chart
- Masters + workers, configurable storage
- Integrates with Spark 4.1 K8s native executors

**Acceptance Criteria:**
- [x] AC1: `charts/celeborn/` or `charts/spark-4.1/templates/celeborn.yaml` exists
- [x] AC2: Celeborn master deployment (replicas configurable)
- [x] AC3: Celeborn worker StatefulSet with storage
- [x] AC4: values.yaml: celeborn.enabled (default false)
- [x] AC5: Spark executor config for Celeborn shuffle (when enabled)
- [x] AC6: `helm template` passes with celeborn.enabled=true

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- `docs/drafts/idea-spark-410-charts.md` (Apache Celeborn section)

### Scope

~440 LOC. See `docs/workstreams/INDEX.md` Feature F04.
