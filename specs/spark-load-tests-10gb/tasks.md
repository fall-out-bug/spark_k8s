---
description: "Task list for Spark Load Tests with 10GB NYC Taxi"
---

# Tasks: Spark Load Tests with 10GB NYC Taxi

**Input**: Design documents from `/specs/spark-load-tests-10gb/`

**Prerequisites**: plan.md (required), spec.md (required), MinIO + Spark History Server deployed

**Organization**: Tasks grouped by user story (US1 = pipeline, US2 = observability, US3 = report). Run `/speckit.tasks` to regenerate.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, or US3

## US1 — Full Pipeline on 10GB Parquet (P1)

- [ ] T001 [US1] Create `scripts/tests/load/prepare-nyc-taxi-data.sh` — download Yellow Taxi parquet (12-18 months), upload to MinIO bucket `raw-data`. Verify size ~10GB.
- [ ] T002 [US1] Create `scripts/tests/load/spark-35-load-test.py` — PySpark job with 5 operations (Read → GroupBy → Join → Window → Write). Capture per-stage metrics to JSON.
- [ ] T003 [US1] [P] Write Helm values file for `jupyter-connect-k8s-3.5.7` scenario if missing
- [ ] T004 [US1] [P] Write Helm values file for `jupyter-connect-standalone-3.5.7` scenario if missing
- [ ] T005 [US1] [P] Write Helm values file for `airflow-connect-k8s-3.5.7` scenario
- [ ] T006 [US1] [P] Write Helm values file for `airflow-connect-standalone-3.5.7` scenario
- [ ] T007 [US1] Create `scripts/tests/load/run-load-tests.sh` orchestrator — iterate 4 scenarios, capture exit codes + metrics JSON, exit non-zero on any failure
- [ ] T008 [US1] Run `helm lint charts/spark-3.5` and `helm template` for each scenario values file
- [ ] T009 [US1] E2E test: deploy `jupyter-connect-k8s-3.5.7`, run pipeline, assert exit 0 and 5 operations logged
- [ ] T010 [US1] [P] E2E test: deploy `jupyter-connect-standalone-3.5.7`, run pipeline, assert
- [ ] T011 [US1] [P] E2E test: deploy `airflow-connect-k8s-3.5.7`, run spark-submit, assert
- [ ] T012 [US1] [P] E2E test: deploy `airflow-connect-standalone-3.5.7`, run spark-submit, assert

## US2 — Observable Metrics Under Load (P2)

- [ ] T013 [US2] Verify event log written to `s3a://spark-logs/3.5.7/events/` after each scenario
- [ ] T014 [US2] Verify Spark History Server reads event log and renders job/stage UI
- [ ] T015 [US2] Assert Grafana Spark Overview shows executor count > 0, jobs rate > 0 during pipeline
- [ ] T016 [US2] [P] Assert Grafana Executor Metrics shows per-executor memory/cores/tasks
- [ ] T017 [US2] [P] Assert Grafana Job Performance shows duration percentiles + shuffle throughput
- [ ] T018 [US2] For `jupyter-connect-k8s-3.5.7` only: assert dynamic allocation observed (executor count grows then shrinks after idle)

## US3 — Comparative Report (P3)

- [ ] T019 [US3] Create `scripts/tests/load/report-template.md` with table skeleton (4 scenarios × 5 operations × {time, peak mem, shuffle r/w, GC})
- [ ] T020 [US3] Write `scripts/tests/load/generate-report.py` — consumes metrics JSON from each scenario, fills report template
- [ ] T021 [US3] Generate `docs/reports/F25-load-test-report.md` from collected metrics
- [ ] T022 [US3] Add `docs/reports/F25-load-test-report.md` to README "Reports" section

## Quality Gates

- [ ] T023 `helm lint charts/spark-3.5` passes
- [ ] T024 `pre-commit run --all-files` passes
- [ ] T025 `./scripts/check-demo-health.sh` passes pre/post
- [ ] T026 `pytest tests/integration/ -q` passes
- [ ] T027 Conventional commit messages on all PRs

## Demo Protection

- [ ] T028 Before each scenario deploy: `./scripts/check-demo-health.sh` exit 0
- [ ] T029 After each scenario: `./scripts/restore-demo.sh` if health broken
- [ ] T030 Final: `./scripts/check-demo-health.sh` exit 0
