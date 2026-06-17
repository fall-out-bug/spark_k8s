---
feature: ghcr-publish-pipeline
status: draft
created: 2026-06-17
---

# Plan: GHCR Publish Pipeline

**Input:** `spec.md`

## Design decisions

### D1: Reuse existing `build-spark-dist.yml` for the dist artifact

The Spark distribution (`dist/*.tgz`) is the expensive part (30+ min Maven build).
`build-spark-dist.yml` already produces it as a 90-day-retained artifact. The publish
workflow will **download** this artifact instead of rebuilding. New `workflow_dispatch`
input `rebuild_dist` (default `false`) controls whether to rebuild.

### D2: Image list and tag mapping

Two images, mapped from Spark version:

| Spark ver | spark-custom tag | jupyter tag | Dockerfile |
|-----------|------------------|-------------|------------|
| 3.5.7 | `3.5.7` | `3.5-3.5.7` | `Dockerfile.3.5.7`, `docker/jupyter/Dockerfile` |
| 4.1.0 | `4.1.0` | `4.1-4.1.0` | `Dockerfile.4.1.0`, `docker/jupyter-4.1/Dockerfile` |
| 4.1.1 | `4.1.1` | `4.1-4.1.1` | `Dockerfile.4.1.1`, `docker/jupyter-4.1/Dockerfile` |

Wait — the jupyter Dockerfile split is messy (both `docker/jupyter/Dockerfile` and
`docker/jupyter-4.1/Dockerfile` exist). **Decision:** standardize on `docker/jupyter-4.1/Dockerfile`
for 4.x and `docker/jupyter/Dockerfile` for 3.5.x (matches current `jupyter-connect-k8s-iceberg-4.1.1.yaml`
which references the 4.1 image). Document the mapping in a single place in the workflow.

### D3: Trigger strategy

- `workflow_dispatch` with `spark_version` choice input (like `build-spark-dist.yml`)
  → publish single version. **Primary path for now** (manual, controlled).
- `push: tags: ['v*']` → publish all in-scope versions (AC5). Added but secondary.
- NO push on every commit to dev/main (too slow, would saturate runner).

### D4: Tagging

- Primary tag = Spark version (e.g. `4.1.1`) — immutable in spirit.
- **No `latest` moving tag initially** — adds confusion. Revisit if consumers ask.
- For immutable release tags (AC6), rely on GitHub's package settings (disable
  overwrite via org policy, or accept re-push overwrites for now and document).

### D5: Permissions and visibility

```yaml
permissions:
  contents: read
  packages: write
```
Uses built-in `GITHUB_TOKEN` (no extra secret). Package visibility: first push creates
private by default → a one-time `gh api --method PATCH /user/packages/container/.../{visibility}`
step OR document the manual flip. **Decision:** add a documentation note + a `workflow_dispatch`
step to set public; don't auto-publicize (org policy dependent).

### D6: Workflow location and structure

New file `.github/workflows/publish-images.yml` (do NOT modify `ci-docker.yml` — it
stays a fast lint+build-check gate). The publish workflow:

```
job: build-and-publish (matrix: spark_version)
  ├─ checkout
  ├─ download dist artifact (or rebuild if rebuild_dist=true)
  ├─ docker build spark-custom:<ver> + tag ghcr.io/...
  ├─ docker build jupyter:<major>-<ver> + tag ghcr.io/...
  ├─ docker login (GITHUB_TOKEN)
  ├─ docker push (both images)
  └─ (optional) set package public
```

Matrix runs in parallel for `3.5.7` / `4.1.0` / `4.1.1` — each is independent
(different dist artifacts, no shared state).

### D7: ci-docker.yml cleanup (GAP-3)

Add 4.1.1 to the build matrix of `ci-docker.yml` (currently hardcoded 4.1.0) so the
fast gate also covers 4.1.1. Keep it no-push (that's `publish-images.yml`'s job).

## Files to create/modify

| File | Action | Purpose |
|------|--------|---------|
| `.github/workflows/publish-images.yml` | **create** | The publish pipeline |
| `.github/workflows/ci-docker.yml` | modify | Add 4.1.1 to build matrix (GAP-3) |
| `docker/spark-custom/Makefile` | verify/modify | Ensure publish targets exist (if used) |
| `docs/operations/image-publishing.md` | create | Runbook: how to publish, visibility, rollback |
| `specs/ghcr-publish-pipeline/tasks.md` | create | Task breakdown |

## Open questions (resolve before implement)

- **Q1:** Is the self-hosted runner the only runner, or is there GH-hosted capacity?
  (Affects parallelism — self-hosted may serialize matrix jobs.)
- **Q2:** Should first publish also set packages public automatically, or manual?
  (Leaning manual + documented, per D5.)

## Risks revisited

- Maven saturation → matrix concurrency capped at 1-2.
- GITHUB_TOKEN scope → limited to this repo's packages; safe.
- Jupyter Dockerfile ambiguity → resolve by explicit path per version in workflow.
