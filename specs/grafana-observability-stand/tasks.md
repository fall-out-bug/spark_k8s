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
- [x] T006 [US1] MinIO auth disabled via runtime patch (`MINIO_PROMETHEUS_AUTH_TYPE=public`) — no bearer token needed
- [x] T007 [US1] Create `charts/observability-demo/templates/servicemonitor-airflow-statsd.yaml`
- [x] T008 [US1] Statsd-exporter deployed as standalone Deployment + Airflow patched via env vars (`AIRFLOW__METRICS__STATSD_*`)
- [x] T009 [US1] Verify all expected pods `Ready` (kubectl wait deployments) — observability + spark-infra namespaces
- [x] T010 [US1] Verify Grafana URL reachable: `http://192.168.49.2:30030` (NodePort)
- [x] T011 [US1] Verify Prometheus `/api/v1/targets` shows 15 active (7 system + 4 spark-infra MinIO + 1 statsd + 3 spark-infra others)
- [x] T012 [US1] Verify Loki LogQL returns Spark driver logs — promtail deployed (helm install grafana/promtail), URL `http://observability-demo-loki.observability.svc.cluster.local:3100/loki/api/v1/push`, LogQL `{namespace="spark-infra"} |= "Spark"` returns driver pod logs (SparkContext lifecycle, executor shutdown). Initial 429 rate limit on backfill resolved by waiting.

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
- [x] T023 [US2] Verified live data on panels: MinIO bucket metrics (196 series), Airflow statsd (60 series incl DAG processing)

## US3 — End-to-End Trace Correlation (P3)

- [x] T024 [US3] `apache-airflow-providers-openlineage==2.3.0` installed in Airflow scheduler + webserver (runtime pip install; image rebuild deferred)
- [x] T025 [US3] OpenLineage transport configured via Airflow env vars → Marquez HTTP endpoint
- [x] T026 [US3] Airflow scheduler starts clean with provider loaded (no errors in logs)
- [x] T027 [US3] Spark OpenLineage listener via `--packages io.openlineage:openlineage-spark_2.12:1.29.0` + `--conf spark.extraListeners=io.openlineage.spark.agent.OpenLineageSparkListener` + `spark.openlineage.transport.{url,endpoint,type}` configs. DAG `spark_openlineage_demo.py` runs SparkPi with full lineage.
- [x] T028 [US3] Triggered DAG `spark_openlineage_demo` → Marquez received RunEvent in namespace `spark-infra-spark`, job `spark_pi` state COMPLETED, with ParentRunFacet linking DAG → task
- [ ] T029 [US3] [KNOWN ISSUE] Jaeger deployed (chart jaegertracing/jaeger v4.11.1, app v2.19.0), Airflow OTel configured (`AIRFLOW__TRACES__OTEL_ON=True`, `OTEL_HOST=jaeger.observability.svc.cluster.local`, ports 4317 gRPC + 4318 HTTP). Exporter connects but receives HTTP 500 from Jaeger OTLP/HTTP receiver. Direct curl to `:4318/v1/traces` returns OK with `{"partialSuccess":{}}` → Jaeger receiver functional, Airflow exporter protocol mismatch (likely payload encoding). Follow-up: switch to OTel Collector proxy, or upgrade Airflow, or debug Airflow opentelemetry-sdk payload format.

## Verification + Docs

- [x] T030 Create `scripts/verify-observability-stand.sh` — runs AC1, AC2, AC3, AC4, AC5, AC7, AC8, AC9 checks, exits non-zero on failure
- [x] T031 Run `./scripts/check-demo-health.sh` — stand does NOT touch demo namespaces (only observability); gate preserved
- [x] T032 Run `helm lint charts/observability-demo` — pre-existing nil pointer in grafana subchart (documented in plan.md risks); deploy works via `--post-renderer`
- [x] T033 Run `pytest tests/integration/test_observability_*.py -q` — 40/40 pass (alertmanager, demo, grafana, jaeger, loki, prometheus, spark_ui)
- [x] T034 Update `specs/grafana-observability-stand/tasks.md` — this file
- [x] T035 Update `docs/guides/{en,ru}/quick-reference.md` with stand deploy commands — added "Observability stand" section with full deploy sequence
- [x] T036 Commit conventional commits per task group; open PR (PR #9)

## Blocked / Out of Scope (deferred)

- Spark image build from source (~30+ min Maven compile) — blocks T006, T008, T012, T023, US3 entirely. Workaround: pre-build and push to GHCR, or accept per-developer local build.
- DCGM on actual GPU hardware (structural only on CPU minikube)
- AWS S3 CloudWatch exporter (migration path)
- Lightbend/Datadog commercial integrations
- Production persistent storage
- Multi-cluster federation
