# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

---

## Project Memory (Structure & Principles)

### Structure

```
spark_k8s/
├── charts/
│   ├── spark-3.5/            # Primary Spark 3.5 chart (standalone, airflow, connect)
│   │   ├── templates/        # K8s templates (standalone, connect, core/)
│   │   ├── presets/           # Scenario + infra presets
│   │   ├── dags/              # Airflow DAGs
│   │   └── examples/          # ML examples
│   ├── spark-4.0/            # Spark 4.0 chart (connect scenarios)
│   ├── spark-4.1/            # Spark 4.1 chart (connect, environments, autoscaling)
│   ├── spark-base/           # Shared subchart (PostgreSQL, MinIO, RBAC, backup)
│   ├── spark-operator/       # Spark Operator CRDs
│   └── observability/        # Grafana, Prometheus, Loki, Jaeger
├── docker/
│   ├── docker-base/          # jdk-17, python-3.10, cuda-12.1, python-deps
│   ├── docker-intermediate/  # jars-iceberg, jars-rapids, jdbc-drivers
│   ├── spark-custom/         # Custom Spark builds (3.5.7, 3.5.8, 4.1.0, 4.1.1)
│   ├── runtime/spark/        # spark-k8s-runtime: baseline, iceberg, gpu, gpu-iceberg
│   └── runtime/jupyter/      # Jupyter extends runtime
├── tests/
│   ├── integration/          # Helm template rendering tests
│   ├── security/             # 24 tests: pss/, scc/, network/, rbac/, secrets/, container/, s3/
│   ├── e2e/                  # Live cluster tests
│   ├── load/                 # Load tests
│   └── evidence/             # Provenance snapshots (baseline, final, post-036-*)
├── scripts/
│   ├── deploy-demo-minikube.sh, restore-demo.sh, check-demo-health.sh  # Demo ops
│   ├── run-matrix-96.sh, run-matrix-320.sh                             # Test matrix
│   ├── tests/                # Test runners (smoke, e2e, load, minikube)
│   └── cicd/                 # CI tooling
├── examples/                  # airflow/, gpu/, iceberg/, streaming/
├── dags/                      # Airflow DAGs
├── docs/
│   ├── workstreams/           # MEMORIES.md (summary), completed/, backlog/, cancelled/, _archived/
│   ├── guides/en/, guides/ru/ # User guides (bilingual)
│   ├── recipes/               # How-to recipes by domain
│   ├── operations/            # Runbooks, procedures
│   ├── architecture/          # Architecture docs
│   └── drafts/                # Requirements (idea-*.md)
├── .github/workflows/         # ci-charts, ci-docker, ci-e2e, ci-lint, ci-sdp, build-spark-dist
├── pyproject.toml             # Python tooling config (pytest, ruff, black, mypy)
└── .pre-commit-config.yaml    # Pre-commit hooks
```

### Implemented Features Index

> Source of truth: `docs/workstreams/MEMORIES.md`

| Feature | Status | Primary Codebase Location |
|---------|--------|--------------------------|
| **F01** Spark Standalone Chart | Done | `charts/spark-3.5/` |
| **F02** Repository Documentation | Done | `docs/guides/en/`, `docs/guides/ru/` |
| **F03** History Server | Done | `charts/spark-3.5/templates/` |
| **F04** Spark 4.1.0 Charts | Done (gap: Celeborn) | `charts/spark-4.1/`, `charts/spark-base/`, `charts/spark-operator/` |
| **F06** Core Components + Presets | Done | `charts/spark-3.5/templates/core/`, `charts/spark-3.5/presets/` |
| **F07** Security + Chart Updates | Done | PSS/SCC in `charts/spark-3.5/` |
| **F08** Smoke Tests | Done (weak evidence) | `tests/integration/` |
| **F09** Docker Base Layers | Done | `docker/docker-base/` |
| **F10** Docker Intermediate | Done | `docker/docker-intermediate/`, `docker/spark-custom/` |
| **F11** Docker Final Images | Done | `docker/runtime/spark/`, `docker/runtime/jupyter/` |
| **F12** E2E Tests | Done | `tests/e2e/` |
| **F13** Load Tests | Done | `tests/load/` |
| **F14** Advanced Security | Done | `tests/security/` (24 files, 7 subdirs) |
| **F15** Parallel Execution | Done | `scripts/run-matrix-96.sh` |
| **F17** Go Client | Done | (external) |
| **F22** Progress Automation | Done | `scripts/cicd/` |
| **F24** Docker Images CI | Done | `.github/workflows/build-spark-dist.yml` |
| **F25** Spark 3.5 Production | Done (10/12) | `charts/spark-3.5/` |
| **F26** Performance Defaults | Done | `charts/*/values.yaml` |
| **F27** Code Quality | Done | `pyproject.toml`, `.pre-commit-config.yaml` |
| **F28** Chart Architecture DRY | Done | `charts/spark-base/`, `values.schema.json` |
| **F29** CI/CD Hardening | Partial (3/4) | `.github/workflows/ci-*.yml`, `.github/CODEOWNERS` |
| **F30** Data Engineering | Done | `examples/airflow/`, `examples/iceberg/`, `docs/recipes/` |
| **F35** Test Matrix Rebuild | Done | `scripts/run-matrix-*.sh`, `tests/integration/test_run_matrix.py` |
| **F36** Chart Refactor | Done | All charts, scripts, tests, docs |
| **F16** Observability Stack | Done (6/6) | `charts/observability/`, `tests/integration/test_observability_*.py` |
| **F31** Observability as Product | Done (9/9) | `docs/observability/`, `tests/observability/` |

### Backlog (active)

| Feature | WS Count | Location |
|---------|----------|----------|
| *(none)* | — | — |

### Open Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| F04: Celeborn chart | P2 | Docs exist, chart missing |
| F18: 14+ operations WS | P2 | Runbooks partial |
| F25: Load tests + tracing | P2 | WS-025-11, 025-12 |
| F29: `minioadmin` hardcoded | P1 | WS-029-04 not done |

### Principles

- **Right over fast:** Do it right, not fast. No workarounds that paper over root causes.
- **Complete the chain:** If you see a chain of problems — finish it. Don't add config without the JAR, don't fix A and leave B broken.
- **Clarify over assume:** Better to ask than to invent. When unclear, ask before implementing.
- **Check for conflicts:** When doing something, verify it doesn't contradict existing solutions, presets, or docs.
- **Boy Scout Rule:** Every touched file must be left better than it was — no regressions, no half-done edits.
- **TDD:** Red → Green → Refactor. Test failure = requirement not met, not "test wrong"
- **Critical path:** Deploy → Smoke → E2E → Load → Metrics (event logs → History Server)
- **No shortcuts:** Event logs ON, S3 for load (no in-memory fallback), image pyramid respected
- **Config via params:** `--set` for helm, env for pipeline; no per-scenario values files
- **SOLID, DRY, KISS, YAGNI** — see .cursorrules
- **No compromises:** If the right path exists, take it. No "good enough" when it contradicts the correct solution.
- **Principles are non-negotiable:** Violating them undermines them. Never lie to ourselves — fix or track.

### Image Pyramid

```
spark-custom:3.5.7|3.5.8|4.1.0|4.1.1  (base)
    → spark-k8s-runtime:3.5-X-baseline|iceberg|gpu|gpu-iceberg
    → spark-k8s-jupyter:3.5-X-*
```

`get_runtime_image(spark_version, gpu, iceberg)` must map dimensions to pyramid.

### Known Drift (2026-03-06, post-cleanup)

| Area | Status | Notes |
|------|--------|-------|
| get_runtime_image | Fixed (F35) | Image pyramid implemented in WS-035-06 |
| Event logs | Fixed | S3 config + MinIO spark-logs/4.1/events |
| Load test | Fixed | Per-file parquet read, S3 only |
| F36 refactor | Done | Standalone flattened into spark-3.5 parent chart |
| F08 evidence gap | Open | 7 WS have blank execution reports; code exists |
| F12 evidence gap | Open | 5/6 WS have blank execution reports; code exists |
| F29 minioadmin | Open (P1) | `minioadmin` still in 49+ files |
| F04 Celeborn | Open (P2) | Docs exist, chart missing |
| WS-011 ID collision | Documented | F02 uses WS-011-01..04 (docs), F11 uses 00-011-01..03 (Docker) |
| F22/F31 ID collision | Documented | F22: WS-031-01..04 (progress), F31: 00-031-01..09 (observability) — both done |

**Reports:** `docs/reports/drift-analysis-2026-03-03.md`, `docs/reports/demo-review-2026-03-03.md`

### Test Matrix

- **Status:** F35 completed (8/8 WS). Runner: `scripts/run-matrix-96.sh`
- **Target:** Green 96 k8s/no-gpu, then 320 full
- **Docs:** `docs/drafts/idea-test-matrix-tdd.md`
- **F34 cancelled** (superseded by F35, files in `docs/workstreams/cancelled/`)

### Demo Protection (NON-NEGOTIABLE)

**The demo has been destroyed 3+ times by agent work. These rules are mandatory.**

#### READ FIRST — before ANY helm/kubectl touching spark-infra or observability

1. Read this entire Demo Protection section
2. Run `./scripts/check-demo-health.sh` — if it fails, run `./scripts/restore-demo.sh` first
3. For config changes: read `charts/spark-3.5/presets/demo-full-spark-infra.yaml` — it is the **sole source of truth**
4. Never run raw `helm` or `kubectl` for demo — use only the canonical scripts

#### Invariants (must always hold)

- `spark-infra` has exactly ONE Helm release named `spark-infra`, chart `spark-3.5` (parent, NOT subchart)
- Service names: `spark-infra-standalone-*` (master, airflow), `spark-infra-spark-35-*` (history, jupyter, metastore), `spark-infra-spark-base-*` (postgresql), `minio` — never `spark-shared-*`
- Preset `presets/demo-full-spark-infra.yaml` is the sole config source; `values.yaml` are fallback defaults only
- Workers: ≥3 replicas, ≥800m CPU, ≥13Gi memory, ≥2 cores, ≥14g Spark memory
- Resource budget: ~5 CPU / ~44Gi of 6 CPU / 48Gi node (enforced by `test_demo_preset_guard.py`)

#### NEVER do these

**Helm/Kubectl:**
- `helm install/upgrade` in `spark-infra` — use `scripts/deploy-demo-minikube.sh` or `scripts/restore-demo.sh`
- `helm install spark-shared -n spark-infra` — conflicting release
- `helm install spark-infra` with wrong chart — chart swap, kills History/Metastore/Jupyter
- `helm uninstall spark-infra -n spark-infra` — use `restore-demo.sh`
- `kubectl delete namespace spark-infra` or `kubectl delete namespace observability`
- `kubectl delete pvc` in `spark-infra` — breaks PostgreSQL auth, Airflow state
- `kubectl scale --replicas=0` in `spark-infra` without immediately restoring
- `kubectl apply` raw manifests into `spark-infra` bypassing Helm

**Configuration:**
- Editing `charts/*/values.yaml` to change demo config — edit only `presets/demo-full-spark-infra.yaml`
- Adding `--set standalone.worker.resources.*` or `--set standalone.worker.replicas` — preset defines these
- Renaming the release from `spark-infra` — port-forwards, exporters, DAGs all reference it
- Hardcoding service names with `spark-shared-*` or any non-`spark-infra-` prefix
- Manually configuring Grafana datasources via API — not persistent; use `deploy-observability.sh`
- Increasing `MAX_TEST_NAMESPACES` in `run-matrix.sh` without verifying cluster capacity

#### ALWAYS do these

- Run `./scripts/check-demo-health.sh` **before and after** any change to `spark-infra` or `observability`
- For config changes: edit `presets/demo-full-spark-infra.yaml`, deploy via canonical script
- Test scenarios in `test-scenario-*` / `test-*` namespaces, NEVER in `spark-infra`
- If demo broken: `./scripts/restore-demo.sh` — do NOT retry failed operation
- After restore/re-deploy: kill stale port-forwards, restart `./tests/observability/start-ui-portforwards.sh`
- When adding files referencing demo services: use `spark-infra` as release name

#### Root causes (9 documented incidents)

1. Wrong chart installed as `spark-infra` instead of parent chart (`spark-3.5`) — killed History/Metastore/PostgreSQL/Jupyter
2. Two releases (`spark-infra` + `spark-shared`) in same namespace — Helm ownership deadlock
3. Too many test namespaces — memory exhaustion, demo pods evicted
4. Config drift: agent edited `values.yaml` instead of preset → 200m/1Gi workers
5. PVC deleted → PostgreSQL password mismatch on restart
6. Port-forwards pointed to `spark-shared-*` (old release name) after re-deploy
7. Grafana datasources configured via API, lost on pod restart
8. demo-metrics-exporter hardcoded `spark-shared-*` → metrics failed
9. Agent renamed release → cascading failures in DAGs, exporters, port-forwards

#### Canonical scripts (use these, never invent alternatives)

| Script | Purpose |
|--------|---------|
| `scripts/deploy-demo-minikube.sh` | Fresh demo deploy |
| `scripts/restore-demo.sh` | Recover from any failure (<5 min) |
| `scripts/check-demo-health.sh` | Verify demo health (exit 0 = OK) |
| `scripts/tests/minikube/deploy-observability.sh` | Observability + Grafana datasources |
| `tests/observability/start-ui-portforwards.sh` | Port-forwards for Windows access |
| `scripts/lib/helm-safe.sh` | Helm wrapper blocking dangerous ops |

---

## Operational Rules (spark-infra & observability)

### 1. Pre-flight (BEFORE any change)

```bash
./scripts/check-demo-health.sh   # exit 0 required; if fails → restore-demo.sh first
```

- Target namespace: `spark-infra` or `observability` — never mix
- spark-infra chart: `charts/spark-3.5` (parent), NOT subchart
- spark-infra values: MUST use `-f charts/spark-3.5/presets/demo-full-spark-infra.yaml`
- observability: use `./scripts/tests/minikube/deploy-observability.sh`

### 2. Post-flight (AFTER any change)

```bash
./scripts/check-demo-health.sh   # run within 2 min of any deploy
```

If failed: do NOT retry — run `./scripts/restore-demo.sh`. If restore fails, hand off to human.

After restore/re-deploy: `pkill -f "kubectl port-forward.*spark-infra"` then `./tests/observability/start-ui-portforwards.sh`

### 3. Rollback: symptom → action

| Symptom | Action |
|---------|--------|
| Helm stuck (pending-install/upgrade, uninstalling) | `./scripts/restore-demo.sh` |
| Wrong chart on release | `./scripts/restore-demo.sh` |
| Two releases in spark-infra | `helm uninstall <wrong-release> -n spark-infra` then `./scripts/restore-demo.sh` |
| Pods OOMKilled / Evicted | Clean test namespaces, then `./scripts/restore-demo.sh` |
| PostgreSQL auth failure | **Do NOT delete PVCs.** Reset password: `kubectl exec spark-infra-spark-base-postgresql-0 -c postgresql -- psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"` then restart dependent pods |
| Metastore CrashLoopBackOff | Fix PostgreSQL first (above), ensure `metastore_db` exists, `kubectl delete pod` metastore |
| Grafana datasources missing | `./scripts/tests/minikube/deploy-observability.sh` |
| Port-forwards dead | `pkill -f port-forward` then `./tests/observability/start-ui-portforwards.sh` |

**Never:** `helm uninstall spark-infra -n spark-infra` — use restore-demo.sh.

### 4. Resource budget (6 CPU / 48Gi minikube)

| Component | CPU req | Memory req |
|-----------|---------|------------|
| System (kube-system, etc.) | ~850m | ~300Mi |
| Observability | ~250m | ~544Mi |
| spark-infra infra | ~1550m | ~4.5Gi |
| 3 workers × 800m/13Gi | 2400m | 39Gi |
| **Total** | ~5050m (84%) | ~44Gi (92%) |

- Test namespaces: keep orphan count ≤ 1; each consumes ~500m CPU
- Never scale workers >3 or increase memory >13Gi without capacity check
- Before matrix: `kubectl get ns -o name | grep -c test-scenario` — must be ≤ 1

### 5. Observability protection

- **Grafana datasources:** only via `deploy-observability.sh`; API/UI edits lost on restart
- **Prometheus targets:** demo-metrics-exporter expects `spark-infra-*` services
- **Port-forwards:** restart `start-ui-portforwards.sh` after every re-deploy

### 6. Session handoff

```bash
./scripts/check-demo-health.sh          # MUST exit 0
kubectl get ns | grep test-scenario      # orphans ≤ 1
helm list -n spark-infra                 # 1 release, status=deployed
git status && git push                   # committed + pushed
```

If `restore-demo.sh` was run during session, note it in handoff.

---

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
