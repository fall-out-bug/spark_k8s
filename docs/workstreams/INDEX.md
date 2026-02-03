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

---

## Feature F04: Apache Spark 4.1.0 Charts

**Source:** `docs/drafts/idea-spark-410-charts.md`
**Status:** Backlog
**Total Workstreams:** 24
**Estimated LOC:** ~7500 (charts + docs + tests)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-020-01 | Create spark-base chart | MEDIUM (~545 LOC) | - | backlog |
| WS-020-02 | Refactor to spark-3.5 structure | MEDIUM (~500 LOC) | WS-020-01 | backlog |
| WS-020-03 | Spark 4.1.0 Docker image | SMALL (~270 LOC) | - | backlog |
| WS-020-04 | Jupyter 4.1.0 Docker image | SMALL (~345 LOC) | - | backlog |
| WS-020-05 | spark-4.1 chart skeleton | MEDIUM (~595 LOC) | WS-020-01 | backlog |
| WS-020-06 | Spark Connect 4.1.0 template | MEDIUM (~360 LOC) | WS-020-05 | backlog |
| WS-020-07 | Hive Metastore 4.0.0 template | SMALL (~210 LOC) | WS-020-05 | backlog |
| WS-020-08 | History Server 4.1.0 template | SMALL (~200 LOC) | WS-020-03 | backlog |
| WS-020-09 | Jupyter 4.1.0 integration | SMALL (~150 LOC) | WS-020-04, WS-020-06 | backlog |
| WS-020-10 | RBAC + Service templates | SMALL (~100 LOC) | WS-020-01 | backlog |
| WS-020-11 | Celeborn chart | MEDIUM (~440 LOC) | - | backlog |
| WS-020-12 | Spark Operator chart | MEDIUM (~860 LOC) | - | backlog |
| WS-020-13 | Integration configs | SMALL (~130 LOC) | WS-020-06, WS-020-11, WS-020-12 | backlog |
| WS-020-14 | Smoke test script | SMALL (~200 LOC) | WS-020-06 to WS-020-10 | backlog |
| WS-020-15 | Coexistence test | SMALL (~180 LOC) | WS-020-02, WS-020-14 | backlog |
| WS-020-16 | History Server compat test | SMALL (~180 LOC) | WS-020-08, WS-020-15 | backlog |
| WS-020-17 | Integration tests | SMALL (~200 LOC) | WS-020-09, WS-020-11, WS-020-12 | backlog |
| WS-020-18 | Performance benchmark | MEDIUM (~300 LOC) | WS-020-14, WS-020-15 | backlog |
| WS-020-19 | Quickstart guides EN+RU | SMALL (~300 LOC) | WS-020-06 to WS-020-10 | backlog |
| WS-020-20 | Production guides EN+RU | MEDIUM (~700 LOC) | WS-020-19 | backlog |
| WS-020-21 | Celeborn guide EN | SMALL (~250 LOC) | WS-020-11, WS-020-13 | backlog |
| WS-020-22 | Spark Operator guide EN | MEDIUM (~305 LOC) | WS-020-12, WS-020-13 | backlog |
| WS-020-23 | Multi-version guide EN+RU | MEDIUM (~400 LOC) | WS-020-15, WS-020-20 | backlog |
| WS-020-24 | ADRs + values overlays | MEDIUM (~430 LOC) | - | backlog |

### Dependency Graph

**Phase 1: Infrastructure & Base**
```
WS-020-01 (spark-base) → WS-020-02 (refactor spark-3.5)
                       → WS-020-05 (spark-4.1 skeleton)

WS-020-03 (Spark 4.1.0 image) → independent
WS-020-04 (Jupyter 4.1.0 image) → independent
```

**Phase 2: Core Spark 4.1 Components**
```
WS-020-05 → WS-020-06 (Spark Connect)
         → WS-020-07 (Hive Metastore)
         → WS-020-08 (History Server)
         → WS-020-10 (RBAC)

WS-020-04 + WS-020-06 → WS-020-09 (Jupyter integration)
```

**Phase 3: Optional Components**
```
WS-020-11 (Celeborn) → independent
WS-020-12 (Spark Operator) → independent
WS-020-06 + WS-020-11 + WS-020-12 → WS-020-13 (integration configs)
```

**Phase 4: Testing**
```
WS-020-06..WS-020-10 → WS-020-14 (smoke test)
WS-020-02 + WS-020-14 → WS-020-15 (coexistence)
WS-020-08 + WS-020-15 → WS-020-16 (history compat)
WS-020-09 + WS-020-11 + WS-020-12 → WS-020-17 (integration tests)
WS-020-14 + WS-020-15 → WS-020-18 (benchmark)
```

**Phase 5: Documentation**
```
WS-020-06..WS-020-10 → WS-020-19 (quickstart)
WS-020-19 → WS-020-20 (production guides)
WS-020-11 + WS-020-13 → WS-020-21 (Celeborn guide)
WS-020-12 + WS-020-13 → WS-020-22 (Operator guide)
WS-020-15 + WS-020-20 → WS-020-23 (multi-version guide)
WS-020-24 (ADRs) → independent
```

### Parallel Execution Paths

1. **Infrastructure Path:** WS-020-01 → WS-020-02 → WS-020-05
2. **Docker Images Path:** WS-020-03, WS-020-04 (parallel)
3. **Core Components Path:** WS-020-05 → WS-020-06, WS-020-07, WS-020-08, WS-020-09, WS-020-10 (some parallel)
4. **Optional Components Path:** WS-020-11, WS-020-12, WS-020-13 (mostly parallel)
5. **Testing Path:** WS-020-14 → WS-020-15 → WS-020-16, WS-020-17, WS-020-18
6. **Documentation Path:** WS-020-19 → WS-020-20 → WS-020-21, WS-020-22, WS-020-23, WS-020-24

---

## Feature F05: Documentation Refresh (prod-like Airflow vars)

**Source:** `docs/drafts/idea-repo-documentation.md`
**Status:** Backlog
**Total Workstreams:** 2
**Estimated LOC:** ~200 (docs)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-021-01 | Update validation docs EN (Airflow vars) | SMALL (~120 LOC) | - | backlog |
| WS-021-02 | Update validation docs RU (Airflow vars) | SMALL (~120 LOC) | WS-021-01 | backlog |

### Dependency Graph

```
WS-021-01 → WS-021-02
```

---

## Feature F06: Phase 0 — Core Components + Feature Presets

**Source:** `docs/drafts/idea-f06-core-components-presets.md`
**Status:** Completed
**Total Workstreams:** 10
**Actual LOC:** ~4000

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-006-01 | Core template structure foundation | MEDIUM (~300 LOC) | Independent | completed |
| WS-006-02 | Minio core template | MEDIUM (~350 LOC) | WS-006-01 | completed |
| WS-006-03 | PostgreSQL core template | MEDIUM (~300 LOC) | WS-006-01 | completed |
| WS-006-04 | Hive Metastore core template | MEDIUM (~400 LOC) | WS-006-01, WS-006-03 | completed |
| WS-006-05 | History Server core template | MEDIUM (~350 LOC) | WS-006-01, WS-006-02 | completed |
| WS-006-06 | GPU feature templates | MEDIUM (~250 LOC) | WS-006-01 | completed |
| WS-006-07 | Iceberg feature templates | MEDIUM (~250 LOC) | WS-006-01 | completed |
| WS-006-08 | Base presets (Core + Features) | MEDIUM (~400 LOC) | WS-006-01, WS-006-02, WS-006-03, WS-006-04, WS-006-05 | completed |
| WS-006-09 | Scenario presets (Jupyter + Airflow) | MEDIUM (~450 LOC) | WS-006-01, WS-006-08 | completed |
| WS-006-10 | Chart documentation (README) | MEDIUM (~600 LOC) | WS-006-08, WS-006-09 | completed |

### Dependency Graph

```
WS-006-01 (Core Template Structure)
    ├── WS-006-02 (Minio) ──────────────┐
    ├── WS-006-03 (PostgreSQL) ────────┤
    ├── WS-006-04 (Hive Metastore) ────┼── WS-006-08 (Base Presets) ────┐
    ├── WS-006-05 (History Server) ────┤                               │
    ├── WS-006-06 (GPU Features) ────────┤                               ├─ WS-006-10 (Docs)
    └── WS-006-07 (Iceberg Features) ───┘                               │
                                                                             │
WS-006-01 ────────────────────────────────────────────────────────────────┘
    │
    └── WS-006-09 (Scenario Presets) ──────────────────────────────────────┘
```

### Parallel Execution Paths

**Phase 1: Foundation**
- WS-006-01 (Core template structure) - MUST BE FIRST

**Phase 2: Core Components (parallel after WS-006-01)**
- WS-006-02 (Minio)
- WS-006-03 (PostgreSQL)
- WS-006-05 (History Server - needs Minio)
- WS-006-06 (GPU Features)
- WS-006-07 (Iceberg Features)

**Phase 3: Core Integration (sequential)**
- WS-006-04 (Hive Metastore - needs PostgreSQL)

**Phase 4: Presets**
- WS-006-08 (Base presets - needs all Core Components)
- WS-006-09 (Scenario presets - needs Base presets)

**Phase 5: Documentation**
- WS-006-10 (README - needs Presets)

### Execution Order

1. **WS-006-01** - Create core template structure
2. **Parallel:** WS-006-02 (Minio), WS-006-03 (PostgreSQL), WS-006-06 (GPU), WS-006-07 (Iceberg)
3. **Parallel:** WS-006-04 (Hive Metastore - after WS-006-03), WS-006-05 (History Server - after WS-006-02)
4. **WS-006-08** (Base presets - after all Core Components)
5. **WS-006-09** (Scenario presets - after WS-006-01, WS-006-08)
6. **WS-006-10** (Documentation - after WS-006-08, WS-006-09)

---

## Feature F07: Phase 1 — Critical Security + Chart Updates

**Source:** Implementation Plan (Critical Security + Chart Updates)
**Status:** In Progress
**Total Workstreams:** 4
**Estimated LOC:** ~1250

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-022-01 | Create namespace.yaml Templates | SMALL (~150 LOC) | - | in_progress |
| WS-022-02 | Enable podSecurityStandards by Default | SMALL (~100 LOC) | - | backlog |
| WS-022-03 | Create OpenShift Presets | MEDIUM (~400 LOC) | WS-022-01, WS-022-02 | backlog |
| WS-022-04 | Create PSS/SCC Smoke Tests | MEDIUM (~600 LOC) | WS-022-03 | backlog |

### Dependency Graph

```
WS-022-01 (namespace.yaml)
    │
    ├─> WS-022-02 (podSecurityStandards default) [PARALLEL]
    │       │
    │       └─> WS-022-03 (OpenShift presets)
    │               │
    │               └─> WS-022-04 (Smoke tests)
    │
    └─> WS-022-03 (OpenShift presets)
            │
            └─> WS-022-04 (Smoke tests)
```

### Execution Order

1. **Parallel:** WS-022-01 + WS-022-02
2. **Sequential:** WS-022-03 (after 1+2 complete)
3. **Sequential:** WS-022-04 (after all complete)

---

## Feature TESTING: Testing Infrastructure

**Source:** `docs/issues/issue-001-minikube-pvc-provisioning.md`
**Status:** In Progress
**Total Workstreams:** 1+
**Estimated LOC:** ~150 (diagnostics)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-TESTING-001 | Minikube storage diagnostics | SMALL (~150 LOC) | - | backlog |
| WS-TESTING-002 | Storage provisioner fix | TBD | WS-TESTING-001 | backlog |
| WS-TESTING-003 | Complete E2E test | TBD | WS-TESTING-002 | backlog |

### Context

PVC provisioning in minikube (WSL2) fails, blocking E2E testing.
This feature tracks diagnostics and fix implementation.

### Dependency Graph

```
WS-TESTING-001 (Diagnostics)
    └── WS-TESTING-002 (Fix Implementation)
            └── WS-TESTING-003 (E2E Test)
```

---

## Summary

| Feature | Total WS | Completed | In Progress | Backlog |
|---------|----------|-----------|-------------|---------|
| F01: Spark Standalone | 12 | 12 | 0 | 0 |
| F02: Repo Documentation | 4 | 4 | 0 | 0 |
| F03: History Server (SA) | 2 | 2 | 0 | 0 |
| F04: Spark 4.1.0 Charts | 24 | 0 | 0 | 24 |
| F05: Docs Refresh (Airflow vars) | 2 | 0 | 0 | 2 |
| F06: Core Components + Presets | 10 | 10 | 0 | 0 |
| F07: Critical Security + Chart Updates | 4 | 0 | 1 | 3 |
| TESTING: Testing Infrastructure | 3+ | 0 | 0 | 3+ |
| **TOTAL** | **61+** | **30** | **1** | **32+** |

---

*Last updated: 2026-02-02*
