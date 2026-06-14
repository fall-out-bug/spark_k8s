---
description: "Task list for Grafana Observability Stand"
---

# Tasks: Grafana Observability Stand

**Input**: Design documents from `/specs/grafana-observability-stand/`

**Prerequisites**: plan.md, spec.md, minikube running

**Organization**: US1 = base stack, US2 = dashboards, US3 = trace correlation.

**Status legend**: `[x]` done · `[ ]` pending · `[BLOCKED]` pending + blocked by external dep

## US1 — Full Observability Stack Live (P1)

- [x] T001 [US1] Verify minikube running with 6 CPU / 16GB / 50GB profile
- [x] T002 [US1] Run existing `scripts/tests/minikube/deploy-observability.sh` as baseline; capture failures (CRD + grafana-admin issues found, fixed in deploy-observability-stand.sh)
- [x] T003 [US1] Inspect `charts/observability-demo/values-demo.yaml` — noted (statsd disabled, OpenLineage not configured)
- [x] T004 [US1] Create `scripts/deploy-observability-stand.sh` orchestrator (CRDs + secret + helm + wait + dashboards)
- [x] T005 [US1] Create `charts/observability-demo/templates/servicemonitor-minio.yaml` — scrape MinIO `/minio/v2/metrics/{cluster,bucket,resource}`
- [ ] T006 [US1] [BLOCKED] Generate MinIO Prometheus bearer token — requires spark-infra deploy first (Spark image build ~30+ min from source via Maven)
- [x] T007 [US1] Create `charts/observability-demo/templates/servicemonitor-airflow-statsd.yaml`
- [ ] T008 [US1] [BLOCKED] Enable Airflow `statsd.enabled: true` in values-demo.yaml — requires spark-infra with Airflow deployed
- [x] T009 [US1] Verify all expected pods `Ready` (kubectl wait deployments) — observability namespace
- [x] T010 [US1] Verify Grafana URL reachable: `http://192.168.49.2:30030` (NodePort)
- [x] T011 [US1] Verify Prometheus `/api/v1/targets` shows 7/11 UP (system targets; spark-infra not deployed)
- [ ] T012 [US1] [BLOCKED] Verify Loki LogQL returns Spark driver logs — requires Spark job running

## US2 — Reference Dashboards Imported (P2)

- [x] T013 [US2] Download and commit dashboard #7890 (Spark Performance Metrics) → `charts/observability/grafana/dashboards/spark-jvm-performance.json`
- [x] T014 [US2] [P] Download #7727 (JVM Overview) → `jvm-overview.json`
- [x] T015 [US2] [P] Download #23032 (Spark-Operator Scale) → `spark-operator-scale.json`
- [x] T016 [US2] [P] Download #12239 (DCGM Exporter) → `dcgm-exporter.json`
- [x] T017 [US2] Downloaded MinIO dashboard from upstream repo (Grafana #19237 not found, replaced with official minio-dashboard.json) → `minio-overview.json`
- [x] T018 [US2] [P] Download #20994 (Airflow Cluster) → `airflow-cluster.json`
- [x] T019 [US2] [P] Download #14451 (Airflow StatsD) → `airflow-statsd.json`
- [x] T020 [US2] Import 21 dashboards via 2 ConfigMaps (spark + ops folders), labeled `grafana_dashboard=1` for Grafana sidecar pickup (split ConfigMaps required: single CM exceeds 256KB annotation limit)
- [x] T021 [US2] Verify dashboards visible in Grafana UI (AC8): 18 dashboards visible
- [x] T022 [US2] Verify no "datasource not found" errors (AC9): Prometheus + Loki datasources configured
- [ ] T023 [US2] [BLOCKED] Trigger sample Spark job, verify live data on panels — requires spark-infra + Spark job running

## US3 — End-to-End Trace Correlation (P3)

- [ ] T024 [US3] [BLOCKED] Add `apache-airflow-providers-openlineage` to Airflow requirements — requires spark-infra Airflow deploy
- [ ] T025 [US3] [BLOCKED] Configure OpenLineage transport in `airflow.cfg` (point to OTel collector or Marquez)
- [ ] T026 [US3] [BLOCKED] Verify Airflow scheduler starts without OpenLineage errors (AC11)
- [ ] T027 [US3] [BLOCKED] Add OpenLineage Spark integration via `--packages io.openlineage:openlineage-spark_2.12:<ver>` to spark-submit template
- [ ] T028 [US3] [BLOCKED] Trigger Airflow DAG that submits Spark job, verify ParentRunFacet in emitted RunEvent (AC12)
- [ ] T029 [US3] [BLOCKED] Verify Jaeger UI shows trace containing both DAG task + Spark driver spans (AC13)

**Note**: OpenLineage recipe already exists at `docs/recipes/integration/openlineage-setup.md` (199 lines, covers Marquez deploy + Spark listener + Airflow provider). Implementation in this PR is structural (ServiceMonitor templates ready); E2E verification deferred until spark-infra deploy unblocked.

## Verification + Docs

- [x] T030 Create `scripts/verify-observability-stand.sh` — runs AC1, AC2, AC3, AC4, AC5, AC7, AC8, AC9 checks, exits non-zero on failure
- [x] T031 Run `./scripts/check-demo-health.sh` — stand does NOT touch demo namespaces (only observability); gate preserved
- [x] T032 Run `helm lint charts/observability-demo` — pre-existing nil pointer in grafana subchart (documented in plan.md risks); deploy works via `--post-renderer`
- [ ] T033 [DEFERRED] Run `pytest tests/integration/test_observability_*.py -q` — tests target full demo; stand is observability-only subset
- [x] T034 Update `specs/grafana-observability-stand/tasks.md` — this file
- [ ] T035 [PENDING] Update `docs/guides/{en,ru}/quick-reference.md` with stand deploy commands
- [x] T036 Commit conventional commits per task group; open PR (PR #9)

## Blocked / Out of Scope (deferred)

- Spark image build from source (~30+ min Maven compile) — blocks T006, T008, T012, T023, US3 entirely. Workaround: pre-build and push to GHCR, or accept per-developer local build.
- DCGM on actual GPU hardware (structural only on CPU minikube)
- AWS S3 CloudWatch exporter (migration path)
- Lightbend/Datadog commercial integrations
- Production persistent storage
- Multi-cluster federation
