# Project Conventions: `spark_k8s`

This repository is primarily **Helm charts + Kubernetes manifests + bash scripts** for running Apache Spark
in Kubernetes (Minikube/k3s and OpenShift-like constraints).

These conventions complement `PROTOCOL.md`.

---

## Language & Communication

- **Docs**: Russian is OK, but keep key terms in English too (PSS, SCC, Spark Standalone, Spark Connect).
- **Commands**: bash snippets should be copy-pastable.

---

## Repo Structure

- **Charts**: `charts/*`
- **Docs (SDP)**: `docs/` (drafts, workstreams, ADRs, issues, UAT)
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
  - If a component uses `s3a://<bucket>/<prefix>`, the init job must ensure the bucket (and required prefix “dir marker” if needed) exists.

---

## Testing & “Coverage” Policy (Helm Repo)

This repo does not have Python unit tests where code coverage makes sense.

For SDP gates, treat the following as **the required test suite**:

- **Static**:
  - `helm lint charts/spark-standalone`
  - `helm lint charts/spark-platform`
- **Render sanity** (must succeed):
  - `helm template ...` for typical values profiles
- **Runtime smoke (Minikube/k3s)**:
  - `scripts/test-spark-standalone.sh <ns> <release>`
  - `scripts/test-prodlike-airflow.sh <ns> <release>`
  - `scripts/test-sa-prodlike-all.sh <ns> <release>`

If any smoke test fails → **equivalent to regression failure (BLOCKING)**.

---

## Git Workflow

- **Commit format**: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).
- **No WIP commits**.
- Prefer small commits that map to a WS or a single review fix.

---

## Documentation Requirements (SDP)

- Completed WS files must live in `docs/workstreams/completed/`.
- Each completed WS must end with:
  - **Execution Report**
  - **Review Result** (APPROVED / CHANGES REQUESTED)
- After feature approval, add a UAT guide: `docs/uat/UAT-F01-spark-standalone.md`.

