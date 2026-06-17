---
description: "Task list for GHCR Publish Pipeline"
---

# Tasks: GHCR Publish Pipeline

**Input:** `spec.md`, `plan.md`
**Status legend:** `[x]` done · `[ ]` pending · `[BLOCKED]` pending + blocked

## US1 — OSS consumer pulls working images (P1)

- [ ] T001 [US1] Audit current image references in charts — confirm exact image:tag pairs that must exist (done in spec; re-verify before build)
- [ ] T002 [US1] Create `.github/workflows/publish-images.yml` skeleton with `workflow_dispatch` trigger + `spark_version` choice input (3.5.7 / 4.1.0 / 4.1.1)
- [ ] T003 [US1] Add `permissions: { contents: read, packages: write }` to the workflow
- [ ] T004 [US1] Implement dist-artifact download step (`actions/download-artifact@v4` by name `spark-dist-<version>`); fall back to error if missing (default `rebuild_dist=false`)
- [ ] T005 [US1] Implement `rebuild_dist=true` path: inline the Maven build from `build-spark-dist.yml` (or call the script)
- [ ] T006 [US1] Build `spark-custom:<ver>` from `docker/spark-custom/Dockerfile.<ver>` + tag `ghcr.io/fall-out-bug/spark-k8s-spark-custom:<ver>`
- [ ] T007 [US1] Build jupyter image + tag `ghcr.io/fall-out-bug/spark-k8s-jupyter-spark:<major>-<ver>` (use `docker/jupyter-4.1/Dockerfile` for 4.x, `docker/jupyter/Dockerfile` for 3.5.x)
- [ ] T008 [US1] Add `docker login ghcr.io -u ${{ github.actor }} -p ${{ secrets.GITHUB_TOKEN }}`
- [ ] T009 [US1] Push both images; verify exit 0
- [ ] T010 [US1] Validate AC1-AC3: `docker pull` each published tag after a manual dispatch

## US2 — Maintainer publishes on release (P2)

- [ ] T011 [US2] Add `push: tags: ['v*']` trigger that publishes all in-scope versions via matrix
- [ ] T012 [US2] Document tag immutability expectation; verify re-push behavior (AC6)

## US3 — Fast rebuilds (P2)

- [ ] T013 [US3] Verify dist artifact reuse works end-to-end (AC7): dispatch with `rebuild_dist=false`, confirm Maven is skipped

## ci-docker.yml cleanup (GAP-3)

- [ ] T014 Add 4.1.1 build jobs to `ci-docker.yml` (mirror existing 4.1.0 jobs) — keep no-push
- [ ] T015 Verify `ci-docker.yml` passes after adding 4.1.1 (self-hosted runner)

## Docs

- [ ] T016 Create `docs/operations/image-publishing.md` — runbook: dispatch workflow, set package public, rollback/re-tag, dist cache strategy
- [ ] T017 Add note to chart READMEs: "images auto-published to GHCR; for local builds see docs/operations/image-publishing.md"

## Quality gates

- [ ] T018 `pre-commit run --all-files` passes (workflow YAML is valid, shellcheck clean)
- [ ] T019 Manual `workflow_dispatch` for 4.1.1 succeeds and images are pullable
- [ ] T020 `helm template charts/spark-4.1 -f charts/spark-4.1/jupyter-connect-k8s-4.1.1.yaml` references now-existing image (resolved by T010)
- [ ] T021 Resolve GAP-1 in `docs/reports/spark41-celeborn-bump-2026-06-17.md` (mark resolved, link to this spec)

## Open questions (blocking T002 scope)

- [ ] Q1 Confirm self-hosted runner is the only runner (affects matrix concurrency)
- [ ] Q2 Confirm first-publish visibility handling (manual flip OK?)
