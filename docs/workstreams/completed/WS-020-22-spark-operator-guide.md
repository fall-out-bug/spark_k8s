---
ws_id: 020-22
feature: F04
status: completed
size: MEDIUM
project_id: 00
github_issue: null
assignee: null
depends_on: ["020-12", "020-13"]
---

## WS-020-22: Spark Operator Guide EN

### 🎯 Goal

**What must WORK after completing this WS:**
- Guide: CRD-based job management with Spark Operator
- SparkApplication examples, webhook, integration
- English

**Acceptance Criteria:**
- [x] AC1: docs/guides/SPARK-OPERATOR-GUIDE.md
- [x] AC2: Install operator via Helm
- [x] AC3: SparkApplication examples (Python, Scala, Java)
- [x] AC4: Integration with Spark 4.1 Connect/K8s native
- [x] AC5: Webhook validation (optional)
- [x] AC6: TTL, cleanup, monitoring

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-020-12 (Spark Operator chart), WS-020-13 (integration configs).

### Input

- charts/spark-operator/
- docs/drafts/idea-spark-410-charts.md (Spark Operator)

### Scope

~305 LOC. See docs/workstreams/INDEX.md Feature F04.
