# Workstreams Index

## Feature F01: Spark Standalone Helm Chart

**Source:** `docs/drafts/idea-spark-standalone-chart.md`
**Status:** In Progress (WS executing/reviewed; some backlog remains)
**Total Workstreams:** 12
**Estimated LOC:** ~2600

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-001-01 | Chart Skeleton | SMALL (~400 LOC) | - | completed |
| WS-001-02 | Spark Master | SMALL (~250 LOC) | WS-001-01 | completed |
| WS-001-03 | Spark Workers | SMALL (~200 LOC) | WS-001-02 | completed |
| WS-001-04 | External Shuffle Service | SMALL (~150 LOC) | WS-001-03 | completed |
| WS-001-05 | Hive Metastore | SMALL (~300 LOC) | WS-001-01 | completed |
| WS-001-06 | Airflow | MEDIUM (~500 LOC) | WS-001-03 | completed |
| WS-001-07 | MLflow | SMALL (~300 LOC) | WS-001-01 | completed |
| WS-001-08 | Ingress | SMALL (~120 LOC) | WS-001-06, WS-001-07 | completed |
| WS-001-09 | Security Hardening | MEDIUM (~400 LOC) | WS-001-07 | completed |
| WS-001-10 | Example DAGs & Tests | MEDIUM (~400 LOC) | WS-001-09 | completed |
| WS-001-11 | Prod-like Airflow Tests | SMALL (~250 LOC) | WS-001-10 | completed |
| WS-001-12 | Shared Values Compatibility | SMALL (~150 LOC) | WS-001-10 | completed |

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
| F01: Spark Standalone | 12 | 12 | 0 | 0 |
| F02: Repo Documentation | 4 | 4 | 0 | 0 |
| F03: History Server (SA) | 2 | 2 | 0 | 0 |

---

*Last updated: 2026-01-16*

## Feature F02: Repository Documentation (Charts + How-To Guides)

**Source:** `docs/drafts/idea-repo-documentation.md`  
**Status:** Completed  
**Total Workstreams:** 4  
**Estimated LOC:** ~1400 (docs)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-011-01 | Docs skeleton (README index + repo map) | SMALL (~200 LOC) | - | completed |
| WS-011-02 | Guides EN + overlays | MEDIUM (~600 LOC) | WS-011-01 | completed |
| WS-011-03 | Guides RU + overlays | MEDIUM (~600 LOC) | WS-011-02 | completed |
| WS-011-04 | Validation runbook + OpenShift notes | MEDIUM (~500 LOC) | WS-011-01 | completed |

### Dependency Graph

```
WS-011-01
  ├── WS-011-02 → WS-011-03
  └── WS-011-04
```

---

## Feature F03: Spark History Server for Standalone Chart

**Source:** `docs/drafts/idea-add-history-server.md`  
**Status:** Completed  
**Total Workstreams:** 2  
**Actual LOC:** ~150

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-012-01 | History Server Template | SMALL (116 LOC) | - | completed |
| WS-012-02 | History Server Smoke Test | SMALL (35 LOC) | WS-012-01 | completed |

### Dependency Graph

```
WS-012-01 → WS-012-02
```

### Review Summary

**Review Date:** 2026-01-16  
**Verdict:** ✅ APPROVED

Both workstreams passed all quality checks. Static validation complete. Runtime validation available via UAT guide (`docs/uat/UAT-F03-history-server.md`).
