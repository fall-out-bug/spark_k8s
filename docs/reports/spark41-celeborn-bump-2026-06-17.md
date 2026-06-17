# Report: Spark 4.1.1 + Celeborn 0.6.3 bump (2026-06-17)

Branch: `chore/spark41-celeborn-bump`

## What changed

1. **Celeborn `0.6.1` → `0.6.3`** (patch bump, upstream image)
   - `charts/spark-3.5/values.yaml`
   - `charts/spark-4.1/values.yaml`
2. **Spark `4.1.0` → `4.1.1`** (code-side only — tags, comments, build scripts)
   - `charts/spark-4.1/Chart.yaml` (appVersion + description)
   - `charts/spark-4.1/values.yaml` (connect image ×2, jupyter image, comments)
   - `charts/spark-4.1/templates/NOTES.txt`
   - `charts/spark-4.1/templates/spark-connect.yaml` (jar name `spark-connect_2.13-4.1.1.jar`)
   - `charts/spark-4.1/templates/executor-pod-template-configmap.yaml` (label)
   - 5 scenario files `*-4.1.1.yaml` (tags were stale `4.1.0` — finished the migration)
   - 5 `values-scenario-*.yaml` + presets (plain spark-custom/jupyter tags)
   - `charts/spark-4.1/README.md` (badges, version block, examples)
   - `docker/spark-custom/build-and-load.sh` (VERSIONS array)
   - `docker/jupyter-4.1/Dockerfile` (`FROM apache/spark:4.1.1-python3`, `pyspark==4.1.1`)

## ⚠️ Known gaps after this PR (tracked, not silent)

### GAP-1: Spark 4.1.1 images NOT published to GHCR (BLOCKING for live 4.1 deployments)

The chart now references `ghcr.io/fall-out-bug/spark-k8s-spark-custom:4.1.1` and
`spark-k8s-jupyter:4.1-4.1.1`, but **no CI pipeline publishes images to GHCR**.
`.github/workflows/ci-docker.yml` builds images but every job is explicitly
"Build image (no push)" — there is no `docker push` / `packages: write` step
anywhere.

**Impact:** `helm install` of any `*-4.1.1.yaml` scenario will fail with
`ImagePullBackOff` until images are published. Spark 3.5.7 scenarios are
unaffected (assume pre-existing images).

**Resolution:** tracked as spec `ghcr-publish-pipeline` — add a publish job to
`ci-docker.yml` triggered on push to `main`/tags, parametrized by Spark version,
using `GITHUB_TOKEN` with `packages: write`. This is the P1 priority.

### GAP-2: GPU variant stays on `4.1.0-gpu` (invariant #4 — NOT broken, intentionally deferred)

GPU scenarios still reference `spark-custom:4.1.0-gpu` and `jupyter:4.1-4.1.0-gpu`:
- `charts/spark-4.1/presets/gpu-values.yaml`
- `charts/spark-4.1/values-scenario-airflow-gpu-connect-k8s.yaml`

**Reason:** GPU image is built from a separate `docker/spark-4.1/gpu/Dockerfile`
(`ARG VERSION=4.1.0-gpu`). There is no `4.1.1-gpu` Dockerfile/build path yet,
and bumping the tag without a matching image would break invariant #4 (GPU/RAPIDS).
GPU migration to 4.1.1 must be done together with a GPU image build + the GHCR
publish pipeline (GAP-1).

Build-path strings (`spark-4.1.0-bin-hadoop3/...` in extraLibraryPath) are
intentionally left as-is — they reference paths inside the compiled Spark
distribution and must match whatever the image was built with.

### GAP-3: `ci-docker.yml` still hardcodes 4.1.0 build jobs

`ci-docker.yml` has `build-dist-41` + `build-spark-41` jobs hardcoded to `4.1.0`.
Once GAP-1 (publish pipeline) lands, these jobs should be parametrized or
duplicated for 4.1.1. Out of scope for this code-only PR.

## Verification done

- `helm lint charts/spark-3.5` → 0 failures
- `helm lint charts/spark-4.1` → 0 failures
- `helm template spark-4.1-test charts/spark-4.1` → renders, `4.1.1` correctly
  substituted in executor label and `spark-connect_2.13-4.1.1.jar`

## Verification NOT done (requires live cluster + published images)

- Live deploy of 4.1.1 scenarios (blocked by GAP-1)
- `check-demo-health.sh` (demo not deployed this session; 3.5.7 pinned, unaffected)
