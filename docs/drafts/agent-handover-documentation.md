# Documentation Handoff for Agents

This handoff is for agents working on documentation updates, testing reports, and user-facing guides.

---

## Scope

Use this guide when you need to:
- update documentation with new test results
- summarize config changes
- publish validation/QA outcomes
- edit guides (EN/RU) with verified behavior

---

## Sources of Truth

Use these files as primary references:
- **E2E matrix results:** `docs/testing/F06-e2e-matrix-report.md`
- **UAT summary:** `docs/uat/e2e-matrix-results.md`
- **Feature testing reports:** `docs/testing/`
- **Issues log:** `docs/issues/`
- **Workstreams:** `docs/workstreams/` (status + acceptance criteria)

If you need to document configs or behavior, verify it in:
- Helm charts: `charts/`
- Docker images: `docker/`
- Test scripts: `scripts/`

---

## Where to Put Updates

Pick the target based on content type:

- **Release/summary:** `docs/testing/` and `docs/uat/`
- **User guides:** `docs/guides/en/` and `docs/guides/ru/`
- **Design/decisions:** `docs/adr/`
- **Issues/bugs:** `docs/issues/`
- **Draft planning:** `docs/drafts/`

When adding a new report, keep filenames consistent:
- `docs/testing/Fxx-<short-title>.md`
- `docs/uat/UAT-<feature>.md`

---

## Required Content in Test Reports

Every test report should include:
- **Summary** (pass/fail + scope)
- **Environment** (cluster + images + versions)
- **Matrix** (what combinations ran)
- **Parameters** (SMOKE, SPARK_ROWS, SETUP/CLEANUP)
- **Results** (explicit PASS/FAIL)
- **Notes** (warnings, retries, known flakes)
- **Config deltas** (what changed to make tests pass)

Use concise tables where possible.

---

## Config and Fixes to Capture

When writing docs, ensure the following recent changes are reflected:
- Spark Connect (3.5) standalone driver host now uses the `spark-connect` service FQDN.
- `SPARK_DRIVER_HOST` is injected for Spark Connect standalone mode.
- Airflow Connect tests keep KubernetesExecutor worker pods for log collection.
- Spark Operator chart supports `crds.create`, tests set it to `false`.
- Spark Operator DAG for 4.1 increases Kubernetes client timeouts.

Reference the full details in `docs/testing/F06-e2e-matrix-report.md`.

---

## Common Pitfalls

- **K8s submit (client mode):** driver pod can exit quickly → metrics may be unavailable.
- **Operator driver metrics:** can be flaky on minikube; treat as warning if the rest passes.
- **Minikube apiserver:** may stop under load; rerun tests after `minikube start`.

Make sure these are called out as warnings, not silent omissions.

---

## Templates

You can reuse `templates/uat-guide.md` for UAT docs and `templates/release-notes.md`
for release summaries.

---

## Quick Validation Checklist

- Reports include exact versions (Spark, operator, images).
- Pass/fail is explicit per configuration.
- Config deltas are listed (not implied).
- No TODOs; use follow-up workstreams instead.

---

## Open Items to Watch

If updating docs, cross-check these workstreams/issues for current status:
- `docs/workstreams/backlog/WS-022-04-runtime-tests-connect-backends.md`
- `docs/workstreams/backlog/WS-020-17-integration-tests.md`
- `docs/issues/ISSUE-017-spark-41-properties-file-order.md`

---

## Contact / Context

This handoff aligns with the current E2E matrix execution run on 2026-01-25.
All results and configs are consolidated in `docs/testing/F06-e2e-matrix-report.md`.

