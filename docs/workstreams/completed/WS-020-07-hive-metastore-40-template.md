---
ws_id: 020-07
feature: F04
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-05"]
---

## WS-020-07: Hive Metastore 4.0.0 Template

### 🎯 Goal

**What must WORK after completing this WS:**
- Hive Metastore 4.0.0 deployment for Spark 4.1
- PostgreSQL backend, separate from Spark 3.5 metastore
- Conditional template (hiveMetastore.enabled)

**Acceptance Criteria:**
- [x] AC1: templates/hive-metastore.yaml (Deployment, Service)
- [x] AC2: Image: Hive 4.0.0 compatible with Spark 4.1
- [x] AC3: PostgreSQL connection (separate DB from 3.5)
- [x] AC4: values: hiveMetastore.enabled, image, database config
- [x] AC5: helm template with hiveMetastore.enabled=true passes

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-05 (spark-4.1 chart skeleton).

### Input

- charts/spark-4.1/
- charts/spark-3.5/templates/hive-metastore.yaml

### Scope

~210 LOC. See docs/workstreams/INDEX.md Feature F04.
