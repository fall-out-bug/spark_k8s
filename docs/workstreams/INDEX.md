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
**Status:** Completed
**Total Workstreams:** 2
**Estimated LOC:** ~200 (docs)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-021-01 | Update validation docs EN (Airflow vars) | SMALL (~120 LOC) | - | completed |
| WS-021-02 | Update validation docs RU (Airflow vars) | SMALL (~120 LOC) | WS-021-01 | completed |

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
**Status:** Completed
**Total Workstreams:** 4
**Estimated LOC:** ~1250

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-022-01 | Create namespace.yaml Templates | SMALL (~150 LOC) | - | completed |
| WS-022-02 | Enable podSecurityStandards by Default | SMALL (~100 LOC) | - | completed |
| WS-022-03 | Create OpenShift Presets | MEDIUM (~400 LOC) | WS-022-01, WS-022-02 | completed |
| WS-022-04 | Create PSS/SCC Smoke Tests | MEDIUM (~600 LOC) | WS-022-03 | completed |

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

## Feature F22: Progress Automation

**Source:** `docs/drafts/idea-f22-progress-automation.md`
**Beads:** spark_k8s-703
**Status:** Completed
**Total Workstreams:** 4
**Estimated LOC:** ~520

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-031-01 | Workstream completion bot | SMALL (~150 LOC) | - | completed |
| WS-031-02 | ROADMAP auto-update | SMALL (~120 LOC) | - | completed |
| WS-031-03 | Weekly digest generator | SMALL (~150 LOC) | WS-031-01 | completed |
| WS-031-04 | Metrics dashboard | SMALL (~100 LOC) | WS-031-01, WS-031-02 | completed |

### Dependency Graph

```
WS-031-01 (Completion bot) ──┬── WS-031-03 (Weekly digest)
                             └── WS-031-04 (Metrics dashboard)
WS-031-02 (ROADMAP update) ───── WS-031-04 (Metrics dashboard)
```

### Execution Order

1. **Parallel:** WS-031-01 + WS-031-02
2. **Sequential:** WS-031-03 (after WS-031-01)
3. **Sequential:** WS-031-04 (after WS-031-01, WS-031-02)

---

## Feature F23: Project Origins Documentation

**Source:** `docs/drafts/idea-f23-project-origins.md`
**Beads:** spark_k8s-1wf (F21)
**Status:** Completed
**Total Workstreams:** 5
**Estimated LOC:** ~640 (docs)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-032-01 | Write origin story | SMALL (~150 LOC) | - | completed |
| WS-032-02 | Problem deep dive | SMALL (~120 LOC) | WS-032-01 | completed |
| WS-032-03 | Solution philosophy | SMALL (~120 LOC) | WS-032-01 | completed |
| WS-032-04 | Vision and future roadmap | SMALL (~100 LOC) | WS-032-03 | completed |
| WS-032-05 | Bilingual version (RU) | SMALL (~150 LOC) | WS-032-04 | completed |

### Dependency Graph

```
WS-032-01 (Origin story)
    ├── WS-032-02 (Problem deep dive)
    └── WS-032-03 (Solution philosophy)
            └── WS-032-04 (Vision & roadmap)
                    └── WS-032-05 (Bilingual RU)
```

### Execution Order

1. **WS-032-01** — Origin story (first)
2. **Parallel:** WS-032-02 + WS-032-03 (after 01)
3. **Sequential:** WS-032-04 (after 03)
4. **Sequential:** WS-032-05 (after 04)

---

## Feature F24: Pre-built Docker Images

**Source:** `docs/drafts/idea-f24-prebuilt-docker-images.md`
**Beads:** spark_k8s-ds8
**Status:** Completed
**Total Workstreams:** 6
**Estimated LOC:** ~660

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-033-01 | GHCR registry setup | SMALL (~80 LOC) | - | completed |
| WS-033-02 | Build automation for spark-custom | MEDIUM (~150 LOC) | WS-033-01 | completed |
| WS-033-03 | Build automation for jupyter-spark | MEDIUM (~150 LOC) | WS-033-01 | completed |
| WS-033-04 | Multi-arch support | MEDIUM (~120 LOC) | WS-033-02, WS-033-03 | completed |
| WS-033-05 | Version tagging strategy | SMALL (~60 LOC) | - | completed |
| WS-033-06 | Update charts for GHCR images | MEDIUM (~100 LOC) | WS-033-04, WS-033-05 | completed |

### Dependency Graph

```
WS-033-01 (GHCR setup) ──┬── WS-033-02 (spark-custom build)
                         └── WS-033-03 (jupyter-spark build)
                                    │
WS-033-05 (Version tagging) ────────┼── WS-033-04 (Multi-arch)
                                    │           │
                                    └───────────┴── WS-033-06 (Update charts)
```

### Execution Order

1. **Parallel:** WS-033-01 + WS-033-05
2. **Parallel:** WS-033-02 + WS-033-03 (after 01)
3. **Sequential:** WS-033-04 (after 02, 03)
4. **Sequential:** WS-033-06 (after 04, 05)

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
**Status:** Completed
**Total Workstreams:** 7
**Estimated LOC:** ~6500

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-008-01 | Jupyter GPU/Iceberg scenarios (12) | SMALL (~500 LOC) | Phase 0, Phase 1, WS-006-06, WS-006-07 | completed |
| WS-008-02 | Standalone chart baseline scenarios (24) | MEDIUM (~800 LOC) | F01 | completed |
| WS-008-03 | Spark Operator scenarios (32) | MEDIUM (~1200 LOC) | WS-020-12 | completed |
| WS-008-04 | History Server validation scenarios (32) | MEDIUM (~1000 LOC) | WS-012-01 | completed |
| WS-008-05 | MLflow scenarios (24) | MEDIUM (~800 LOC) | WS-001-07 | completed |
| WS-008-06 | Dataset generation utilities | SMALL (~400 LOC) | WS-008-01 | completed |
| WS-008-07 | Parallel execution improvements | SMALL (~600 LOC) | WS-008-02 | completed |

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
**Status:** Completed
**Total Workstreams:** 3
**Estimated LOC:** ~1050

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-009-01 | JDK 17 base layer + test | SMALL (~300 LOC) | None | completed |
| WS-009-02 | Python 3.10 base layer + test | SMALL (~250 LOC) | None | completed |
| WS-009-03 | CUDA 12.1 base layer + test | MEDIUM (~500 LOC) | WS-009-01 | completed |

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
**Status:** Completed
**Total Workstreams:** 4
**Estimated LOC:** ~2500

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-010-01 | Spark core layers (4) + tests | MEDIUM (~800 LOC) | F09 | completed |
| WS-010-02 | Python dependencies layer + test | MEDIUM (~600 LOC) | F09 | completed |
| WS-010-03 | JDBC drivers layer + test | SMALL (~400 LOC) | F09 | completed |
| WS-010-04 | JARs layers (RAPIDS, Iceberg) + tests | MEDIUM (~700 LOC) | F09, WS-010-01 | completed |

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
**Status:** Completed
**Total Workstreams:** 3
**Estimated LOC:** ~3900

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-011-01 | Spark 3.5 images (8) + tests | LARGE (~1200 LOC) | F10 | completed |
| WS-011-02 | Spark 4.1 images (8) + tests | LARGE (~1200 LOC) | F10 | completed |
| WS-011-03 | Jupyter images (12) + tests | LARGE (~1500 LOC) | F10, WS-011-01, WS-011-02 | completed |

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
**Status:** Completed
**Total Workstreams:** 6
**Estimated LOC:** ~4900

| ID | Name | Scenarios | Dependency | Status |
|----|------|-----------|------------|--------|
| WS-012-01 | Core E2E | 24 | F06, F07, F11 | completed |
| WS-012-02 | GPU E2E | 16 | F06, F07, F11 | completed |
| WS-012-03 | Iceberg E2E | 16 | F06, F07, F11 | completed |
| WS-012-04 | GPU+Iceberg E2E | 8 | F06, F07, F11 | completed |
| WS-012-05 | Standalone E2E | 8 | F06, F07 | completed |
| WS-012-06 | Library compatibility | 8 | F06, F07 | completed |

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
**Status:** Completed
**Total Workstreams:** 5
**Estimated LOC:** ~3000

> **Note:** Canonical implementation is `spark_k8s-47g`. Earlier `spark_k8s-aaq` (CLOSED) used different WS structure (CPU/memory scaling, concurrent, failure) and is superseded by this implementation.

| ID | Name | Scenarios | Dependency | Status |
|----|------|-----------|------------|--------|
| WS-013-01 | Baseline load | 4 | F06, F12 | completed |
| WS-013-02 | GPU load | 4 | F06, F12 | completed |
| WS-013-03 | Iceberg load | 4 | F06, F12 | completed |
| WS-013-04 | Comparison load | 4 | F06, F12 | completed |
| WS-013-05 | Security stability | 4 | F06, F07 | completed |

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
**Status:** Completed
**Total Workstreams:** 7
**Actual LOC:** ~3200
**Total Scenarios:** 48

| ID | Name | Scenarios | Dependency | Status |
|----|------|-----------|------------|--------|
| WS-014-01 | PSS tests | 8 | F06, F07 | completed |
| WS-014-02 | SCC tests | 12 | F06, F07 | completed |
| WS-014-03 | Network policies | 6 | F06, F07 | completed |
| WS-014-04 | RBAC tests | 6 | F06, F07 | completed |
| WS-014-05 | Secret management | 6 | F06, F07 | completed |
| WS-014-06 | Container security | 8 | F06, F07 | completed |
| WS-014-07 | S3 security | 6 | F06, F07 | completed |

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

### Review Summary

**Review Date:** 2026-02-13 (re-review)
**Verdict:** ✅ APPROVED
**Previous:** 2026-02-10 CHANGES_REQUESTED (blockers fixed: rlk, bch)

**Results:** 118 passed, 14 skipped. Coverage 81.91%. All quality gates pass.

See `docs/reports/review-F14-full-2026-02-13.md`. UAT guide: `docs/uat/UAT-F14-security.md`.

---

## Feature F15: Phase 9 — Parallel Execution & CI/CD

**Source:** `docs/phases/phase-09-parallel.md`
**Status:** Completed
**Bead:** spark_k8s-dyz CLOSED
**Total Workstreams:** 3
**Estimated LOC:** ~2100

| ID | Name | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-015-01 | Parallel execution framework | MEDIUM (~800 LOC) | F06, F08, F12, F13 | completed |
| WS-015-02 | Result aggregation | MEDIUM (~600 LOC) | WS-015-01 | completed |
| WS-015-03 | CI/CD integration | MEDIUM (~700 LOC) | WS-015-02 | completed |

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

### Review Summary

**Review Date:** 2026-02-13 (re-review)
**Verdict:** ✅ APPROVED (confirmed)
**Previous:** 2026-02-10 APPROVED

**All deliverables verified.** All blockers remain CLOSED.

See `docs/reports/review-F15-full-2026-02-13.md`. UAT guide: `docs/uat/UAT-F15-parallel.md`.

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

### Review Summary

**Review Date:** 2026-02-10
**Verdict:** ✅ APPROVED
**Status:** 50 passed, 16 skipped. All blockers (74z.8, k5r, 2qk, 31l, 74z.9, 74z.10) CLOSED.

See `docs/reports/review-F16-full-2026-02-10.md`. UAT guide: `docs/uat/UAT-F16-observability.md`.

---

## Feature F17: Spark Connect Go Client

**Source:** `docs/drafts/feature-spark-connect-go.md`
**Status:** Completed
**Total Workstreams:** 4
**Actual LOC:** ~1701 (25 files, all <200)

| ID | Name | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-017-01 | Spark Connect Go client library | MEDIUM | F06, F11 | completed |
| WS-017-02 | Go smoke tests | MEDIUM | WS-017-01 | completed |
| WS-017-03 | Go E2E tests | MEDIUM | WS-017-01 | completed |
| WS-017-04 | Go load tests | MEDIUM | WS-017-01 | completed |

### Dependency Graph

```
F06, F11 ──── WS-017-01 (Go client library)
                │
                ├── WS-017-02 (Go smoke tests)
                ├── WS-017-03 (Go E2E tests)
                └── WS-017-04 (Go load tests)
```

### Review Summary

**Review Date:** 2026-02-10
**Verdict:** ✅ APPROVED
**Beads:** ecz, 85e, bok, cqy.6 — all CLOSED.

See `docs/reports/review-F17-full-2026-02-10.md`. UAT guide: `docs/uat/UAT-F17-go-client.md`.

---

## Feature F18: Production Operations Suite

**Source:** `docs/drafts/feature-production-operations.md`
**Status:** In Progress
**Total Workstreams:** 17+
**Bead:** spark_k8s-d5e

| ID | Name | Status |
|----|------|--------|
| WS-018-01 | Incident Response Framework | closed |
| WS-018-02 | Spark Application Failure Runbooks | completed |
| WS-018-03 | Data Layer Recovery Runbooks | completed |
| WS-018-04..17 | SLO, Scaling, Runbooks, etc. | open |

### Review Summary

**Review Date:** 2026-02-10
**Verdict:** ✅ APPROVED
**Fixed (beads):** yck, 117, 7xp, 6ki — CLOSED. **Nedodelki:** d5e.20 (coverage ≥80%). d5e.21 (ops-scripts-assessment) — CLOSED.

See `docs/reports/review-F18-full-2026-02-10.md`. UAT guide: `docs/uat/UAT-F18-operations.md`.

---

## Feature F25: Spark 3.5 Charts Production-Ready

**Source:** `docs/drafts/idea-spark-35-production-ready.md`
**Status:** Backlog
**Total Workstreams:** 9
**Estimated LOC:** ~2000
**Bead:** spark_k8s-ju2

| ID | Name | Scope | Dependency | Status | Bead |
|----|------|-------|------------|--------|------|
| WS-025-01 | Fix chart metadata + values.yaml | SMALL (~150 LOC) | - | completed | spark_k8s-r6h |
| WS-025-02 | Spark Standalone deployment template | MEDIUM (~300 LOC) | - | completed | spark_k8s-3ip |
| WS-025-03 | Prometheus metrics exporter config | SMALL (~100 LOC) | WS-025-01 | completed | spark_k8s-ngl |
| WS-025-04 | Monitoring templates (SM+PM+Grafana) | MEDIUM (~500 LOC) | WS-025-03 | completed | spark_k8s-pqx |
| WS-025-05 | OpenShift Route template | SMALL (~150 LOC) | - | completed | spark_k8s-2zy |
| WS-025-06 | Fix 8 scenario values files | MEDIUM (~400 LOC) | WS-025-01, WS-025-02 | completed | spark_k8s-ni8 |
| WS-025-07 | Update OpenShift presets | SMALL (~100 LOC) | WS-025-04, WS-025-05 | completed | spark_k8s-r51 |
| WS-025-08 | Fix spark-connect-configmap | SMALL (~50 LOC) | WS-025-01 | completed | spark_k8s-og4 |
| WS-025-09 | Helm validation + smoke tests | MEDIUM (~300 LOC) | WS-025-06..08 | completed | spark_k8s-2if |
| WS-025-10 | Minikube integration tests | MEDIUM (~400 LOC) | WS-025-09 | completed | spark_k8s-6q1 |
| WS-025-11 | Load tests 10GB NYC Taxi | LARGE (~600 LOC) | WS-025-10, WS-025-12 | backlog | spark_k8s-got |
| WS-025-12 | Tracing + profiling dashboards/recipes | LARGE (~800 LOC) | WS-025-03, WS-025-04 | backlog | spark_k8s-znp |

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
                              │
          WS-025-03 + WS-025-04
                │
          WS-025-12 (Tracing + profiling dashboards/recipes)
                │
          WS-025-10 ──────────┤
          (Minikube tests)    │
                        WS-025-11 (Load tests 10GB NYC Taxi)
```

### Parallel Execution Paths

**Phase 1 (parallel):** WS-025-01 + WS-025-02 + WS-025-05
**Phase 2 (after 01):** WS-025-03, WS-025-08
**Phase 3 (after 03):** WS-025-04
**Phase 4 (after 01+02):** WS-025-06
**Phase 5 (after 04+05):** WS-025-07
**Phase 6 (after 06+07+08):** WS-025-09
**Phase 7 (after 09):** WS-025-10 (minikube integration tests)
**Phase 3b (after 03+04):** WS-025-12 (tracing + profiling dashboards/recipes)
**Phase 8 (after 10+12):** WS-025-11 (load tests 10GB NYC Taxi + Grafana validation)

### Review Summary

**Review Date:** 2026-02-10
**Verdict:** ✅ APPROVED (WS-025-01..10)
**Fixed (beads):** ju2.5 — budget.enabled nil; y0m — loc exemption; pb8, 2f9 deliverables exist. **Parity test:** spark-4.1 costExporter (ds8.7).

See `docs/reports/review-F25-full-2026-02-10.md`. UAT guide: `docs/uat/UAT-F25-spark-35-charts.md`.

---

## Feature F26: Spark Performance Defaults

**Source:** `docs/drafts/idea-spark-performance-defaults.md`
**Status:** Completed
**Total Workstreams:** 3
**Estimated LOC:** ~400
**Audit source:** repo-audit-2026-02-13.md (Spark Practices SP-1..SP-8)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-026-01 | Enable AQE and Modern Spark Defaults | SMALL (~150 LOC) | - | completed |
| WS-026-02 | Fix Deprecated Spark 4.x Properties | SMALL (~100 LOC) | - | completed |
| WS-026-03 | Structured Streaming Example (Kafka → Iceberg) | MEDIUM (~150 LOC) | WS-026-01 | completed |

### Dependency Graph

```
WS-026-01 (AQE + defaults) ──── WS-026-03 (Streaming example)
WS-026-02 (Fix deprecated)      (independent)
```

### Audit Cross-Reference

| Audit ID | Description | WS |
|----------|-------------|-----|
| SP-1 | No AQE in defaults (+20-40% perf) | WS-026-01 |
| SP-2 | spark.blacklist deprecated in 4.x | WS-026-02 |
| SP-4 | Hardcoded shuffle.partitions=200 | WS-026-01 |
| SP-5 | No KryoSerializer | WS-026-01 |
| SP-6 | No zstd parquet compression | WS-026-01 |
| SP-7 | No podNamePrefix | WS-026-01 |
| SP-8 | No Structured Streaming example | WS-026-03 |

---

## Feature F27: Code Quality A*

**Source:** `docs/drafts/idea-code-quality-astar.md`
**Status:** Backlog
**Total Workstreams:** 3
**Estimated LOC:** ~600 (config + refactoring)
**Audit source:** repo-audit-2026-02-13.md (Code Quality CQ-1..CQ-6)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-027-01 | Create pyproject.toml and Enforce Coverage | SMALL (~100 LOC) | - | backlog |
| WS-027-02 | Split Oversized Test Files (13 files > 200 LOC) | MEDIUM (~300 LOC refactor) | WS-027-01 | backlog |
| WS-027-03 | Split Oversized Scripts + Add Pre-commit | SMALL (~200 LOC refactor) | WS-027-01 | backlog |

### Dependency Graph

```
WS-027-01 (pyproject.toml + coverage)
    ├── WS-027-02 (Split test files)
    └── WS-027-03 (Split scripts + pre-commit)
```

### Audit Cross-Reference

| Audit ID | Description | WS |
|----------|-------------|-----|
| CQ-1 | 13 test files > 200 LOC | WS-027-02 |
| CQ-2 | 3 Python scripts > 200 LOC | WS-027-03 |
| CQ-3 | No unified linter config | WS-027-01 |
| CQ-4 | No requirements.txt / pyproject.toml | WS-027-01 |
| CQ-5 | Coverage not enforced | WS-027-01 |
| CQ-6 | No pre-commit hooks | WS-027-03 |

---

## Feature F28: Chart Architecture DRY

**Source:** `docs/drafts/idea-chart-architecture-dry.md`
**Status:** In Progress (WS-028-01, WS-028-03 completed)
**Total Workstreams:** 3
**Estimated LOC:** ~800 (refactoring)
**Audit source:** repo-audit-2026-02-13.md (Architecture AR-1..AR-7)
**Oneshot report:** `docs/reports/oneshot-F028-2026-02-13.md`

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-028-01 | Unify Values Layout + Extract to spark-base | LARGE (~400 LOC refactor) | - | **completed** |
| WS-028-02 | Consolidate RBAC + Remove Legacy Hive Duplicates | MEDIUM (~200 LOC) | WS-028-01 | backlog (redesigned) |
| WS-028-03 | Add values.schema.json and Helm Test Templates | MEDIUM (~300 LOC) | - | **completed** |

### Dependency Graph

```
WS-028-01 (Unify values + extract)
    └── WS-028-02 (Consolidate RBAC + remove legacy)

WS-028-03 (Schema + Helm tests) ── DONE
```

### Oneshot Agent Findings (2026-02-13)

Agent correctly identified WS-028-01 and WS-028-02 could not be executed as originally designed:

1. **WS-028-01:** Values layout differs between charts (`core.postgresql` in 3.5/4.1 vs `postgresql` in spark-base). **Resolution:** Redesigned to include ADR + values unification before template extraction.

2. **WS-028-02:** "Duplicates" serve different purposes:
   - `rbac.yaml` (82 LOC) = Role + RoleBinding + ClusterRole + ClusterRoleBinding (comprehensive)
   - `rbac/role.yaml` (35 LOC) = Role only (minimal) — **NOT a duplicate, needs merge**
   - `keda-scaledobject.yaml` = Spark Operator target; `autoscaling/keda-scaledobject.yaml` = Connect S3 target — **different features**
   - `hive-metastore.yaml` (`.Values.hiveMetastore`) = legacy; `core/hive-metastore-deployment.yaml` (`.Values.core.hiveMetastore`) = new — **needs values unification first**

   **Resolution:** Redesigned as consolidation (merge RBAC, remove legacy hive after values unification, rename KEDA for clarity).

3. **WS-028-03:** Completed successfully — `values.schema.json` and Helm test templates verified.

### Audit Cross-Reference

| Audit ID | Description | WS | Status |
|----------|-------------|-----|--------|
| AR-1 | Template duplication between 3.5 and 4.1 | WS-028-01 | redesigned |
| AR-2 | values.yaml > 460 LOC (monolithic) | WS-028-03 | **done** (schema validates) |
| AR-3 | Duplicate hive-metastore templates | WS-028-02 | redesigned |
| AR-4 | Duplicate RBAC (rbac.yaml + rbac/) | WS-028-02 | redesigned |
| AR-5 | Duplicate KEDA (keda + autoscaling/) | WS-028-02 | redesigned (rename) |
| AR-6 | No Helm chart tests | WS-028-03 | **done** |
| AR-7 | No values.schema.json | WS-028-03 | **done** |

---

## Feature F29: CI/CD Hardening

**Source:** `docs/drafts/idea-cicd-hardening.md`
**Status:** Backlog
**Total Workstreams:** 4
**Estimated LOC:** ~500
**Audit source:** repo-audit-2026-02-13.md (DevOps DO-1..DO-10)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-029-01 | Fix CI/CD Bugs and Modernize Actions | SMALL (~100 LOC) | - | backlog |
| WS-029-02 | Add Dependabot, CODEOWNERS, .dockerignore | SMALL (~100 LOC) | WS-029-01 | backlog |
| WS-029-03 | Chart Release Pipeline (OCI Registry) | MEDIUM (~200 LOC) | WS-029-01 | backlog |
| WS-029-04 | Harden Default Credentials in Values Files | SMALL (~100 LOC) | - | backlog |

### Dependency Graph

```
WS-029-01 (Fix CI bugs) ──┬── WS-029-02 (Dependabot + CODEOWNERS)
                           └── WS-029-03 (Chart release pipeline)
WS-029-04 (Harden credentials)    (independent, CRITICAL priority)
```

### Audit Cross-Reference

| Audit ID | Description | WS | Priority |
|----------|-------------|-----|----------|
| DO-1 | Hardcoded minioadmin in 49+ files | WS-029-04 | **CRITICAL** |
| DO-2 | security-scan.yml typo ubuntu-litted | WS-029-01 | High |
| DO-3 | security-scan.yml sarif mismatch | WS-029-01 | High |
| DO-4 | No chart release pipeline | WS-029-03 | Medium |
| DO-5 | No image pinning (SHA digest) | WS-029-02 | Medium |
| DO-6 | No .dockerignore | WS-029-02 | Medium |
| DO-8 | Outdated actions/checkout@v3 | WS-029-01 | Low |
| DO-9 | No Dependabot/Renovate | WS-029-02 | Medium |
| DO-10 | No CODEOWNERS | WS-029-02 | Low |

---

## Feature F30: Data Engineering Patterns

**Source:** `docs/drafts/idea-data-engineering-patterns.md`
**Status:** Backlog
**Total Workstreams:** 4
**Estimated LOC:** ~1200
**Audit source:** repo-audit-2026-02-13.md (Data Engineering DE-1..DE-8)

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-030-01 | OpenLineage Integration Preset | MEDIUM (~300 LOC) | - | backlog |
| WS-030-02 | Production Airflow DAG Templates | MEDIUM (~300 LOC) | - | backlog |
| WS-030-03 | Iceberg Best Practices Guide | MEDIUM (~400 LOC) | - | backlog |
| WS-030-04 | Integrate Observability as Chart Dependency | MEDIUM (~200 LOC) | WS-030-01 | backlog |

### Dependency Graph

```
WS-030-01 (OpenLineage) ──── WS-030-04 (Observability integration)
WS-030-02 (Airflow DAGs)     (independent)
WS-030-03 (Iceberg guide)    (independent)
```

### Audit Cross-Reference

| Audit ID | Description | WS |
|----------|-------------|-----|
| DE-1 | No data lineage (OpenLineage) | WS-030-01 |
| DE-2 | No schema registry | Future (out of scope) |
| DE-3 | No data quality framework examples | WS-030-02 (DQ DAG) |
| DE-4 | No production ETL pipeline examples | WS-030-02 |
| DE-6 | No Iceberg partitioning strategy docs | WS-030-03 |
| DE-7 | Airflow DAGs are examples only | WS-030-02 |
| DE-8 | Observability charts not integrated | WS-030-04 |

---

## Audit → Feature Cross-Reference Map

**Source:** `docs/reports/repo-audit-2026-02-13.md`

| Audit Aspect | Grade | Existing Features | New Features | Gap Coverage |
|-------------|-------|-------------------|--------------|--------------|
| Code Quality (B+) | CQ-1..CQ-6 | — | **F27** (3 WS) | 100% |
| Architecture (B) | AR-1..AR-7 | F04 (backlog) | **F28** (3 WS) | 100% |
| DevOps (B+) | DO-1..DO-10 | F15, F16 | **F29** (4 WS) | 100% |
| Spark Practices (A-) | SP-1..SP-8 | F25 (WS-025-11, WS-025-12) | **F26** (3 WS) | 100% |
| Data Engineering (B) | DE-1..DE-8 | F16, F18 | **F30** (4 WS) | 87% (DE-2 deferred) |

### Existing Backlog Augmentation

| Existing WS | Audit Items Absorbed | Notes |
|-------------|---------------------|-------|
| F16 WS-016-01..06 | DE-8 partially | Observability stack exists; F30 WS-030-04 integrates it |
| F18 WS-018-02..03 | — | Already covers ops runbooks |
| F25 WS-025-11 | — | Load tests remain as-is |
| F25 WS-025-12 | SP-1 partially | Tracing + profiling; AQE defaults in F26 |
| F04 WS-020-* | AR-1 partially | 4.1 chart refactoring; F28 handles DRY extraction |

---

## Execution Priority (Waves)

### Wave 1 — Critical & Quick Wins (F26 + F29 partial)

| WS | Feature | Effort | Impact |
|----|---------|--------|--------|
| **WS-029-04** | F29: Harden credentials | SMALL | **CRITICAL security** |
| **WS-029-01** | F29: Fix CI bugs | SMALL | CI reliability |
| **WS-026-01** | F26: AQE + modern defaults | SMALL | +20-40% performance |
| **WS-026-02** | F26: Fix deprecated props | SMALL | Forward compat |

### Wave 2 — Foundation (F27 + F28 partial)

| WS | Feature | Effort | Impact |
|----|---------|--------|--------|
| **WS-027-01** | F27: pyproject.toml + coverage | SMALL | Quality foundation |
| **WS-028-02** | F28: Remove duplicates | SMALL | Clean templates |
| **WS-027-02** | F27: Split test files | MEDIUM | Quality gate |
| **WS-027-03** | F27: Split scripts + pre-commit | SMALL | DX |

### Wave 3 — Structural (F28 + F29 rest)

| WS | Feature | Effort | Impact |
|----|---------|--------|--------|
| **WS-028-01** | F28: Extract to spark-base | LARGE | DRY architecture |
| **WS-028-03** | F28: Schema + Helm tests | MEDIUM | Validation UX |
| **WS-029-02** | F29: Dependabot + CODEOWNERS | SMALL | Maintenance |
| **WS-029-03** | F29: Chart release (OCI) | MEDIUM | Release maturity |

### Wave 4 — Feature Completeness (F26 rest + F30)

| WS | Feature | Effort | Impact |
|----|---------|--------|--------|
| **WS-026-03** | F26: Streaming example | MEDIUM | Use case coverage |
| **WS-030-01** | F30: OpenLineage | MEDIUM | Lineage visibility |
| **WS-030-02** | F30: Production DAGs | MEDIUM | Production patterns |
| **WS-030-03** | F30: Iceberg guide | MEDIUM | Knowledge |
| **WS-030-04** | F30: Observability integration | MEDIUM | Single install |

---

## Summary

| Feature | Total WS | Completed | In Progress | Backlog |
|---------|----------|-----------|-------------|---------|
| F01: Spark Standalone | 12 | 12 | 0 | 0 |
| F02: Repo Documentation | 4 | 4 | 0 | 0 |
| F03: History Server (SA) | 2 | 2 | 0 | 0 |
| F04: Spark 4.1.0 Charts | 24 | 0 | 0 | 24 |
| F05: Docs Refresh (Airflow vars) | 2 | 2 | 0 | 0 |
| F06: Core Components + Presets | 10 | 10 | 0 | 0 |
| F07: Critical Security + Chart Updates | 4 | 4 | 0 | 0 |
| F22: Progress Automation | 4 | 4 | 0 | 0 |
| F23: Project Origins Documentation | 5 | 5 | 0 | 0 |
| F24: Pre-built Docker Images | 6 | 6 | 0 | 0 |
| F08: Phase 2 — Smoke Tests | 7 | 7 | 0 | 0 |
| F09: Phase 3 — Docker Base Layers | 3 | 3 | 0 | 0 |
| F10: Phase 4 — Docker Intermediate Layers | 4 | 4 | 0 | 0 |
| F11: Phase 5 — Docker Final Images | 3 | 3 | 0 | 0 |
| F12: Phase 6 — E2E Tests | 6 | 6 | 0 | 0 |
| F13: Phase 7 — Load Tests | 5 | 5 | 0 | 0 |
| F14: Phase 8 — Advanced Security | 7 | 7 | 0 | 0 |
| F15: Phase 9 — Parallel Execution & CI/CD | 3 | 3 | 0 | 0 |
| F16: Observability Stack | 6 | 0 | 0 | 6 |
| F17: Spark Connect Go Client | 4 | 4 | 0 | 0 |
| F18: Production Operations Suite | 17+ | 2 | 0 | 15+ |
| F25: Spark 3.5 Production-Ready | 12 | 10 | 0 | 2 |
| **F26: Spark Performance Defaults** | **3** | **3** | **0** | **0** |
| **F27: Code Quality A*** | **3** | **0** | **0** | **3** |
| **F28: Chart Architecture DRY** | **3** | **1** | **0** | **2** |
| **F29: CI/CD Hardening** | **4** | **0** | **0** | **4** |
| **F30: Data Engineering Patterns** | **4** | **0** | **0** | **4** |
| TESTING: Testing Infrastructure | 3+ | 0 | 0 | 3+ |
| **TOTAL** | **138+** | **87** | **0** | **101+** |

---

*Last updated: 2026-02-13*
