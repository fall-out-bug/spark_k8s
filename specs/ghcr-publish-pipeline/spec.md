---
feature: ghcr-publish-pipeline
status: draft
created: 2026-06-17
---

# Spec: GHCR Publish Pipeline

## Problem

The repo's Helm charts reference custom images hosted at
`ghcr.io/fall-out-bug/spark-k8s-spark-custom` and `ghcr.io/fall-out-bug/spark-k8s-jupyter-spark`,
but **no CI pipeline publishes these images**. `ci-docker.yml` only builds images
with `--no-push`. Verification (`gh api /user/packages?package_type=container`)
confirms zero packages exist in the GHCR namespace.

Consequence: every chart scenario that points at a `ghcr.io/...` image will
`ImagePullBackOff` for any consumer who hasn't built the image locally. This
directly blocks the Spark 4.1.1 migration (GAP-1 in PR #14) and undermines the
OSS-consumer contract (constitution v1.1.0: "Public values schema and preset
names MUST stay backward-compatible" — implies the referenced images must exist).

## Goal

A CI pipeline that publishes all custom runtime images to GHCR so that `helm install`
of any chart scenario works out-of-the-box for OSS consumers, with no local image build.

## Scope

### In scope

1. Publish these images to `ghcr.io/fall-out-bug/`:
   - `spark-k8s-spark-custom:<version>` for Spark `3.5.7`, `4.1.0`, `4.1.1`
     (custom Hadoop 3.4.2 + AWS SDK v2 builds, require pre-built `dist/*.tgz`)
   - `spark-k8s-jupyter-spark:<major>-<full>` for the matching Spark versions
     (e.g. `4.1-4.1.1`, `3.5-3.5.7`)
2. Tagging strategy: version tags (immutable per release) + `latest`-style moving tags
   for the active dev version.
3. Trigger: on tag push (`v*`) for releases; manual `workflow_dispatch` for ad-hoc
   builds (mirrors `build-spark-dist.yml` pattern).
4. `GITHUB_TOKEN` with `packages: write`; images published to the org/user namespace.
5. Build caching to avoid 30+ min Maven rebuilds on every run (reuse `dist` artifacts).

### Out of scope (explicitly deferred)

- GPU variant images (`4.1.0-gpu`, etc.) — separate Dockerfile/build matrix; tracked
  as invariant #4, will be a follow-up spec once the base pipeline lands.
- Airflow, Hive, jupyterhub, optional images — these use different registries/names
  in charts (`spark-k8s/airflow`, `spark-k8s/hive`); out of scope until referenced via GHCR.
- Multi-arch builds (arm64) — self-hosted runner is amd64-only for now.
- Image signing / SBOM (cosign, syft) — future hardening, separate spec.

## User stories

### US1 — OSS consumer pulls working images (P1)

**As** an OSS consumer cloning this repo,
**I want** `helm install` of a default scenario to pull existing images,
**so that** I can run the chart without building custom images from source.

**AC1:** After pipeline runs, `docker pull ghcr.io/fall-out-bug/spark-k8s-spark-custom:3.5.7`
succeeds.
**AC2:** `docker pull ghcr.io/fall-out-bug/spark-k8s-spark-custom:4.1.1` succeeds.
**AC3:** `docker pull ghcr.io/fall-out-bug/spark-k8s-jupyter-spark:4.1-4.1.1` succeeds.
**AC4:** Images are publicly readable (no auth needed to pull).

### US2 — Maintainer publishes on release (P2)

**As** a maintainer,
**I want** pushing a `v*` tag to publish all images automatically,
**so that** releases ship reproducible images without manual steps.

**AC5:** `git tag v0.2.0 && git push --tags` triggers publish of all in-scope images.
**AC6:** Published tags are immutable (re-publishing same tag fails, not overwrites).

### US3 — Fast rebuilds (P2)

**As** a maintainer,
**I want** rebuilds to reuse cached Spark distributions,
**so that** a fix doesn't require a 30+ min Maven compile.

**AC7:** A `workflow_dispatch` run with "rebuild dist: no" downloads the existing
dist artifact and skips Maven.

## Risks

- **R1:** Spark dist build is 30+ min on self-hosted runner; parallel matrix may
  saturate the runner. Mitigation: sequential or limited concurrency.
- **R2:** `GITHUB_TOKEN` `packages: write` is org-wide; scoped to this repo only.
- **R3:** GPU image dependency on CUDA base layers — excluded (out of scope), but
  must not accidentally break when GPU Dockerfile references change.
- **R4:** Public visibility of packages defaults to private on first push; needs
  an explicit `gh api` call or org setting to set public (AC4).

## References

- Current (broken) state: `docs/reports/spark41-celeborn-bump-2026-06-17.md` GAP-1
- Build infra: `scripts/build-spark-dist.sh`, `.github/workflows/build-spark-dist.yml`,
  `.github/workflows/ci-docker.yml`
- Constitution invariants: `specs/_constitution.md` §Consumers & Invariants
