# Project Conventions: `spark_k8s`

This repository is primarily **Helm charts + Kubernetes manifests + bash scripts** for running Apache Spark
in Kubernetes (Minikube/k3s and OpenShift-like constraints).

These conventions complement the project constitution at `specs/_constitution.md`.

---

## Language & Communication

- **Docs**: Russian is OK, but keep key terms in English too (PSS, SCC, Spark Standalone, Spark Connect).
- **Commands**: bash snippets should be copy-pastable.

---

## Repo Structure

- **Charts**: `charts/*`
- **Specs (OpenSpec)**: `openspec/` (current specs + in-flight changes); legacy `specs/` kept as reference
- **Docs**: `docs/` (guides, operations, recipes, archive of legacy workstreams)
- **Scripts**: `scripts/` (idempotent smoke/E2E helpers)
- **Docker images**: `docker/` (Spark/Jupyter/etc)

---

## Helm Chart Conventions

- **No hardcoded secrets in templates**:
  - Use `Secret` (`stringData`) and reference via `envFrom.secretRef` or `valueFrom.secretKeyRef`.
  - Defaults in `values.yaml` may contain *local-only* example creds; MUST be documented as such.
- **ConfigMaps**:
  - Large embedded payloads (DAGs, SQL, configs) go under chart `files/` and are included via `.Files.Get`.
  - Keep templates small (**target <200 LOC**).
- **Naming**:
  - Use `{{ include "<chart>.fullname" . }}` for resource names.
  - Labels: `app.kubernetes.io/*` via `_helpers.tpl`.
- **Security**:
  - When `security.podSecurityStandards=true`, templates must be compatible with PSS `restricted`:
    - `runAsNonRoot`, `seccompProfile: RuntimeDefault`, drop all caps, `allowPrivilegeEscalation=false`
    - avoid `hostPath`, `hostPort`, `privileged`
    - mount writable paths via `emptyDir`/PVC (never rely on writing into image FS)
- **MinIO buckets**:
  - If a component uses `s3a://<bucket>/<prefix>`, the init job must ensure the bucket (and required prefix "dir marker" if needed) exists.

---

## Testing & "Coverage" Policy (Helm Repo)

This repo does not have Python unit tests where code coverage makes sense.

For quality gates, treat the following as **the required test suite**:

- **Static**:
  - `helm lint charts/spark-3.5`
  - `helm lint charts/spark-4.1`
  - `helm lint charts/spark-base`
- **Render sanity** (must succeed):
  - `helm template ...` for typical values profiles
- **Runtime smoke (Minikube/k3s)**:
  - `./scripts/check-demo-health.sh`
  - Matrix runners under `scripts/tests/smoke/` and `scripts/tests/load/`

If any smoke test fails → **equivalent to regression failure (BLOCKING)**.

---

## Git Workflow

- **Commit format**: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).
- **No WIP commits**.
- Prefer small commits that map to a single feature or review fix.

---

## Documentation Requirements (OpenSpec)

- Feature work is modeled as changes under `openspec/changes/<id>/` (proposal, tasks, delta specs).
- Workflow: `/opsx:new` → `/opsx:apply` → `/opsx:verify` → `/opsx:archive`.
- Project principles: `specs/_constitution.md`.
- Legacy spec-kit specs under `specs/` are reference only (not for new work).
- Historical WS archive (read-only provenance): `docs/archive/sdp-workstreams/`.
