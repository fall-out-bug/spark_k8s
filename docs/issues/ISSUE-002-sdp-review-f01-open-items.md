## ISSUE-002: SDP review — F01 open items / follow-ups

### Status

Closed (WS-001-12 completed)

### Summary

During strict SDP review of **F01: Spark Standalone Helm Chart**, the implementation is functionally validated
(Spark E2E + Airflow prod-like DAGs), but the feature is **not fully complete** because one workstream remains in backlog.

### Blockers (for F01 APPROVED)

1. **WS-001-12 (Shared Values Compatibility) is still backlog**
   - Impact: By SDP rules, the feature cannot be marked fully complete/approved while a WS in the feature remains pending.
   - Options:
     - Execute WS-001-12, then re-run `/review F01`
     - Or move WS-001-12 into a separate feature (if it is explicitly out of current scope)

### Non-blocking Improvements (recommended)

- Add a short “operator runbook” doc for local/prod-like flows (deploy + smoke scripts + common failures)
- Add CI job(s) for `helm lint` and a render smoke (`helm template`) for both charts

### Evidence (what is already green)

- `helm lint` for `charts/spark-standalone` passes
- Runtime smoke in `spark-sa-prodlike`:
  - `scripts/test-sa-prodlike-all.sh` passes (SparkPi + Airflow `example_bash_operator` + `spark_etl_synthetic`)

### Resolution

- WS-001-12 was executed and moved to `docs/workstreams/completed/WS-001-12-shared-values-compat.md`.

