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

**The demo has been destroyed 3 times in one week by agent work. These rules are mandatory.**

**NEVER do these:**
- `helm install/upgrade` in namespace `spark-infra` (use `scripts/deploy-demo-minikube.sh` or `scripts/restore-demo.sh`)
- `helm install spark-shared -n spark-infra` (creates conflicting release)
- `helm install spark-infra charts/spark-3.5/charts/spark-standalone` (chart swap — kills History, Metastore, Jupyter)
- `kubectl delete namespace spark-infra` or `kubectl delete namespace observability`
- `kubectl scale --replicas=0` on any deployment in `spark-infra` without restoring

**ALWAYS do these:**
- Test scenarios go in `test-scenario-*` or `test-*` namespaces, NEVER in `spark-infra`
- Before matrix runs: `./scripts/check-demo-health.sh`
- After matrix runs: `./scripts/check-demo-health.sh`
- If demo is broken: `./scripts/restore-demo.sh` (recovers in <5 min)
- Use `source scripts/lib/helm-safe.sh && helm_safe_install` for any helm operation

**Root causes of past incidents:**
1. Agent installed subchart (`spark-standalone`) as release `spark-infra` instead of parent chart (`spark-3.5`) — silently deleted History Server, Metastore, PostgreSQL, Jupyter
2. Two releases (`spark-infra` + `spark-shared`) in same namespace — Helm ownership deadlock
3. Matrix tests created too many namespaces — memory exhaustion, demo pods evicted

**Scripts:**
- `scripts/check-demo-health.sh` — verify demo is healthy (exit 0 = OK)
- `scripts/restore-demo.sh` — recover from any failure mode
- `scripts/lib/helm-safe.sh` — helm wrapper that blocks dangerous operations
- `scripts/deploy-demo-minikube.sh` — canonical demo deploy path

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
