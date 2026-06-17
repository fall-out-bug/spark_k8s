# spark_k8s Constitution

Project-wide principles governing all spec-kit features. Applies to every `specs/<feature>/` directory. Amendments require PR + ratification note in Governance section.

## Core Principles

### I. Right over Fast (NON-NEGOTIABLE)

Between "do it right" and "do it fast" we always choose right. No workarounds that paper over root causes — fix the underlying issue. If we know the correct approach, we take it. No "good enough for now" when it contradicts the right solution.

### II. Complete the Chain

If you see a chain of problems, finish it to the end. Don't add config without the JAR, don't fix A and leave B broken. Half-finished implementations are forbidden.

### III. Regression Prevention (NON-NEGOTIABLE)

Critical paths — **demo, deploy, smoke tests** — must not regress. Use guards, tests, canonical scripts:

- Before ANY helm/kubectl touching `charts/spark-3.5/` or `charts/observability-demo/`: run `./scripts/check-demo-health.sh`. If fails → `./scripts/restore-demo.sh` first.
- Canonical scripts only for demo: `scripts/deploy-demo-minikube.sh`, `scripts/restore-demo.sh`, `scripts/check-demo-health.sh`.
- Smoke tests are blocking. If a smoke test fails → equivalent to regression failure.

### IV. Helm Chart Conventions

This is a Helm chart repo, NOT a Python application. There is no Python source to "cover".

- **Files < 200 LOC** AI-readiness gate (charts excluded from coverage; templates target < 200 LOC).
- **No hardcoded secrets in templates**: use `Secret` + `envFrom.secretRef` / `valueFrom.secretKeyRef`. Local-only example creds in `values.yaml` MUST be documented as such.
- **Naming**: `{{ include "<chart>.fullname" . }}` for resources; `app.kubernetes.io/*` labels via `_helpers.tpl`.
- **Security**: when `security.podSecurityStandards=true`, templates must be PSS `restricted` compatible: `runAsNonRoot`, `seccompProfile: RuntimeDefault`, drop all caps, `allowPrivilegeEscalation=false`. Avoid `hostPath`, `hostPort`, `privileged`.
- **MinIO buckets**: if a component uses `s3a://<bucket>/<prefix>`, the init job must ensure bucket exists.

### V. Test Quality (Helm-specific)

Valid tests MUST do one of:
1. Run `helm template` and assert on rendered YAML output
2. Run `helm lint` and verify chart syntax
3. Execute a script and verify output/exit code
4. Run against live K8s cluster (`@pytest.mark.e2e`)

**FORBIDDEN test patterns:**
- `assert Path("file").exists()` as the only assertion
- `assert "keyword" in file.read_text()` as the only assertion
- Tests that check documentation content
- Tests that count files or verify directory structure
- `--cov=tests` (self-coverage)
- Any test that passes without `helm` or `kubectl` invoked

Coverage is not a metric here. Quality = `helm lint` passes + `helm template` renders + security assertions pass.

### VI. Conventional Commits + No WIP

- Format: `feat(chart):`, `fix(chart):`, `docs:`, `test:`, `chore:`, `refactor:`, `style:`, `perf:`, `ci:`, `build:`, `revert:`.
- No WIP commits.
- Prefer small commits that map to a single feature or review fix.
- `dev` is the working branch; `main` is the release branch.

### VII. Demo-Protection Boy Scout Rule

Every touched file must be left better than it was — no regressions, no half-done edits. When unclear, ask before implementing (clarify over assume). When doing something, verify it doesn't contradict existing solutions, presets, or docs.

## Consumers & Invariants (NON-NEGOTIABLE)

This repo has two consumer classes; all updates must respect both:

- **Primary consumer (S7 team)** — uses the repo as the internal analytics platform; technical constraints below are invariants.
- **OSS consumers** — consume the repo as open-source charts. **Public values schema and preset names MUST stay backward-compatible**; breaking changes require a chart major version bump + migration notes.

### Product invariants (updates must NOT break these)

| # | Invariant | Anchor |
|---|-----------|--------|
| 1 | **Spark 3.5.7 pinned** on custom source build (Hadoop 3.4.2 + AWS SDK v2). Do not bump Spark 3.5.x line without explicit decision. | `charts/spark-3.5/`, `docker/spark-custom/Dockerfile.3.5.7` |
| 2 | **Monitoring + profiling of Airflow + Spark jobs in Grafana** (dashboards, PodMonitor/ServiceMonitor, statsd-exporter, S3A metrics). | `charts/observability-demo/`, `charts/spark-3.5/templates/monitoring/` |
| 3 | **Apache Iceberg** support (image variants + presets) | image pyramid `iceberg` axis |
| 4 | **GPU / NVIDIA RAPIDS** support (CUDA images + presets + DCGM dashboard) | image pyramid `gpu` axis |
| 5 | **Apache Celeborn** disaggregated shuffle (ADR-0005) | `charts/spark-3.5/values.yaml` celeborn block |
| 6 | **OpenLineage** (Marquez backend + Airflow provider + Spark listener + Jaeger trace correlation) | `charts/openlineage/`, F30 |
| 7 | **MLflow** experiment tracking (optional subchart) | `charts/spark-standalone` subchart |
| 8 | **Spark Connect** as primary access model (gRPC server + dynamic K8s executors) | `charts/spark-3.5/charts/spark-connect` |
| 9 | **MinIO / S3-compatible** storage as default backend | `charts/values-common.yaml`, presets |
| 10 | **OpenShift** compatibility (Routes, PSS `restricted`, SCC) | presets, security tests |

### Active backlog (real wants, NOT deferred ideas)

These are active requirements tracked as future specs, to be considered during upgrades:

- **SLA/SLO**: 99.9% Spark-Connect availability, RTO < 30 min, RPO < 1 h, MTTR < 30 min (`docs/drafts/feature-production-operations.md`, WS-018-04/07).
- **Cost attribution**: per-job / per-team + budget alerts in Grafana (WS-018-10/11).
- **Job-level CI/CD**: validate → promote → rollback with data-quality gates (WS-018-08/09).
- **HA for Spark Standalone Master** (ADR-0001) — verify chart support; relevant to Spark Operator migration.

## Additional Constraints

- **Shell scripts**: must pass `shellcheck -S warning`. Use `set -euo pipefail`.
- **CI**: no `|| true` on lint or test steps; no `continue-on-error: true` on blocking jobs. CI must fail fast on helm lint errors, template render failures, security violations.
- **Image pyramid**: `get_runtime_image(spark_version, gpu, iceberg)` maps to runtime image tags. Adding a new Spark version requires updating this mapping AND rebuilding all required variants.
- **Pre-commit**: all commits pass `pre-commit run --all-files` (ruff, black, mypy, shellcheck, conventional-commits).

## Development Workflow

Spec-Driven Development via GitHub spec-kit:

1. `/speckit.specify` → define what + why (requirements, user stories)
2. (optional) `/speckit.clarify` → resolve ambiguity before plan
3. `/speckit.plan` → technical implementation plan
4. (optional) `/speckit.checklist` → quality checklist
5. `/speckit.tasks` → actionable, dependency-ordered task list
6. `/speckit.analyze` → cross-artifact consistency check (NON-NEGOTIABLE before implement)
7. `/speckit.implement` → execute tasks
8. `/speckit.taskstoissues` → publish to GitHub Issues for tracking

Each feature lives under `specs/<feature-name>/` with `spec.md`, `plan.md`, `tasks.md`.

## Quality Gates

| Gate | Requirement |
|------|-------------|
| **AI-Readiness** | Files < 200 LOC, CC < 10, type hints |
| **Error Handling** | No `except: pass`, no bare exceptions |
| **No TODOs** | All tasks completed or tracked as new spec |
| **Helm Lint** | All modified charts pass `helm lint` |
| **Helm Template** | All modified charts render with typical values |
| **Security** | No hardcoded secrets; PSS `restricted` compatible when enabled |
| **Demo Health** | `./scripts/check-demo-health.sh` exits 0 |
| **Pre-commit** | `pre-commit run --all-files` exits 0 |

## Governance

- This constitution supersedes ad-hoc decisions and is the source of truth for project invariants.
- Amendments require: PR with diff, justification, ratification date update below.
- Conflict resolution: constitution > `.cursorrules` > `PROJECT_CONVENTIONS.md` > ad-hoc.
- Historical WS archive (read-only): `docs/archive/sdp-workstreams/`. New work must not be added there.
- Beads tracker (`.beads/`, `bd` CLI) is **frozen**. New issues go through spec-kit → GitHub Issues.

**Version**: 1.1.0 | **Ratified**: 2026-06-14 | **Last Amended**: 2026-06-17

### Amendment Log

- **v1.1.0 (2026-06-17)**: Added "Consumers & Invariants" section. Codifies two consumer classes (S7 primary + OSS), 10 product invariants (Spark 3.5.7 pin, Airflow/Spark Grafana monitoring+profiling, Iceberg, GPU/RAPIDS, Celeborn, OpenLineage, MLflow, Spark Connect, MinIO, OpenShift), and 4 active backlog wants (SLA/SLO, cost attribution, job CI/CD, HA Master). Justification: customer requirements were scattered across `docs/drafts/` and `docs/archive/` with no single source of truth, risking silent breakage during version upgrades.
