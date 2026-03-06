# Project Memory — Meta-Library

> **Purpose:** Single source of truth for project state. Agents: read this to find features, gaps, drift, and where everything lives.
> Distilled from 170+ workstream files. Individual WS files in `completed/` for provenance.
> Last updated: 2026-03-06

---

## Navigation Map — Where to Find What

| I need... | Look here |
|-----------|-----------|
| **Feature status, deliverables, key paths** | Features Index (below) |
| **Image pyramid, test matrix** | Key Concepts (below) |
| **Provenance, evidence, trace** | Key Concepts → Provenance/Evidence/Trace (below) |
| **Open gaps, backlog items** | Known Gaps (below) |
| **Drift, evidence gaps, ID collisions** | Known Drift → `docs/reports/drift-*.md` |
| **Workstream files (WS-XXX-YY)** | `docs/workstreams/completed/`, `docs/workstreams/backlog/` |
| **ADR decisions** | `docs/adr/` |
| **Operations, runbooks** | `docs/operations/`, `docs/runbooks/` |
| **Test matrix, runners** | `scripts/run-matrix-96.sh`, `docs/drafts/idea-test-matrix-tdd.md` |
| **SDP CLI commands** | SDP CLI Reference (below) |
| **Agent workflow, demo rules** | [AGENTS.md](../../AGENTS.md), [docs/operations/demo-protection.md](../operations/demo-protection.md) |

---

## Features Index (Quick Reference)

| Feature | Status | Primary Location |
|---------|--------|------------------|
| F01 Spark Standalone | Done | `charts/spark-3.5/` |
| F02 Documentation | Done | `docs/guides/en/`, `docs/guides/ru/` |
| F03 History Server | Done | `charts/spark-3.5/templates/` |
| F04 Spark 4.1 | Done (gap: Celeborn) | `charts/spark-4.1/`, `charts/spark-base/` |
| F06 Core + Presets | Done | `charts/spark-3.5/templates/core/`, `presets/` |
| F07 Security | Done | PSS/SCC in `charts/spark-3.5/` |
| F08 Smoke Tests | Done (weak evidence) | `tests/integration/` |
| F09–F11 Docker | Done | `docker/docker-base/`, `docker/runtime/` |
| F12 E2E | Done (weak evidence) | `tests/e2e/` |
| F13 Load | Done | `tests/load/` |
| F14 Security Tests | Done | `tests/security/` |
| F15–F17, F22–F31 | Done | See detailed sections below |
| F35 Test Matrix | Done | `scripts/run-matrix-96.sh` |
| F36 Chart Refactor | Done | All charts |

**Full details** — each feature section below has: deliverables, key paths, evidence, WS files.

---

## Key Concepts

**Image Pyramid:** `get_runtime_image(spark_version, gpu, iceberg)` must map to:
```
spark-custom:3.5.7|3.5.8|4.1.0|4.1.1 (base)
  → spark-k8s-runtime:3.5-X-baseline|iceberg|gpu|gpu-iceberg
  → spark-k8s-jupyter:3.5-X-*
```

**Test Matrix:** F35 done. Runner: `scripts/run-matrix-96.sh`. Target: Green 96 k8s/no-gpu, then 320 full.

---

### Provenance, Evidence, Trace

| Concept | Meaning | Where |
|---------|---------|-------|
| **Provenance** | Source of deliverables, WS lineage. Where did this come from? | WS files in `completed/`, `tests/evidence/` (baseline/final snapshots) |
| **Evidence** | Proof work was done. Execution reports, test output, helm lint/template. | Execution report section in each WS file; `tests/evidence/` (helm template snapshots); `scripts/generate-helm-evidence.sh` |
| **Trace** | Traceability: AC → test → deliverable. Audit trail. | Review reports (`docs/reports/review-*.md`), AC mapping in WS files; observability: `trace_id` in logs (Loki) links to Jaeger traces |

**Evidence quality:** Strong = execution reports + tests; Weak = blank reports, code exists; Gap = no evidence.

**Regenerate evidence:** `./scripts/generate-helm-evidence.sh baseline` and `./scripts/generate-helm-evidence.sh final` → `tests/evidence/{baseline,final}/`, `tests/evidence/diff-report.md`.

---

### SDP CLI Reference

| Command | Purpose |
|---------|---------|
| `sdp status --text` | Project state (WS open/completed/blocked) |
| `sdp drift detect [ws-id]` | Detect code↔docs drift |
| `sdp memory index` | Index docs/ into memory.db |
| `sdp memory search <query>` | Full-text search across artifacts |
| `sdp verify <ws-id>` | Verify workstream completion with evidence |
| `sdp log show` | Evidence log events |
| `sdp log trace --verify` | Verify evidence chain integrity |
| `sdp guard activate <ws-id>` | Enforce edit scope before @build |
| `sdp orchestrate --feature F{XX} --next-action` | Get next step for @oneshot |
| `sdp next` | Next-step recommendation |

**Config:** `.sdp/config.yml` (project root). Run `sdp init --auto` or copy `docs/sdp-config.yml.example`.

**Hooks:** After submodule update, run `sh .sdp/hooks/install-git-hooks.sh`. Project hooks: `scripts/hooks/` (pre-commit, pre-push, commit-msg).

**CI (trace, evidence, provenance):** `.github/workflows/ci-sdp.yml` — trace: `sdp log trace --verify` (fail if broken); evidence: helm snapshots `tests/evidence/`, `sdp verify` for modified WS; provenance: conventional commits, SDP-Agent trailers.

---

## Known Gaps

| Area | Gap | Severity |
|------|-----|----------|
| F04 | Celeborn chart missing (WS-020-11) | P2 |
| F08 | All 7 WS lack execution evidence | P3 (code exists) |
| F12 | 5/6 WS lack execution evidence | P3 (code exists) |
| F18 | 14+ operations WS open | P2 |
| F25 | WS-025-11 (load tests), WS-025-12 (tracing) | P2 |
| F29 | minioadmin hardcoded (WS-029-04) | P1 |
| WS-AUTO | Design specs in completed/, never built | P3 (misplaced) |
| WS-CI | Design specs in completed/, CI rebuilt differently | P3 (misplaced) |

---

## Known Drift (2026-03-06)

| Area | Status | Notes |
|------|--------|-------|
| get_runtime_image | Fixed (F35) | Image pyramid in WS-035-06 |
| Event logs, Load test | Fixed | S3 config, per-file parquet |
| F29 minioadmin | Open (P1) | 49+ files |
| F08, F12 evidence | Open | Blank execution reports |
| WS-011, F22/F31 ID collision | Documented | See reports |

**Reports:** `docs/reports/drift-analysis-2026-03-03.md`, `docs/reports/demo-review-2026-03-03.md`

---

## Detailed Feature Sections (Below)

---

## F01: Spark Standalone Helm Chart — DONE (12/12 WS)

**Deliverables:** `charts/spark-3.5/` — full standalone Spark chart with master, workers, shuffle service, Hive Metastore, Airflow, MLflow, ingress, security hardening, example DAGs.
**Key paths:**
- `charts/spark-3.5/templates/` — all Kubernetes templates
- `charts/spark-3.5/dags/` — Airflow DAGs
- `charts/spark-3.5/presets/` — scenario presets
- `charts/spark-3.5/values.yaml`
**Evidence:** Strong. WS-001-01..12 all in `completed/` with execution reports.
**WS files:** `WS-001-01..12`

---

## F02: Repository Documentation — DONE (4/4 WS)

**Deliverables:** docs skeleton, guides (EN+RU), validation runbook, OpenShift notes.
**Key paths:**
- `docs/guides/en/` — English guides (charts, overlays)
- `docs/guides/ru/` — Russian guides
- `README.md`
**Evidence:** Strong. WS-011-01..04 with execution reports.
**WS files:** `WS-011-01..04`

---

## F03: Spark History Server — DONE (2/2 WS)

**Deliverables:** History Server template + smoke test.
**Key paths:** `charts/spark-3.5/templates/` (history server), `tests/integration/`
**Evidence:** Strong. Reviewed 2026-01-16, APPROVED.
**WS files:** `WS-012-01..02`

---

## F04: Spark 4.1.0 Charts — DONE (24/24 WS, gap: Celeborn)

**Deliverables:** Full Spark 4.1 chart with Connect, Metastore, History Server, Jupyter, RBAC, Operator.
**Key paths:**
- `charts/spark-4.1/` — 92 files (templates, presets, environments)
- `charts/spark-base/` — shared chart (PostgreSQL, MinIO, RBAC)
- `charts/spark-operator/` — Spark Operator CRDs
- `docs/guides/` — quickstart, production, multi-version guides
- `docs/adr/` — ADR-0004+
**Gap:** Celeborn chart (WS-020-11) — docs exist but no `charts/celeborn/`.
**Evidence:** Weak. No execution reports in WS files. Code exists but WS docs were spec-only.
**WS files:** `WS-020-01..24`

---

## F05: Docs Refresh (Airflow vars) — DONE (2/2 WS)

**Deliverables:** Updated validation docs EN+RU for Airflow variables.
**WS files:** `WS-021-01..02`

---

## F06: Core Components + Feature Presets — DONE (10/10 WS)

**Deliverables:** Core template structure, MinIO, PostgreSQL, Hive Metastore, History Server, GPU features, Iceberg features, base presets, scenario presets, chart README.
**Key paths:**
- `charts/spark-3.5/templates/core/` — core component templates
- `charts/spark-3.5/presets/` — infrastructure and scenario presets
**Evidence:** Strong. WS-006-01..10, all with completion evidence.
**WS files:** `WS-006-01..10` (note: 06-03, 06-07 files not in completed/ — likely merged into others)

---

## F07: Critical Security + Chart Updates — DONE (4/4 WS)

**Deliverables:** namespace.yaml, podSecurityStandards, OpenShift presets, PSS/SCC smoke tests.
**Key paths:** `charts/spark-3.5/templates/`, `charts/spark-3.5/presets/`
**Evidence:** Strong. WS-022-01..04.
**WS files:** `WS-022-01..04`

---

## F08: Smoke Tests (Phase 2) — DONE (7/7 WS, weak evidence)

**Deliverables:** Jupyter GPU/Iceberg scenarios, standalone chart scenarios, Spark Operator scenarios, History Server validation, MLflow scenarios, dataset generation, parallel execution.
**Key paths:** `tests/integration/`, `tests/e2e/`
**Evidence:** WEAK. All 7 WS files (00-008-01..07) have blank execution report placeholders.
**WS files:** `00-008-01..07`

---

## F09: Docker Base Layers (Phase 3) — DONE (3/3 WS)

**Deliverables:** JDK 17, Python 3.10, CUDA 12.1 base Docker images.
**Key paths:** `docker/docker-base/jdk-17/`, `docker/docker-base/python-3.10/`, `docker/docker-base/cuda-12.1/`
**Evidence:** Strong for 009-01 (real test output). Adequate for 009-02, 009-03.
**WS files:** `00-009-01..03`

---

## F10: Docker Intermediate Layers (Phase 4) — DONE (4/4 WS, naming mess)

**Deliverables:** Spark core layers, Python deps, JDBC drivers, JARs (RAPIDS, Iceberg).
**Key paths:** `docker/docker-intermediate/`, `docker/spark-custom/`
**Evidence:** Mixed. WS-010-02, WS-010-04: Strong. 00-010-01/02/04: blank (superseded specs).
**Note:** Duplicate files exist: `00-010-XX` (specs) vs `WS-010-XX` (implementations). WS-010-* are canonical.
**Redesign (archived):** F10 was redesigned to use custom Spark builds (Hadoop 3.4.2, AWS SDK v2). Incorrect `docker/docker-base/spark-core/` removed. Version coverage: 3.5.7, 4.1.0.
**WS files:** `WS-010-01..04`, `WS-00-010-03` (canonical); `00-010-01/02/04` (superseded specs)

---

## F11: Docker Final Images (Phase 5) — DONE (3/3 WS)

**Deliverables:** Spark 3.5 images (8 variants), Spark 4.1 images (8 variants), Jupyter images (12 variants).
**Key paths:** `docker/runtime/spark/`, `docker/runtime/jupyter/`, `docker/spark-3.5/`, `docker/spark-4.1/`
**Evidence:** Strong. 00-011-01..03 with image size data, file lists.
**WS files:** `00-011-01..03`

---

## F12: E2E Tests (Phase 6) — DONE (6/6 WS, mostly weak evidence)

**Deliverables:** Core, GPU, Iceberg, GPU+Iceberg, Standalone, Library compat E2E tests.
**Key paths:** `tests/e2e/`
**Evidence:** Strong for 00-012-01. WEAK for 00-012-02..06 (blank reports, `status: backlog` in frontmatter).
**WS files:** `00-012-01..06`

---

## F13: Load Tests (Phase 7) — DONE (5/5 WS)

**Deliverables:** Baseline, GPU, Iceberg, Comparison, Security stability load tests.
**Key paths:** `tests/load/`, `scripts/tests/load/`
**Evidence:** Strong. 00-013-01..05 with file lists and quality checks.
**WS files:** `00-013-01..05`

---

## F14: Advanced Security (Phase 8) — DONE (7/7 WS)

**Deliverables:** PSS, SCC, Network policies, RBAC, Secret management, Container security, S3 security tests.
**Key paths:** `tests/security/` (24 test files across 7 subdirectories: pss/, scc/, network/, rbac/, secrets/, container/, s3/)
**Evidence:** Strong. Reviewed 2026-02-13, APPROVED. 118 passed, 14 skipped, 81.91% coverage.
**WS files:** `WS-014-01..07`, `WS-C5M` (split test_security.py)

---

## F15: Parallel Execution & CI/CD (Phase 9) — DONE (3/3 WS)

**Deliverables:** Parallel execution framework, result aggregation, CI/CD integration.
**Key paths:** `scripts/run-matrix-96.sh`, `scripts/aggregate-matrix-results.py`
**Evidence:** Adequate. Reviewed 2026-02-13, APPROVED.
**WS files:** `00-015-01..03`

---

## F16: Observability Stack — DONE (6/6 WS)

**Deliverables completed:** Prometheus (WS-016-01), Loki (WS-016-02), Jaeger (WS-016-03), Grafana (WS-016-04), AlertManager (WS-016-05), Spark UI integration (WS-016-06).
**Key paths:** `charts/observability/`, `charts/observability-demo/` (demo umbrella), `tests/integration/test_observability_*.py`, `charts/spark-3.5/templates/history-server-servicemonitor.yaml`
**Evidence:** Strong. 16 observability integration tests. Grafana: Prometheus/Loki/Jaeger datasources, spark-overview dashboard. AlertManager: PrometheusRule, Slack, inhibit rules. History Server: ServiceMonitor, Jaeger/Loki env vars.
**Consolidation (2026-03-06):** Single stack. Demo uses `charts/observability-demo` (Helm). demo-metrics-exporter + OTEL Collector in chart. Raw YAMLs → `tests/observability/_archived/`. Deploy: `scripts/tests/minikube/deploy-observability.sh`.
**Helm lint (2026-03-06):** observability-demo values.yaml must provide Grafana subchart defaults (sidecar, imageRenderer, grafana.ini, persistence.inMemory) — per "Right over fast", no workarounds. See ADR-0010.
**WS files:** `completed/00-016-01`..`00-016-06`

---

## F17: Spark Connect Go Client — DONE (4/4 WS)

**Deliverables:** Go client library, smoke/E2E/load tests.
**Evidence:** Strong. Reviewed 2026-02-10, APPROVED. 1701 LOC across 25 files.
**WS files:** `WS-017-01..04`

---

## F18: Production Operations Suite — PARTIAL (3/17+ WS)

**Deliverables completed:** Incident Response Framework, Spark Failure Runbooks, Data Recovery Runbooks.
**Key paths:** `docs/operations/runbooks/`, `docs/operations/procedures/`
**Evidence:** Strong for completed WS. Reviewed 2026-02-10, APPROVED.
**Remaining:** WS-018-04..17 (SLO, Scaling, etc.) — still open.
**WS files:** `WS-018-02..03`

---

## F22: Progress Automation — DONE (4/4 WS)

**Deliverables:** Workstream completion bot, ROADMAP auto-update, weekly digest generator, metrics dashboard.
**Key paths:** `scripts/cicd/update-roadmap.sh`, `scripts/cicd/weekly-digest.sh`
**Evidence:** Strong.
**WS files:** `WS-031-01..04` (note: shares 031 prefix with F31)

---

## F23: Project Origins Documentation — DONE (5/5 WS)

**Deliverables:** Origin story, problem deep dive, solution philosophy, vision/roadmap, bilingual RU.
**Key paths:** `docs/architecture/`, `README.md`
**Evidence:** Strong.
**WS files:** `WS-032-01..05`

---

## F24: Pre-built Docker Images — DONE (6/6 WS)

**Deliverables:** GHCR registry, build automation (spark-custom, jupyter-spark), multi-arch, version tagging, chart updates.
**Key paths:** `.github/workflows/build-spark-dist.yml`, `docker/spark-custom/`, `docker/jupyter/`
**Evidence:** Strong.
**WS files:** `WS-033-01..06`

---

## F25: Spark 3.5 Production-Ready — DONE (10/12 WS)

**Deliverables:** Chart metadata, standalone deployment, Prometheus metrics, monitoring templates, OpenShift routes, scenario values, configmap fixes, validation tests, minikube integration.
**Key paths:** `charts/spark-3.5/`, `tests/integration/`
**Evidence:** Strong for WS-025-01..10. Reviewed 2026-02-10, APPROVED.
**Remaining:** WS-025-11 (load tests 10GB), WS-025-12 (tracing dashboards) — backlog.
**WS files:** `WS-025-01..10`

---

## F26: Spark Performance Defaults — DONE (3/3 WS)

**Deliverables:** AQE + modern defaults, deprecated properties fix, structured streaming example.
**Key paths:** `charts/spark-3.5/values.yaml`, `charts/spark-4.1/values.yaml`, `examples/streaming/`
**Evidence:** Strong.
**WS files:** `WS-026-01..03`

---

## F27: Code Quality — DONE (3/3 WS)

**Deliverables:** pyproject.toml, pre-commit hooks, split oversized files.
**Key paths:** `pyproject.toml`, `.pre-commit-config.yaml`
**Evidence:** Weak (WS docs have `status: backlog`, AC unchecked). But deliverables exist.
**WS files:** `WS-027-01..03`

---

## F28: Chart Architecture DRY — DONE (3/3 WS)

**Deliverables:** Unified values layout, RBAC consolidation, values.schema.json, Helm test templates.
**Key paths:** `charts/spark-3.5/values.schema.json`, `charts/spark-base/`
**Evidence:** Strong. Oneshot report: `docs/reports/oneshot-F028-2026-02-13.md`.
**WS files:** `WS-028-01..03`

---

## F29: CI/CD Hardening — PARTIAL (3/4 WS done)

**Deliverables completed:** Modern CI workflows, Dependabot, CODEOWNERS, .dockerignore.
**Key paths:** `.github/workflows/ci-*.yml`, `.github/CODEOWNERS`, `.dockerignore`
**Gap:** WS-029-04 (harden default credentials) — `minioadmin` still in 49+ files. NOT DONE.
**Evidence:** Weak (WS docs have `status: backlog`). But deliverables exist for 01-03.
**WS files:** `WS-029-01..04`

---

## F30: Data Engineering Patterns — DONE (4/4 WS)

**Deliverables:** OpenLineage preset, production DAG templates, Iceberg best practices, observability integration.
**Key paths:**
- `charts/spark-4.1/presets/openlineage-values.yaml`
- `examples/airflow/dags/production/`
- `docs/recipes/data-management/iceberg-best-practices.md`
- `examples/iceberg/best_practices/`
**Evidence:** Weak (WS docs have `status: backlog`). But deliverables exist.
**WS files:** `WS-030-01..04`

---

## F31: Observability as Product — DONE (9/9 WS)

**Deliverables:** INVENTORY, 5 persona recipes (DevOps, DataOps, Tech Lead, Data Engineer, Data Scientist), PR gate smoke tests, example alerts, runbook index.
**Key paths:**
- `docs/observability/INVENTORY.md` — dashboards, metrics, Loki, demos
- `docs/observability/recipes/` — devops-5min, dataops-5min, techlead-5min, data-engineer-5min, ds-5min
- `tests/observability/test_observability_smoke.py` — helm template assertions
- `docs/observability/examples/` — alerts.yaml, README
- `docs/observability/README.md` — entry point, personas table
**Evidence:** Strong. All 9 WS have execution reports. Reviewed 2026-03-06, APPROVED.
**Review fixes (2026-03-06):** values.yaml Grafana subchart defaults (Right over fast). CI: helm lint observability-demo without -f. .cursorrules: observability-demo in repo structure. See ADR-0010.
**WS files:** `completed/00-031-01`..`00-031-09`

---

## F35: Test Matrix Rebuild — DONE (8/8 WS)

**Deliverables:** Matrix runner core, deploy/smoke/e2e/load levels, image pyramid, metrics validation, 96-scenario integration.
**Key paths:** `scripts/run-matrix-96.sh`, `scripts/run-matrix-320.sh`, `tests/integration/test_run_matrix.py`
**Evidence:** Strong. All WS have execution reports with test evidence.
**WS files:** `00-035-01..08`

---

## F36: Chart Refactor — Flatten/Rename — DONE (12/12 WS)

**Deliverables:** Flattened standalone into parent chart, extracted Airflow, renamed `kubernetes` key, updated presets/scripts/tests/docs, CI gates, final evidence diff.
**Key paths:** All `charts/spark-3.5/`, `charts/spark-4.0/`, scripts, tests, docs.
**Evidence:** Strong. Provenance snapshots before/after, helm lint, helm template evidence.
**WS files:** `00-036-01..12`

---

## Bug Fixes — 7 completed

| ID | Fix | Path |
|----|-----|------|
| 2026-03-06 | spark-operator crds.create nil pointer | `charts/spark-operator/values.yaml` |
| WS-BUG-004 | Spark 4.1 Connect readonly config | `charts/spark-4.1/` |
| WS-BUG-005 | Spark 4.1 Metastore readonly config | `charts/spark-4.1/` |
| WS-BUG-006 | History log prefix `spark-logs/4.1/events` | `charts/spark-base/` |
| WS-BUG-007 | S3 credentials existingSecret | `charts/spark-base/` |
| WS-BUG-008 | Jupyter RUNTIME_DIR | `docker/runtime/jupyter/` |
| WS-BUG-009 | Spark 3.5 Metastore UID | `charts/spark-3.5/` |

**Evidence:** All Strong. Execution reports with verified fixes.

---

## TESTING Infrastructure — DONE (3/3 WS)

**Deliverables:** Minikube storage diagnostics, provisioner fix, E2E test.
**Key paths:** `docs/testing/`, `scripts/testing/`
**Evidence:** Strong. Execution reports with root cause analysis.
**WS files:** `WS-TESTING-001..003`

---

## Unregistered Work (06-XXX series, F19, WS-AUTO, WS-CI)

### 06-XXX (old Phase 1 roadmap) — 11 WS, mixed quality
Real deliverables for: multi-environment (`charts/spark-4.1/environments/`), observability (ServiceMonitor/PodMonitor), auto-scaling (`templates/autoscaling/`), security stack (network policies), GPU support (presets), governance docs. Thin/missing: compatibility matrix, disaster recovery, onboarding.

### F19 (API Documentation) — 1 WS
`scripts/docs/generate-values-reference.sh`, `docs/reference/values-reference.md`. Adequate.

### WS-AUTO-01..06 — DESIGN SPECS ONLY, no implementation
### WS-CI-01..03 — DESIGN SPECS ONLY, target CI workflows archived

---

## Cancelled

### F34: Test Matrix TDD — CANCELLED (5/5 WS, superseded by F35)

All 5 workstreams cancelled 2026-03-06. F35 covers same scope with better specificity:
- WS-034-01 (Image Pyramid) → replaced by WS-035-06
- WS-034-02 (Beads Generator) → replaced by matrix runner approach
- WS-034-03 (Full Critical Path) → replaced by WS-035-02..05
- WS-034-04 (Metrics Validation) → replaced by WS-035-07
- WS-034-05 (Green 96 Scenarios) → replaced by WS-035-08

