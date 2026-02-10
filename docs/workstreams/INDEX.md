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

## Feature F08: Phase 2 — Complete Smoke Tests

**Source:** `docs/phases/phase-02-smoke.md`
**Status:** In Progress
**Total Workstreams:** 7
**Estimated LOC:** ~6500

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-008-01 | Jupyter GPU/Iceberg scenarios (12) | SMALL (~500 LOC) | Phase 0, Phase 1, WS-006-06, WS-006-07 | backlog |
| WS-008-02 | Standalone chart baseline scenarios (24) | MEDIUM (~800 LOC) | F01 | in_progress |
| WS-008-03 | Spark Operator scenarios (32) | MEDIUM (~1200 LOC) | WS-020-12 | backlog |
| WS-008-04 | History Server validation scenarios (32) | MEDIUM (~1000 LOC) | WS-012-01 | backlog |
| WS-008-05 | MLflow scenarios (24) | MEDIUM (~800 LOC) | WS-001-07 | backlog |
| WS-008-06 | Dataset generation utilities | SMALL (~400 LOC) | WS-008-01 | backlog |
| WS-008-07 | Parallel execution improvements | SMALL (~600 LOC) | WS-008-02 | backlog |

### Current State (15 scenarios implemented)

| Компонент | Режим | Версия | Фича | Статус |
|-----------|-------|--------|------|--------|
| Jupyter | k8s-submit | 3.5.7, 3.5.8 | - | ✅ |
| Jupyter | connect-k8s | 4.1.0, 4.1.1 | - | ✅ |
| Jupyter | connect-standalone | 4.1.0, 4.1.1 | - | ✅ |
| Airflow | connect-k8s | 4.1.0, 4.1.1 | - | ✅ |
| Airflow | connect-standalone | 4.1.0, 4.1.1 | - | ✅ |
| Airflow | connect-k8s | 4.1.0, 4.1.1 | GPU | ✅ |
| Airflow | connect-k8s | 4.1.0, 4.1.1 | Iceberg | ✅ |

### Dependency Graph

```
Phase 0 (WS-006-01 to WS-006-09) ──────┐
Phase 1 (WS-022-01 to WS-022-04) ──────┼── WS-008-01 (Jupyter GPU/Iceberg) ──┐
F01 (WS-001-01 to WS-001-12) ──────────┤                                │
WS-006-06, WS-006-07 (GPU/Iceberg) ────┘                                │
                                                                   │
F01 (completed) ──────────────────────────────────────────────────────┼── WS-008-02 (Standalone) ────┐
                                                                   │                            │
WS-020-12 (Spark Operator) ─────────────────────────────────────────┼── WS-008-03 (Operator) ──────┤
                                                                   │                            │
WS-012-01 (History Server) ────────────────────────────────────────┼── WS-008-04 (History) ───────┼── WS-008-07 (Parallel
                                                                   │                            │        Execution)
WS-001-07 (MLflow) ─────────────────────────────────────────────────┼── WS-008-05 (MLflow) ────────┤
                                                                   │                            │
WS-008-01 ─────────────────────────────────────────────────────────┼── WS-008-06 (Dataset) ───────┘
                                                                   │
```

### Execution Order

**Phase 1: High Priority (P1)**
- WS-008-01: Jupyter GPU/Iceberg scenarios
- WS-008-02: Standalone chart scenarios
- WS-008-06: Dataset generation utilities

**Phase 3: Medium Priority (P2)**
- WS-008-03: Spark Operator scenarios
- WS-008-04: History Server scenarios

**Phase 4: Infrastructure (P1)**
- WS-008-07: Parallel execution improvements

**Phase 5: Low Priority (P3)**
- WS-008-05: MLflow scenarios

---

## Feature F09: Phase 3 — Docker Base Layers

**Source:** `docs/phases/phase-03-docker-base.md`
**Status:** Backlog
**Total Workstreams:** 3
**Estimated LOC:** ~1050

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-009-01 | JDK 17 base layer + test | SMALL (~300 LOC) | None | backlog |
| WS-009-02 | Python 3.10 base layer + test | SMALL (~250 LOC) | None | backlog |
| WS-009-03 | CUDA 12.1 base layer + test | MEDIUM (~500 LOC) | WS-009-01 | backlog |

### Dependency Graph

```
WS-009-01 (JDK 17 base layer) ──────┐
WS-009-02 (Python 3.10 base layer) ─┼── Independent (parallel)
                                   │
                                   │
WS-009-01 ─────────────────────────┴── WS-009-03 (CUDA 12.1 base layer)
```

### Execution Order

**Phase 1: Parallel Start (P1)**
- WS-009-01: JDK 17 base layer
- WS-009-02: Python 3.10 base layer

**Phase 2: After JDK 17 (P1)**
- WS-009-03: CUDA 12.1 base layer (extends JDK 17)

---

## Feature F10: Phase 4 — Docker Intermediate Layers

**Source:** `docs/phases/phase-04-docker-intermediate.md`
**Status:** Backlog
**Total Workstreams:** 4
**Estimated LOC:** ~2500

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-010-01 | Spark core layers (4) + tests | MEDIUM (~800 LOC) | F09 | backlog |
| WS-010-02 | Python dependencies layer + test | MEDIUM (~600 LOC) | F09 | backlog |
| WS-010-03 | JDBC drivers layer + test | SMALL (~400 LOC) | F09 | backlog |
| WS-010-04 | JARs layers (RAPIDS, Iceberg) + tests | MEDIUM (~700 LOC) | F09, WS-010-01 | backlog |

### Dependency Graph

```
F09 (Phase 3 - Base Layers) ──────┐
                                   ├── WS-010-01 (Spark core) ────┐
                                   │                            │
                                   ├── WS-010-02 (Python deps)   ├── WS-010-04 (JARs)
                                   │                            │
                                   └── WS-010-03 (JDBC drivers) ──┘
```

### Execution Order

**Phase 1: Parallel Start (after F09)**
- WS-010-01: Spark core layers
- WS-010-02: Python dependencies
- WS-010-03: JDBC drivers

**Phase 2: After Spark core (P1)**
- WS-010-04: JARs layers (extends Spark core)

---

## Feature F11: Phase 5 — Docker Final Images

**Source:** `docs/phases/phase-05-docker-final.md`
**Status:** Backlog
**Total Workstreams:** 3
**Estimated LOC:** ~3900

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-011-01 | Spark 3.5 images (8) + tests | LARGE (~1200 LOC) | F10 | backlog |
| WS-011-02 | Spark 4.1 images (8) + tests | LARGE (~1200 LOC) | F10 | backlog |
| WS-011-03 | Jupyter images (12) + tests | LARGE (~1500 LOC) | F10, WS-011-01, WS-011-02 | backlog |

### Dependency Graph

```
F10 (Phase 4 - Intermediate Layers) ───┐
                                       ├── WS-011-01 (Spark 3.5) ────┐
                                       │                            │
                                       ├── WS-011-02 (Spark 4.1) ────┼── WS-011-03 (Jupyter)
                                       │                            │
                                       └── WS-009-02 (Python base) ────┘
```

### Execution Order

**Phase 1: Parallel Start (after F10)**
- WS-011-01: Spark 3.5 images
- WS-011-02: Spark 4.1 images

**Phase 2: After Spark images (P1)**
- WS-011-03: Jupyter images (depends on Spark images)

---

## Feature F12: Phase 6 — E2E Tests

**Source:** `docs/phases/phase-06-e2e.md`
**Status:** Backlog
**Total Workstreams:** 6
**Estimated LOC:** ~4900

| ID | Name | Scenarios | Dependency | Status |
|----|------|-----------|------------|--------|
| WS-012-01 | Core E2E | 24 | F06, F07, F11 | backlog |
| WS-012-02 | GPU E2E | 16 | F06, F07, F11 | backlog |
| WS-012-03 | Iceberg E2E | 16 | F06, F07, F11 | backlog |
| WS-012-04 | GPU+Iceberg E2E | 8 | F06, F07, F11 | backlog |
| WS-012-05 | Standalone E2E | 8 | F06, F07 | backlog |
| WS-012-06 | Library compatibility | 8 | F06, F07 | backlog |

### Dependency Graph

```
F06 (Phase 0), F07 (Phase 1), F11 (Phase 5) ────┐
                                                ├── WS-012-01 (Core E2E)
                                                ├── WS-012-02 (GPU E2E)
                                                ├── WS-012-03 (Iceberg E2E)
                                                ├── WS-012-04 (GPU+Iceberg E2E)
                                                ├── WS-012-05 (Standalone E2E)
                                                └── WS-012-06 (Library compatibility)
```

### Execution Order

**All workstreams can run in parallel after Phases 0, 1, 5 complete.**

---

## Feature F13: Phase 7 — Load Tests

**Source:** `docs/phases/phase-07-load.md`
**Status:** Backlog
**Total Workstreams:** 5
**Estimated LOC:** ~3000

| ID | Name | Scenarios | Dependency | Status |
|----|------|-----------|------------|--------|
| WS-013-01 | Baseline load | 4 | F06, F12 | backlog |
| WS-013-02 | GPU load | 4 | F06, F12 | backlog |
| WS-013-03 | Iceberg load | 4 | F06, F12 | backlog |
| WS-013-04 | Comparison load | 4 | F06, F12 | backlog |
| WS-013-05 | Security stability | 4 | F06, F07 | backlog |

### Dependency Graph

```
F06 (Phase 0), F07 (Phase 1), F12 (Phase 6) ────┐
                                                ├── WS-013-01 (Baseline load)
                                                ├── WS-013-02 (GPU load)
                                                ├── WS-013-03 (Iceberg load)
                                                ├── WS-013-04 (Comparison load)
                                                └── WS-013-05 (Security stability)
```

### Execution Order

**All workstreams can run in parallel after Phases 0, 1, 6 complete.**

---

## Feature F14: Phase 8 — Advanced Security

**Source:** `docs/phases/phase-08-security.md`
**Status:** Backlog
**Total Workstreams:** 7
**Estimated LOC:** ~4200

| ID | Name | Scenarios | Dependency | Status |
|----|------|-----------|------------|--------|
| WS-014-01 | PSS tests | 8 | F06, F07 | backlog |
| WS-014-02 | SCC tests | 12 | F06, F07 | backlog |
| WS-014-03 | Network policies | 6 | F06, F07 | backlog |
| WS-014-04 | RBAC tests | 6 | F06, F07 | backlog |
| WS-014-05 | Secret management | 6 | F06, F07 | backlog |
| WS-014-06 | Container security | 8 | F06, F07 | backlog |
| WS-014-07 | S3 security | 6 | F06, F07 | backlog |

### Dependency Graph

```
F06 (Phase 0), F07 (Phase 1) ────┐
                                ├── WS-014-01 (PSS tests)
                                ├── WS-014-02 (SCC tests)
                                ├── WS-014-03 (Network policies)
                                ├── WS-014-04 (RBAC tests)
                                ├── WS-014-05 (Secret management)
                                ├── WS-014-06 (Container security)
                                └── WS-014-07 (S3 security)
```

### Execution Order

**All workstreams can run in parallel after Phases 0, 1 complete.**

---

## Feature F15: Phase 9 — Parallel Execution & CI/CD

**Source:** `docs/phases/phase-09-parallel.md`
**Status:** Backlog
**Total Workstreams:** 3
**Estimated LOC:** ~2100

| ID | Name | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-015-01 | Parallel execution framework | MEDIUM (~800 LOC) | F06, F08, F12, F13 | backlog |
| WS-015-02 | Result aggregation | MEDIUM (~600 LOC) | WS-015-01 | backlog |
| WS-015-03 | CI/CD integration | MEDIUM (~700 LOC) | WS-015-02 | backlog |

### Dependency Graph

```
F06, F08, F12, F13 ──── WS-015-01 (Parallel execution)
                          │
                          └── WS-015-02 (Result aggregation)
                                │
                                └── WS-015-03 (CI/CD integration)
```

### Execution Order

**Sequential:** WS-015-01 → WS-015-02 → WS-015-03

---

## Feature F16: Observability Stack (Monitoring & Tracing)

**Source:** `docs/drafts/feature-observability.md`
**Status:** Backlog
**Total Workstreams:** 6
**Estimated LOC:** ~3600

| ID | Name | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-016-01 | Metrics collection (Prometheus) | MEDIUM (~700 LOC) | F06 | backlog |
| WS-016-02 | Logging aggregation (Loki) | MEDIUM (~600 LOC) | F06 | backlog |
| WS-016-03 | Distributed tracing (Jaeger/OTel) | MEDIUM (~600 LOC) | F06 | backlog |
| WS-016-04 | Dashboards (Grafana) | MEDIUM (~500 LOC) | WS-016-01, WS-016-02 | backlog |
| WS-016-05 | Alerting rules | MEDIUM (~400 LOC) | WS-016-01 | backlog |
| WS-016-06 | Spark UI integration | MEDIUM (~800 LOC) | WS-016-01, WS-016-03 | backlog |

### Dependency Graph

```
F06 ────────────────────────────────┐
                                      ├── WS-016-01 (Metrics) ────┐
                                      ├── WS-016-02 (Logging) ────┼── WS-016-04 (Dashboards)
                                      ├── WS-016-03 (Tracing) ────┤
                                      │                            │
                                      └── WS-016-05 (Alerting)    │
                                                                   │
                                   WS-016-01 + WS-016-03 ───────────┴── WS-016-06 (Spark UI)
```

---

## Feature F17: Spark Connect Go Client

**Source:** `docs/drafts/feature-spark-connect-go.md`
**Status:** Backlog
**Total Workstreams:** 4
**Estimated LOC:** ~2800

| ID | Name | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-017-01 | Spark Connect Go client library | MEDIUM (~800 LOC) | F06, F11 | backlog |
| WS-017-02 | Go smoke tests | MEDIUM (~600 LOC) | WS-017-01 | backlog |
| WS-017-03 | Go E2E tests | MEDIUM (~700 LOC) | WS-017-01 | backlog |
| WS-017-04 | Go load tests | MEDIUM (~700 LOC) | WS-017-01 | backlog |

### Dependency Graph

```
F06, F11 ──── WS-017-01 (Go client library)
                │
                ├── WS-017-02 (Go smoke tests)
                ├── WS-017-03 (Go E2E tests)
                └── WS-017-04 (Go load tests)
```

---

## Feature F25: Spark 3.5 Charts Production-Ready

**Source:** `docs/drafts/idea-spark-35-production-ready.md`
**Status:** Backlog
**Total Workstreams:** 9
**Estimated LOC:** ~2000
**Bead:** spark_k8s-ju2

| ID | Name | Scope | Dependency | Status | Bead |
|----|------|-------|------------|--------|------|
| WS-025-01 | Fix chart metadata + values.yaml | SMALL (~150 LOC) | - | backlog | spark_k8s-r6h |
| WS-025-02 | Spark Standalone deployment template | MEDIUM (~300 LOC) | - | backlog | spark_k8s-3ip |
| WS-025-03 | Prometheus metrics exporter config | SMALL (~100 LOC) | WS-025-01 | backlog | spark_k8s-ngl |
| WS-025-04 | Monitoring templates (SM+PM+Grafana) | MEDIUM (~500 LOC) | WS-025-03 | backlog | spark_k8s-pqx |
| WS-025-05 | OpenShift Route template | SMALL (~150 LOC) | - | backlog | spark_k8s-2zy |
| WS-025-06 | Fix 8 scenario values files | MEDIUM (~400 LOC) | WS-025-01, WS-025-02 | backlog | spark_k8s-ni8 |
| WS-025-07 | Update OpenShift presets | SMALL (~100 LOC) | WS-025-04, WS-025-05 | backlog | spark_k8s-r51 |
| WS-025-08 | Fix spark-connect-configmap | SMALL (~50 LOC) | WS-025-01 | backlog | spark_k8s-og4 |
| WS-025-09 | Helm validation + smoke tests | MEDIUM (~300 LOC) | WS-025-06..08 | backlog | spark_k8s-2if |
| WS-025-10 | Minikube integration tests | MEDIUM (~400 LOC) | WS-025-09 | backlog | spark_k8s-6q1 |

### Dependency Graph

```
WS-025-01 (Fix metadata)     WS-025-02 (Standalone)     WS-025-05 (Routes)
    │                              │                          │
    ├── WS-025-03 (Metrics) ───┐   │                          │
    │       │                  │   │                          │
    │       └── WS-025-04 ─────┼───┼──────────────────────────┤
    │           (Monitoring)   │   │                          │
    │                          │   │                          │
    ├── WS-025-08 (Configmap)  │   │      WS-025-07 ◄────────┘
    │                          │   │      (OpenShift presets)
    │                          │   │          │
    └──────────────────────────┴───┘          │
                │                             │
          WS-025-06 (Scenarios)               │
                │                             │
                └─────────────────────────────┘
                              │
                        WS-025-09 (Validation)
                              │
                        WS-025-10 (Minikube tests)
```

### Parallel Execution Paths

**Phase 1 (parallel):** WS-025-01 + WS-025-02 + WS-025-05
**Phase 2 (after 01):** WS-025-03, WS-025-08
**Phase 3 (after 03):** WS-025-04
**Phase 4 (after 01+02):** WS-025-06
**Phase 5 (after 04+05):** WS-025-07
**Phase 6 (after 06+07+08):** WS-025-09
**Phase 7 (after 09):** WS-025-10 (minikube integration tests)

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
| F08: Phase 2 — Smoke Tests | 7 | 0 | 0 | 7 |
| F09: Phase 3 — Docker Base Layers | 3 | 0 | 0 | 3 |
| F10: Phase 4 — Docker Intermediate Layers | 4 | 0 | 0 | 4 |
| F11: Phase 5 — Docker Final Images | 3 | 0 | 0 | 3 |
| F12: Phase 6 — E2E Tests | 6 | 0 | 0 | 6 |
| F13: Phase 7 — Load Tests | 5 | 0 | 0 | 5 |
| F14: Phase 8 — Advanced Security | 7 | 0 | 0 | 7 |
| F15: Phase 9 — Parallel Execution & CI/CD | 3 | 0 | 0 | 3 |
| F16: Observability Stack | 6 | 0 | 0 | 6 |
| F17: Spark Connect Go Client | 4 | 0 | 0 | 4 |
| **F25: Spark 3.5 Production-Ready** | **10** | **0** | **0** | **10** |
| TESTING: Testing Infrastructure | 3+ | 0 | 0 | 3+ |
| **TOTAL** | **119+** | **30** | **1** | **90+** |

---

*Last updated: 2026-02-10*
