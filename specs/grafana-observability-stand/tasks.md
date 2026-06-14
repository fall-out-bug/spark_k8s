---
description: "Task list for Grafana Observability Stand"
---

# Tasks: Grafana Observability Stand

**Input**: Design documents from `/specs/grafana-observability-stand/`

**Prerequisites**: plan.md, spec.md, minikube running

**Organization**: US1 = base stack, US2 = dashboards, US3 = trace correlation.

## US1 — Full Observability Stack Live (P1)

- [ ] T001 [US1] Verify minikube running with 6 CPU / 16GB / 50GB profile
- [ ] T002 [US1] Run existing `scripts/tests/minikube/deploy-observability.sh` as baseline; capture failures
- [ ] T003 [US1] Inspect `charts/observability-demo/values-demo.yaml` — note what's enabled/disabled
- [ ] T004 [US1] Create `scripts/deploy-observability-stand.sh` orchestrator: minikube check → deploy spark-infra → deploy observability-demo → wait for Ready → AC1-AC2
- [ ] T005 [US1] Create `charts/observability-demo/templates/servicemonitor-minio.yaml` — scrape MinIO `/minio/v2/metrics/bucket`
- [ ] T006 [US1] Generate MinIO Prometheus bearer token via `mc admin prometheus generate`; inject into ServiceMonitor secret
- [ ] T007 [US1] Create `charts/observability-demo/templates/servicemonitor-airflow-statsd.yaml`
- [ ] T008 [US1] Enable Airflow `statsd.enabled: true` in values-demo.yaml
- [ ] T009 [US1] Verify all expected pods `Ready` (kubectl wait deployments)
- [ ] T010 [US1] Verify Grafana URL reachable: `minikube service observability-demo-grafana -n observability --url`
- [ ] T011 [US1] Verify Prometheus `/api/v1/targets` shows all UP
- [ ] T012 [US1] Verify Loki LogQL returns Spark driver logs (last 5 min)

## US2 — Reference Dashboards Imported (P2)

- [ ] T013 [US2] Download and commit dashboard #7890 (Spark Performance Metrics) → `charts/observability/grafana/dashboards/spark-jvm-performance.json`
- [ ] T014 [US2] [P] Download #7727 (JVM Overview) → `jvm-overview.json`
- [ ] T015 [US2] [P] Download #23032 (Spark-Operator Scale) → `spark-operator-scale.json`
- [ ] T016 [US2] [P] Download #12239 (DCGM Exporter) → `dcgm-exporter.json`
- [ ] T017 [US2] [P] Download #19237 (MinIO Bucket) → `minio-bucket.json`
- [ ] T018 [US2] [P] Download #20994 (Airflow Cluster) → `airflow-cluster.json`
- [ ] T019 [US2] [P] Download #14451 (Airflow StatsD) → `airflow-statsd.json`
- [ ] T020 [US2] Create `charts/observability-demo/templates/dashboards-configmap.yaml` wrapping the 7 new JSONs for Grafana sidecar import
- [ ] T021 [US2] Verify dashboards visible in Grafana UI (AC8)
- [ ] T022 [US2] Verify no "datasource not found" errors (AC9)
- [ ] T023 [US2] Trigger sample Spark job, verify live data on at least one panel per dashboard (AC10)

## US3 — End-to-End Trace Correlation (P3)

- [ ] T024 [US3] Add `apache-airflow-providers-openlineage` to Airflow requirements
- [ ] T025 [US3] Configure OpenLineage transport in `airflow.cfg` (point to OTel collector or Marquez)
- [ ] T026 [US3] Verify Airflow scheduler starts without OpenLineage errors (AC11)
- [ ] T027 [US3] Add OpenLineage Spark integration via `--packages io.openlineage:openlineage-spark_2.12:<ver>` to spark-submit template
- [ ] T028 [US3] Trigger Airflow DAG that submits Spark job, verify ParentRunFacet in emitted RunEvent (AC12)
- [ ] T029 [US3] Verify Jaeger UI shows trace containing both DAG task + Spark driver spans (AC13)

## Verification + Docs

- [ ] T030 Create `scripts/verify-observability-stand.sh` — runs AC1-AC13 checks, exits non-zero on failure
- [ ] T031 Run `./scripts/check-demo-health.sh` — MUST pass (regression gate)
- [ ] T032 Run `helm lint charts/observability-demo` — MUST pass
- [ ] T033 Run `pytest tests/integration/test_observability_*.py -q` — MUST pass
- [ ] T034 Update `specs/grafana-observability-stand/spec.md` acceptance criteria checkboxes
- [ ] T035 Update `docs/guides/{en,ru}/quick-reference.md` with stand deploy commands
- [ ] T036 Commit conventional commits per task group; open PR

## Out of Scope (deferred)

- DCGM on actual GPU hardware (structural only on CPU minikube)
- AWS S3 CloudWatch exporter (migration path)
- Lightbend/Datadog commercial integrations
- Production persistent storage
- Multi-cluster federation
