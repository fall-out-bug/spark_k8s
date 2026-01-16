# Workstreams Index

## Feature F01: Spark Standalone Helm Chart

**Source:** `docs/drafts/idea-spark-standalone-chart.md`
**Status:** Planning Complete
**Total Workstreams:** 12
**Estimated LOC:** ~2600

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-001-01 | Chart Skeleton | SMALL (~400 LOC) | - | backlog |
| WS-001-02 | Spark Master | SMALL (~250 LOC) | WS-001-01 | backlog |
| WS-001-03 | Spark Workers | SMALL (~200 LOC) | WS-001-02 | backlog |
| WS-001-04 | External Shuffle Service | SMALL (~150 LOC) | WS-001-03 | backlog |
| WS-001-05 | Hive Metastore | SMALL (~300 LOC) | WS-001-01 | backlog |
| WS-001-06 | Airflow | MEDIUM (~500 LOC) | WS-001-03 | backlog |
| WS-001-07 | MLflow | SMALL (~300 LOC) | WS-001-01 | backlog |
| WS-001-08 | Ingress | SMALL (~120 LOC) | WS-001-06, WS-001-07 | backlog |
| WS-001-09 | Security Hardening | MEDIUM (~400 LOC) | WS-001-07 | backlog |
| WS-001-10 | Example DAGs & Tests | MEDIUM (~400 LOC) | WS-001-09 | backlog |
| WS-001-11 | Prod-like Airflow Tests | SMALL (~250 LOC) | WS-001-10 | backlog |
| WS-001-12 | Shared Values Compatibility | SMALL (~150 LOC) | WS-001-10 | backlog |

### Dependency Graph

```
WS-001-01 (Chart Skeleton)
    ├── WS-001-02 (Spark Master)
    │       └── WS-001-03 (Spark Workers)
    │               ├── WS-001-04 (Shuffle Service)
    │               └── WS-001-06 (Airflow)
    │                       └── WS-001-08 (Ingress)
    ├── WS-001-05 (Hive Metastore)
    └── WS-001-07 (MLflow)
            └── WS-001-08 (Ingress)
                    └── WS-001-09 (Security Hardening)
                            └── WS-001-10 (DAGs & Tests)
                                    └── WS-001-11 (Prod-like Airflow Tests)
                                    └── WS-001-12 (Shared Values Compatibility)
```

### Parallel Execution Paths

1. **Critical Path:** WS-001-01 → WS-001-02 → WS-001-03 → WS-001-06 → WS-001-08 → WS-001-09 → WS-001-10 → WS-001-11
2. **Parallel:** WS-001-04, WS-001-05, WS-001-07 can run after their dependencies

---

## Summary

| Feature | Total WS | Completed | In Progress | Backlog |
|---------|----------|-----------|-------------|---------|
| F01: Spark Standalone | 12 | 0 | 0 | 12 |

---

*Last updated: 2026-01-15*
