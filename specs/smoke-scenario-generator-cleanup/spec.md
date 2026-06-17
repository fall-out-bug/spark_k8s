---
feature: smoke-scenario-generator-cleanup
status: draft (backlog skeleton)
created: 2026-06-17
---

# Spec: Smoke Scenario Generator Cleanup (SC2034 root cause)

## Problem

The smoke-test scenario generator (`scripts/tests/smoke/matrix/`, driven by
`smoke-matrix.yaml`) emits `IMAGE_REPOSITORY="spark-custom"` into **every**
generated scenario script under `scripts/tests/smoke/scenarios/`, even in the
~73 scenarios that never reference `$IMAGE_REPOSITORY`. This produces
`shellcheck SC2034` (variable appears unused) warnings across ~73 files.

As a result, `scripts/tests/smoke/scenarios/` is currently **excluded from
shellcheck** in `.pre-commit-config.yaml` (added 2026-06-17 during the
pre-commit autoupdate). This hides the debt rather than fixing the root cause.

`IMAGE_REPOSITORY` legitimately takes 3 distinct values depending on the
scenario image variant:
- `spark-custom` (default / CPU)
- `spark-custom-gpu` (GPU / RAPIDS, invariant #4)
- `spark-custom-iceberg` (Iceberg, invariant #3)

The GPU and Iceberg variants are always used where defined; only the plain
`spark-custom` default is over-emitted.

## Goal

The generator emits `IMAGE_REPOSITORY` (and any other per-scenario variable)
**only when the scenario body references it**. Once fixed and scenarios are
regenerated, the shellcheck exclude for `scripts/tests/smoke/scenarios/` can
be removed.

## Scope (preliminary)

### Likely in scope
- Audit the generator (`scripts/tests/smoke/matrix/`, `generate-smoke-doc.py`,
  `validate-smoke-matrix.py`, `smoke-matrix.yaml`) to find where
  `IMAGE_REPOSITORY` is emitted
- Make emission conditional on whether the scenario template body references it
- Regenerate all scenarios
- Verify shellcheck passes on `scripts/tests/smoke/scenarios/` with the exclude removed
- Remove the `.pre-commit-config.yaml` shellcheck exclude for this path

### Likely out of scope
- Other shellcheck codes (SC2218, SC1010, SC1083) that may appear once SC2034
  is resolved — handle as they surface during regeneration
- Restructuring the scenario template itself

## Open questions (before plan.md)

- Q1: Is `IMAGE_REPOSITORY` the only over-emitted variable, or are
  `IMAGE_TAG`, `SPARK_VERSION`, `APP_NAME` also over-emitted in some scenarios?
  (Quick audit: `grep -c '$VAR' file` for each variable across all scenarios.)
- Q2: Are the scenarios hand-edited after generation (which would make
  regeneration destructive), or purely generator-owned?
- Q3: Should the generator instead always emit and the scenarios always use
  (e.g. via a shared `common.sh` lookup), rather than conditional emission?

## References

- Exclude added: `.pre-commit-config.yaml` shellcheck hook (2026-06-17)
- Generator: `scripts/tests/smoke/matrix/`
- Matrix definition: `scripts/tests/smoke/matrix/smoke-matrix.yaml`
- Constitution: invariants #3 (Iceberg), #4 (GPU) — the image variants involved

## Next step

Resolve Q1-Q3 (especially Q2 — regeneration safety), then write `plan.md`.
