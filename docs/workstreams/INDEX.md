# Workstreams Index

## Feature F00: Helm Charts Update (Phase 0)

**Source:** `docs/phases/phase-00-helm-charts.md`
**Status:** Backlog
**Total Workstreams:** 10
**Estimated LOC:** ~4400

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-000-01 | Chart template structure design | SMALL (~300 LOC) | Independent | backlog |
| WS-000-02 | GPU templates implementation | MEDIUM (~600 LOC) | WS-000-01 | backlog |
| WS-000-03 | Iceberg templates implementation | MEDIUM (~600 LOC) | WS-000-01 | backlog |
| WS-000-04 | Connect templates for Spark 3.5 | MEDIUM (~500 LOC) | WS-000-01, WS-000-02, WS-000-03 | backlog |
| WS-000-05 | Baseline presets creation | MEDIUM (~400 LOC) | WS-000-01 | backlog |
| WS-000-06 | GPU presets creation | MEDIUM (~450 LOC) | WS-000-01, WS-000-02 | backlog |
| WS-000-07 | Iceberg presets creation | MEDIUM (~450 LOC) | WS-000-01, WS-000-03 | backlog |
| WS-000-08 | GPU+Iceberg combo presets | MEDIUM (~450 LOC) | WS-000-01, WS-000-02, WS-000-03, WS-000-06, WS-000-07 | backlog |
| WS-000-09 | Spark 3.5 chart documentation | MEDIUM (~600 LOC) | WS-000-05, WS-000-06, WS-000-07, WS-000-08 | backlog |
| WS-000-10 | Spark 4.1 chart documentation | MEDIUM (~650 LOC) | WS-000-05, WS-000-06, WS-000-07, WS-000-08, WS-000-09 | backlog |

### Dependency Graph

```
WS-000-01 (Template Structure Design)
    ├── WS-000-02 (GPU Templates) ────┐
    ├── WS-000-03 (Iceberg Templates) ├──┤
    └── WS-000-04 (Connect 3.5) ──────┘
    │
    ├── WS-000-05 (Baseline Presets)
    ├── WS-000-06 (GPU Presets) ────────┬── WS-000-08 (Combo Presets) ──┬── WS-000-09 (3.5 Docs)
    └── WS-000-07 (Iceberg Presets) ────┘                              └── WS-000-10 (4.1 Docs)
```

### Parallel Execution Paths

**Phase 1: Foundation**
- WS-000-01 (Template structure design) - MUST BE FIRST

**Phase 2: Templates (parallel)**
- WS-000-02 (GPU templates)
- WS-000-03 (Iceberg templates)
- WS-000-04 (Connect 3.5 - depends on WS-000-02 and WS-000-03)

**Phase 3: Presets (parallel)**
- WS-000-05 (Baseline - depends on WS-000-01)
- WS-000-06 (GPU - depends on WS-000-02)
- WS-000-07 (Iceberg - depends on WS-000-03)

**Phase 4: Combo + Docs**
- WS-000-08 (Combo presets - depends on WS-000-06 and WS-000-07)
- WS-000-09 (3.5 docs - depends on all presets)
- WS-000-10 (4.1 docs - depends on WS-000-09)

### Execution Order

1. **WS-000-01** - Design template structure
2. **Parallel:** WS-000-02, WS-000-03
3. **WS-000-04** (after WS-000-02, WS-000-03)
4. **Parallel:** WS-000-05, WS-000-06, WS-000-07
5. **WS-000-08** (after WS-000-06, WS-000-07)
6. **WS-000-09** (after WS-000-05 through WS-000-08)
7. **WS-000-10** (after WS-000-09)

---

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

## Feature F06: Critical Security + Chart Updates (Phase 1)

**Source:** `docs/phases/phase-01-security.md`
**Status:** Backlog
**Total Workstreams:** 4
**Estimated LOC:** ~1350

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-100-01 | Namespace.yaml с PSS Labels | SMALL (~180 LOC) | - | backlog |
| WS-100-02 | Enable podSecurityStandards by Default | SMALL (~120 LOC) | WS-100-01 | backlog |
| WS-100-03 | OpenShift Presets | MEDIUM (~450 LOC) | WS-100-01 | backlog |
| WS-100-04 | PSS/SCC Smoke Tests | MEDIUM (~600 LOC) | WS-100-02, WS-100-03 | backlog |

### Dependency Graph

```
WS-100-01 (namespace.yaml)
    ├── WS-100-02 (podSecurityStandards: true)
    └── WS-100-03 (OpenShift presets)
            └── WS-100-04 (Smoke tests)
```

### Parallel Execution Paths

1. **WS-100-01** - Create namespace.yaml templates (MUST BE FIRST)
2. **Parallel:** WS-100-02, WS-100-03 (can run in parallel after WS-100-01)
3. **WS-100-04** (after WS-100-02, WS-100-03)

### Execution Order

1. **WS-100-01** - Create namespace.yaml templates for both charts
2. **Parallel:** WS-100-02 (enable podSecurityStandards), WS-100-03 (OpenShift presets)
3. **WS-100-04** (after security defaults and presets are ready)

---

## Feature F07: Complete Smoke Tests (Phase 2)

**Source:** `docs/phases/phase-02-smoke.md`
**Status:** Backlog
**Total Workstreams:** 5
**Estimated LOC:** ~3900

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-002-01 | Baseline scenarios (25) | MEDIUM (~800 LOC) | Phase 0, Phase 1 | backlog |
| WS-002-02 | Connect for Spark 3.5 (18) | MEDIUM (~600 LOC) | Phase 0, Phase 1 | backlog |
| WS-002-03 | GPU scenarios (36) | MEDIUM (~900 LOC) | Phase 0, Phase 5 | backlog |
| WS-002-04 | Iceberg scenarios (36) | MEDIUM (~900 LOC) | Phase 0, Phase 5 | backlog |
| WS-002-05 | GPU+Iceberg combo (24) | MEDIUM (~700 LOC) | Phase 0, Phase 5 | backlog |

### Dependency Graph

```
Phase 0, Phase 1
    ↓
WS-002-01 (Baseline) ────────┐
WS-002-02 (Connect 3.5) ──────┤
    ↓                         ├─ Can start WITHOUT Phase 5
Phase 5 (Docker Final) ────────┘
    ↓
WS-002-03 (GPU) ─────────────┐
WS-002-04 (Iceberg) ──────────┤
WS-002-05 (GPU+Iceberg) ───────┘
```

---

## Feature F08: Docker Base Layers (Phase 3)

**Source:** `docs/phases/phase-03-docker-base.md`
**Status:** Backlog
**Total Workstreams:** 3
**Estimated LOC:** ~1050

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-003-01 | JDK 17 base layer + test | SMALL (~300 LOC) | - | backlog |
| WS-003-02 | Python 3.10 base layer + test | SMALL (~250 LOC) | - | backlog |
| WS-003-03 | CUDA 12.1 base layer + test | MEDIUM (~500 LOC) | - | backlog |

### Dependency Graph

```
WS-003-01 (JDK 17) ─── INDEPENDENT
WS-003-02 (Python 3.10) ─── INDEPENDENT
WS-003-03 (CUDA 12.1) ─── INDEPENDENT
```

**Note:** Phase 3 может быть параллелен с Phase 0, Phase 1, Phase 2

---

## Feature F09: Docker Intermediate Layers (Phase 4)

**Source:** `docs/phases/phase-04-docker-intermediate.md`
**Status:** Backlog
**Total Workstreams:** 4
**Estimated LOC:** ~2500

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-004-01 | Spark core layers (4) + tests | MEDIUM (~800 LOC) | Phase 3 | backlog |
| WS-004-02 | Python dependencies layer + test | MEDIUM (~600 LOC) | Phase 3 | backlog |
| WS-004-03 | JDBC drivers layer + test | SMALL (~400 LOC) | Phase 3 | backlog |
| WS-004-04 | JARs layers (RAPIDS, Iceberg) + tests | MEDIUM (~700 LOC) | Phase 3 | backlog |

### Dependency Graph

```
Phase 3 (Base Layers)
    ↓
WS-004-01 (Spark Core × 4 versions) ───┐
WS-004-02 (Python Dependencies) ────────┤
WS-004-03 (JDBC Drivers) ───────────────┼─── Phase 5 (Final Images)
WS-004-04 (JARs: RAPIDS, Iceberg) ──────┘
```

### Parallel Execution Paths

1. **Phase 3 (Base)** - JDK 17, Python 3.10, CUDA 12.1 (parallel)
2. **Phase 4 (Intermediate)** - Spark Core × 4 (parallel), Python deps, JDBC, JARs (parallel)
3. **Phase 5 (Final)** - зависит от Phase 4

### Execution Order

1. **Phase 3:** WS-003-01, WS-003-02, WS-003-03 (parallel)
2. **Phase 4:** WS-004-01, WS-004-02, WS-004-03, WS-004-04 (parallel after Phase 3)
3. **Phase 5:** WS-005-01, WS-005-02, WS-005-03 (parallel after Phase 4)

---

## Feature F10: Docker Final Images (Phase 5)

**Source:** `docs/phases/phase-05-docker-final.md`
**Status:** Backlog
**Total Workstreams:** 3
**Estimated LOC:** ~3900

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-005-01 | Spark 3.5 images (8) + tests | LARGE (~1200 LOC) | Phase 4 | backlog |
| WS-005-02 | Spark 4.1 images (8) + tests | LARGE (~1200 LOC) | Phase 4 | backlog |
| WS-005-03 | Jupyter images (12) + tests | LARGE (~1500 LOC) | Phase 5 (Spark) | backlog |

### Dependency Graph

```
Phase 4 (Intermediate Layers)
    ↓
Phase 5 (Final Images)
    ├─ WS-005-01 (Spark 3.5 × 4 variants) ───┐
    ├─ WS-005-02 (Spark 4.1 × 4 variants) ────┼── 28 final images
    └─ WS-005-03 (Jupyter × 12 variants) ─────┘
```

### Parallel Execution Paths

1. **Phase 4 (Intermediate)** - все слои параллельно
2. **Phase 5 (Final)** - WS-005-01, WS-005-02 параллельно; WS-005-03 зависит от Spark images

### Execution Order

1. **Phase 4:** WS-004-01, WS-004-02, WS-004-03, WS-004-04 (parallel)
2. **Phase 5:** WS-005-01, WS-005-02 (parallel after Phase 4)
3. **WS-005-03** (after WS-005-01, WS-005-02 - Jupyter depends on Spark base images)

### Image Variants

**Variants:**
- baseline - без GPU, без Iceberg
- gpu - NVIDIA RAPIDS + CUDA
- iceberg - Apache Iceberg support
- gpu-iceberg - GPU + Iceberg combo

**Final Images:**
- Spark 3.5.7: 4 variants
- Spark 3.5.8: 4 variants
- Spark 4.1.0: 4 variants
- Spark 4.1.1: 4 variants
- Jupyter 3.5.7: 4 variants
- Jupyter 3.5.8: 4 variants
- Jupyter 4.1.0: 4 variants

**Total:** 28 final images

---

## Feature F11: Advanced Security (Phase 8)

**Source:** `docs/phases/phase-08-security.md`
**Status:** Backlog
**Total Workstreams:** 7
**Estimated LOC:** ~4200

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-008-01 | PSS tests (8 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 1 | backlog |
| WS-008-02 | SCC tests (12 scenarios) | MEDIUM (~900 LOC) | Phase 0, Phase 1 | backlog |
| WS-008-03 | Network policies (6 scenarios) | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-008-04 | RBAC tests (6 scenarios) | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-008-05 | Secret management (6 scenarios) | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-008-06 | Container security (8 scenarios) | MEDIUM (~700 LOC) | Phase 0, Phase 1 | backlog |
| WS-008-07 | S3 security (6 scenarios) | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |

### Dependency Graph

```
Phase 0, Phase 1
    ↓
WS-008-01 (PSS Tests) ──────────────┐
WS-008-02 (SCC Tests) ───────────────┤
WS-008-03 (Network Policies) ────────┤
WS-008-04 (RBAC Tests) ──────────────┼── All independent
WS-008-05 (Secret Management) ───────┤   (can run in parallel)
WS-008-06 (Container Security) ──────┤
WS-008-07 (S3 Security) ─────────────┘
```

### Parallel Execution Paths

All 7 workstreams are independent and can run in parallel after Phase 0 and Phase 1 are complete.

### Test Structure

```
tests/security/phase08/
├── conftest.py                    # Shared fixtures
├── __init__.py
├── test_08_01_pss.py              # 8 PSS scenarios
├── test_08_02_scc.py              # 12 SCC scenarios (mocked oc)
├── test_08_03_network_policies.py # 6 Network Policy scenarios
├── test_08_04_rbac.py             # 6 RBAC scenarios
├── test_08_05_secrets.py          # 6 Secret scenarios (K8s native only)
├── test_08_06_container_security.py # 8 Container Security scenarios
└── test_08_07_s3_security.py      # 6 S3 Security scenarios
```

### Scenarios Breakdown

**WS-008-01: PSS Tests (8)**
1. PSS restricted — spark-connect pod compliant
2. PSS restricted — spark-worker pod compliant
3. PSS restricted — jupyter pod compliant
4. PSS restricted — hive-metastore pod compliant
5. PSS baseline — spark-connect pod compliant
6. PSS privileged — NOT allowed in prod preset
7. PSS labels — namespace enforce=restricted
8. PSS labels — namespace audit=restricted

**WS-008-02: SCC Tests (12)**
1. SCC restricted — spark-connect with UID 185
2. SCC restricted — spark-worker with UID 185
3. SCC anyuid — spark-connect with any UID
4. SCC nonroot — spark-connect with non-root
5. SCC restricted-v2 — OpenShift 4.11+ compatibility
6. SCC uid ranges — 1000-2000 for spark
7. SCC fsGroup — shared volume permissions
8. SCC seccomp — default profile
9. SCC capabilities — drop ALL
10. SCC no privileged — containers NOT privileged
11. SCC runAsUser — enforced in pod spec
12. SCC SELinux — MCS label validation

**WS-008-03: Network Policies (6)**
1. Default-deny — blocks all ingress/egress
2. Spark-connect ingress — allows port 15002
3. DNS egress — allows UDP:53
4. S3 egress — allows TCP:9000
5. Cross-namespace — blocks unauthorized ns access
6. Worker communication — allows spark-connect ↔ worker

**WS-008-04: RBAC Tests (6)**
1. Role exists — spark-connect role created
2. Least privilege — only required verbs
3. No wildcard — "*" NOT in permissions
4. Secret access — only s3-credentials secret
5. ServiceAccount — created and used
6. RoleBinding — binds SA to Role

**WS-008-05: Secret Management (6)**
1. K8s native Secret — created from values
2. Secret from literal — helm --set-file
3. Secret reference — pod uses secretRef
4. No hardcoded secrets — grep validation
5. Secret type — Opaque vs TLS
6. Secret immutability — immutable=true option

**WS-008-06: Container Security (8)**
1. Non-root user — runAsUser=185
2. Non-root group — runAsGroup=185
3. Read-only root — readOnlyRootFilesystem option
4. No privilege escalation — allowPrivilegeEscalation=false
5. Drop capabilities — drop ALL
6. No privileged — privileged=false
7. Seccomp profile — runtime/default
8. Resource limits — memory/CPU enforced

**WS-008-07: S3 Security (6)**
1. TLS in-flight — enforce HTTPS for S3
2. Encryption at rest — s3:ServerSideEncryption
3. IAM role — IRSA annotation
4. Secret-based — s3-credentials secret
5. No hardcoded keys — grep for AKIA*
6. MinIO local — TLS for MinIO

---

## Feature F12: E2E Tests (Phase 6)

**Source:** `docs/phases/phase-06-e2e.md`
**Status:** Backlog
**Total Workstreams:** 6
**Estimated LOC:** ~4900

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-006-01 | Core E2E (24 scenarios) | LARGE (~1500 LOC) | Phase 0, Phase 1, Phase 5 | backlog |
| WS-006-02 | GPU E2E (16 scenarios) | MEDIUM (~900 LOC) | Phase 0, Phase 5 (GPU images) | backlog |
| WS-006-03 | Iceberg E2E (16 scenarios) | MEDIUM (~900 LOC) | Phase 0, Phase 5 (Iceberg images) | backlog |
| WS-006-04 | GPU+Iceberg E2E (8 scenarios) | MEDIUM (~500 LOC) | Phase 0, Phase 5 (GPU+Iceberg) | backlog |
| WS-006-05 | Standalone E2E (8 scenarios) | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-006-06 | Library compatibility (8 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 1 | backlog |

### Dependency Graph

```
Phase 0, Phase 1, Phase 5
    ↓
WS-006-01 (Core E2E) ─────────────┐
WS-006-02 (GPU E2E) ──────────────┤
WS-006-03 (Iceberg E2E) ───────────┤
WS-006-04 (GPU+Iceberg E2E) ───────┼── All independent (can run in parallel)
WS-006-05 (Standalone E2E) ────────┤
WS-006-06 (Library compatibility) ──┘
```

### Parallel Execution Paths

All 6 workstreams are independent and can run in parallel after Phase 0, Phase 1, and Phase 5 are complete.

### Test Structure

```
tests/e2e/phase06/
├── conftest.py                    # Shared fixtures (NYC Taxi dataset, Spark session)
├── __init__.py
├── test_06_01_core_e2e.py        # 24 Core E2E scenarios
├── test_06_02_gpu_e2e.py         # 16 GPU E2E scenarios (RAPIDS)
├── test_06_03_iceberg_e2e.py     # 16 Iceberg E2E scenarios
├── test_06_04_gpu_iceberg_e2e.py # 8 GPU+Iceberg E2E scenarios
├── test_06_05_standalone_e2e.py  # 8 Standalone E2E scenarios
└── test_06_06_library_compat.py  # 8 Library compatibility scenarios
```

### Scenarios Breakdown

**WS-006-01: Core E2E (24)**
- Spark 3.5.7, 3.5.8, 4.1.0, 4.1.1 × spark-connect, spark-k8s-submit
- 4 SQL queries per scenario (Q1: COUNT, Q2: GROUP BY, Q3: JOIN, Q4: Window)
- NYC Taxi full dataset (11GB)

**WS-006-02: GPU E2E (16)**
- Spark 3.5.7, 3.5.8, 4.1.0, 4.1.1 × RAPIDS baseline, optimized
- 4 GPU queries per scenario (cuDF COUNT, GROUP BY, JOIN, cuML Linear Regression)
- GPU metrics: memory, utilization, speedup factor

**WS-006-03: Iceberg E2E (16)**
- Spark 3.5.7, 3.5.8, 4.1.0, 4.1.1 × Iceberg operations
- Operations: CREATE, READ, UPDATE, DELETE, MERGE, TIME TRAVEL, SCHEMA EVOLUTION, PARTITIONING

**WS-006-04: GPU+Iceberg E2E (8)**
- Spark 3.5.7, 4.1.0 × GPU+Iceberg combo operations
- RAPIDS + Iceberg integration tests

**WS-006-05: Standalone E2E (8)**
- Spark 3.5.7, 3.5.8, 4.1.0, 4.1.1 × Master/Worker coordination
- Operations: Master status, Worker registration, Shuffle, Broadcast, Dynamic allocation, Fault tolerance

**WS-006-06: Library Compatibility (8)**
- Pandas API on Spark, Arrow serialization, MLlib, Delta Lake, Apache Hudi
- Version compatibility matrix

---

## Feature F13: Load Tests (Phase 7)

**Source:** `docs/phases/phase-07-load.md`
**Status:** Backlog
**Total Workstreams:** 5
**Estimated LOC:** ~3000

| ID | Name | Scope | Dependency | Status |
|----|------|-------|------------|--------|
| WS-007-01 | Baseline load (4 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 6 | backlog |
| WS-007-02 | GPU load (4 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 6 (GPU E2E) | backlog |
| WS-007-03 | Iceberg load (4 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 6 (Iceberg E2E) | backlog |
| WS-007-04 | Comparison load (4 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 6 | backlog |
| WS-007-05 | Security stability (4 scenarios) | MEDIUM (~600 LOC) | Phase 0, Phase 1 | backlog |

### Dependency Graph

```
Phase 0, Phase 6
    ↓
WS-007-01 (Baseline Load) ────────────┐
WS-007-02 (GPU Load) ───────────────────┤
WS-007-03 (Iceberg Load) ────────────────┼── All independent (can run in parallel)
WS-007-04 (Comparison Load) ─────────────┤
WS-007-05 (Security Stability) ──────────┘
```

### Parallel Execution Paths

All 5 workstreams are independent and can run in parallel after Phase 0 and Phase 6 are complete.

### Test Structure

```
tests/load/phase07/
├── conftest.py                    # Shared fixtures (30 min duration, metrics)
├── __init__.py
├── test_07_01_baseline_load.py   # 4 Baseline load scenarios
├── test_07_02_gpu_load.py        # 4 GPU load scenarios (RAPIDS)
├── test_07_03_iceberg_load.py    # 4 Iceberg load scenarios
├── test_07_04_comparison_load.py  # 4 Comparison load scenarios
└── test_07_05_security_stability.py # 4 Security stability scenarios
```

### Scenarios Breakdown

**WS-007-01: Baseline Load (4)**
- Spark 3.5.7 — Sustained SELECT COUNT (30 min, 1 qps)
- Spark 3.5.8 — Sustained GROUP BY (30 min, 1 qps)
- Spark 4.1.0 — Sustained JOIN (30 min, 0.5 qps)
- Spark 4.1.1 — Sustained Mixed (30 min, 1 qps)

**WS-007-02: GPU Load (4)**
- Spark 3.5.7 GPU — Sustained cuDF COUNT (30 min, 1 qps)
- Spark 3.5.7 GPU Optimized — Sustained cuDF GROUP BY (30 min, 0.5 qps)
- Spark 4.1.0 GPU — Sustained cuDF JOIN (30 min, 0.5 qps)
- Spark 4.1.0 GPU vs CPU — Comparison Load (30 min)

**WS-007-03: Iceberg Load (4)**
- Spark 3.5.7 Iceberg — Sustained INSERT (30 min, 10 inserts/sec)
- Spark 3.5.8 Iceberg — Sustained MERGE/UPSERT (30 min, 5 merges/sec)
- Spark 4.1.0 Iceberg — Sustained UPDATE/DELETE (30 min, 5 ops/sec)
- Spark 4.1.1 Iceberg — Sustained TIME TRAVEL (30 min, 10 qps)

**WS-007-04: Comparison Load (4)**
- GPU vs CPU — Side-by-side (30 min, alternating)
- Iceberg vs Parquet — Format comparison (30 min, alternating)
- Spark 3.5 vs 4.1 — Version comparison (30 min, alternating)
- Standalone vs K8s-submit — Deployment comparison (30 min, alternating)

**WS-007-05: Security Stability (4)**
- PSS Restricted — Sustained load (30 min)
- SCC Restricted — Sustained load (30 min, mocked)
- RBAC Least Privilege — Sustained load (30 min)
- Network Policies — Sustained load (30 min)

---

## Summary

| Feature | Total WS | Completed | In Progress | Backlog |
|---------|----------|-----------|-------------|---------|
| F00: Helm Charts Update (Phase 0) | 10 | 0 | 0 | 10 |
| F01: Spark Standalone | 12 | 12 | 0 | 0 |
| F02: Repo Documentation | 4 | 4 | 0 | 0 |
| F03: History Server (SA) | 2 | 2 | 0 | 0 |
| F04: Spark 4.1.0 Charts | 24 | 0 | 0 | 24 |
| F05: Docs Refresh (Airflow vars) | 2 | 0 | 0 | 2 |
| F06: Critical Security (Phase 1) | 4 | 0 | 0 | 4 |
| F07: Complete Smoke Tests (Phase 2) | 5 | 0 | 0 | 5 |
| F08: Docker Base Layers (Phase 3) | 3 | 0 | 0 | 3 |
| F09: Docker Intermediate Layers (Phase 4) | 4 | 0 | 0 | 4 |
| F10: Docker Final Images (Phase 5) | 3 | 0 | 0 | 3 |
| F11: Advanced Security (Phase 8) | 7 | 0 | 0 | 7 |
| F12: E2E Tests (Phase 6) | 6 | 0 | 0 | 6 |
| F13: Load Tests (Phase 7) | 5 | 0 | 0 | 5 |
| **TOTAL** | **91** | **18** | **0** | **73** |

---

*Last updated: 2026-02-01*
