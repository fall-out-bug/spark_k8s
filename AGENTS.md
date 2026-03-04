# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

---

## Project Memory (Structure & Principles)

### Structure

```
spark_k8s/
├── charts/                    # Helm charts
│   ├── spark-3.5/            # Spark 3.5.x (has spark-standalone subchart)
│   ├── spark-4.1/            # Spark 4.1.x (no spark-standalone; use charts/spark-standalone)
│   ├── spark-standalone -> spark-3.5/charts/spark-standalone  # Canonical path
│   └── spark-base/           # Shared (MinIO, RBAC)
├── docker/
│   ├── docker-base/          # jdk-17, python-3.10, cuda-12.1
│   ├── spark-custom/         # Custom Spark builds (3.5.7, 3.5.8, 4.1.0, 4.1.1)
│   ├── runtime/spark/        # spark-k8s-runtime: baseline, iceberg, gpu, gpu-iceberg
│   └── runtime/jupyter/      # Jupyter extends runtime
├── tests/
│   ├── test-matrix.yaml      # 320 scenarios (dimensions: spark_version, gpu, iceberg, etc.)
│   ├── run-matrix.sh         # Runner: helm install + smoke/e2e/load
│   └── scripts/nyc_taxi_pipeline.py  # Pipeline for all levels
└── docs/
    ├── drafts/idea-*.md      # Requirements
    ├── workstreams/          # WS-XXX-YY.md
    └── issues/               # ISSUE-XXX.md
```

### Principles

- **TDD:** Red → Green → Refactor. Test failure = requirement not met, not "test wrong"
- **Critical path:** Deploy → Smoke → E2E → Load → Metrics (event logs → History Server)
- **No shortcuts:** Event logs ON, S3 for load (no in-memory fallback), image pyramid respected
- **Config via params:** `--set` for helm, env for pipeline; no per-scenario values files
- **SOLID, DRY, KISS, YAGNI** — see .cursorrules

### Image Pyramid

```
spark-custom:3.5.7|3.5.8|4.1.0|4.1.1  (base)
    → spark-k8s-runtime:3.5-X-baseline|iceberg|gpu|gpu-iceberg
    → spark-k8s-jupyter:3.5-X-*
```

`get_runtime_image(spark_version, gpu, iceberg)` must map dimensions to pyramid.

### Known Drift (2026-03-03)

**Full report:** `docs/reports/drift-analysis-2026-03-03.md` — сверка каждой закрытой фичи с репо.

| Area | Drift | Fix |
|------|-------|-----|
| get_runtime_image | Ignores gpu, iceberg | WS-034-01 (image pyramid) |
| Event logs | Was disabled | S3 config + MinIO spark-logs/4.1/events |
| Load test | Had in-memory fallback | Per-file parquet read, S3 only |
| spark-4.1 | No spark-standalone | Use charts/spark-standalone |
| stash@{1} | Deleted tests (wrong) | Never apply; use split |
| **F08** | WS 00-008-* in backlog, INDEX says completed | Move to completed or align ROADMAP |
| **F01/F03** | Expected charts/spark-standalone at root | Actual: spark-3.5/charts/spark-standalone |
| **F28** | ROADMAP says 1, INDEX says 3 completed | Align counts |
| **WS-011-*** | F02 (docs) and F11 (Docker) ID collision | Note: F02 uses WS-011-01..04 (docs), F11 uses 00-011-01..03 (Docker) in completed/ |

**GPU:** Не исключается. Кластер перезапускается с GPU support.

### Test Matrix Success

- **Target:** Green matrix (96 k8s/no-gpu or 320 full)
- **Path:** Beads per scenario with RGR plan → fix → verify
- **Docs:** `docs/drafts/idea-test-matrix-tdd.md`, `docs/workstreams/backlog/00-034-*.md`

### Beads: Drift + Demo (2026-03-03)

| Epic | ID | Scope |
|------|-----|-------|
| **Stable build** | spark_k8s-6sh | Depends on drift + demo; goal: no break on each run |
| **Drift fixes** | spark_k8s-vle | 4 tasks: F08, F01/F03, F28, WS-011 collision |
| **Demo stability** | spark_k8s-1xt | 14 issues: 4 P0, 6 P1, 4 P2 (demo-review-2026-03-03) |

**Reports:** `docs/reports/drift-analysis-2026-03-03.md`, `docs/reports/demo-review-2026-03-03.md`

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
- `helm install spark-infra charts/spark-3.5/charts/spark-standalone` — chart swap, kills History/Metastore/Jupyter
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

1. Subchart (`spark-standalone`) installed as `spark-infra` instead of parent chart (`spark-3.5`) — killed History/Metastore/PostgreSQL/Jupyter
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
