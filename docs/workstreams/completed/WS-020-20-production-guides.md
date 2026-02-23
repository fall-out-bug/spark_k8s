---
ws_id: 020-20
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-19"]
---

## WS-020-20: Production Guides EN+RU

### 🎯 Goal

**What must WORK after completing this WS:**
- Production best practices guide for Spark 4.1
- Resource sizing, HA, monitoring, security
- EN and RU versions

**Acceptance Criteria:**
- [x] AC1: docs/guides/SPARK-4.1-PRODUCTION.md (EN)
- [x] AC2: docs/guides/SPARK-4.1-PRODUCTION-RU.md (RU)
- [x] AC3: Resource sizing (driver, executor, Connect replicas)
- [x] AC4: HA considerations (multiple Connect replicas, Hive HA)
- [x] AC5: Monitoring (Prometheus, Grafana)
- [x] AC6: Security (RBAC, network policies, secrets)
- [x] AC7: Bilingual (EN/RU)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-19 (Quickstart guides).

### Input

- charts/spark-4.1/
- docs/drafts/idea-spark-410-charts.md

### Scope

~700 LOC. See docs/workstreams/INDEX.md Feature F04.
