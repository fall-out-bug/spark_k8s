# Image Publishing Runbook

How custom runtime images (`spark-custom`, `jupyter-spark`) get published to GHCR
so that `helm install` works out-of-the-box for OSS consumers.

## The two-image model

| Image | GHCR path | Tag format | Built from |
|-------|-----------|------------|------------|
| spark-custom | `ghcr.io/fall-out-bug/spark-k8s-spark-custom` | `<spark-version>` (e.g. `4.1.1`) | `docker/spark-custom/Dockerfile.<ver>` + pre-built `dist/*.tgz` |
| jupyter | `ghcr.io/fall-out-bug/spark-k8s-jupyter-spark` | `<major.minor>-<full>` (e.g. `4.1-4.1.1`) | `docker/jupyter-4.1/Dockerfile` (4.x) / `docker/jupyter/Dockerfile` (3.5.x) |

**Important:** `spark-custom` is NOT a plain Apache Spark image — it's compiled
from source with Hadoop 3.4.2 + AWS SDK v2 (invariant #1). Building it requires a
Spark distribution tarball produced by `scripts/build-spark-dist.sh`.

## Publishing a version (normal flow)

1. Ensure the Spark dist artifact exists. Run **Build Spark Distributions**
   workflow (`build-spark-dist.yml`) with the target version once; the artifact
   (`spark-dist-<ver>`) is retained 90 days.

2. Run **Publish Images** workflow (`publish-images.yml`) via `workflow_dispatch`:
   - `spark_version`: the version to publish
   - `rebuild_dist`: leave `false` (reuse artifact from step 1). Set `true` only
     to force a fresh 30+ min Maven build.

3. The workflow builds both images, logs into GHCR with `GITHUB_TOKEN`, and pushes.

4. **First-time only — set packages public.** GHCR creates packages as private by
   default. After the very first push of each image, make it public (required for
   anonymous/OSS pulls):

   ```bash
   gh api --method PATCH /user/packages/container/spark-k8s-spark-custom \
     -f visibility=public
   gh api --method PATCH /user/packages/container/spark-k8s-jupyter-spark \
     -f visibility=public
   ```

   (Use `/orgs/<org>/packages/...` if the namespace is an org, not a user.)

## Verifying

```bash
docker pull ghcr.io/fall-out-bug/spark-k8s-spark-custom:4.1.1
docker pull ghcr.io/fall-out-bug/spark-k8s-jupyter-spark:4.1-4.1.1
```

Both must succeed without authentication once packages are public (step 4).

## What is NOT published here

- **GPU variants** (`*-gpu`): separate Dockerfile + CUDA base layers. Tracked as
  invariant #4; will be added in a follow-up spec.
- **Airflow, Hive, jupyterhub, optional images**: use different names/registries
  in charts (`spark-k8s/airflow`, `spark-k8s/hive`). Not yet on GHCR.
- **CI build checks** (`ci-docker.yml`): this is a fast no-push gate that verifies
  Dockerfiles build. It never pushes — that is `publish-images.yml`'s job.

## Concurrency

A single self-hosted runner (`spark_k8s_wsl`) serves all workflows. The publish
workflow uses `concurrency: publish-images` to serialize — only one publish runs
at a time, preventing image-tag races.

## Rollback / re-tagging

GHCR does **not** enforce tag immutability by default. To "roll back" to a previous
build, re-run the publish workflow for that version (it overwrites the tag). For
audit-grade immutability, enable package tag protection in org settings (out of
current scope).

## Related

- Spec: `specs/ghcr-publish-pipeline/`
- Dist builder: `.github/workflows/build-spark-dist.yml`, `scripts/build-spark-dist.sh`
- Build gate: `.github/workflows/ci-docker.yml`
- Why this exists: `docs/reports/spark41-celeborn-bump-2026-06-17.md` GAP-1
