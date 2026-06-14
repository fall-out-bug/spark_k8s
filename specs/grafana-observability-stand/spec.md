# Feature Specification: Grafana Observability Stand (minikube, full stack)

**Feature Branch**: `feature/grafana-observability-stand`

**Created**: 2026-06-14

**Status**: Draft

**Source**: Implementation work after spec-kit migration. References: [docs/references/observability-references.md](../../docs/references/observability-references.md)

## User Scenarios & Testing

### User Story 1 - Full Observability Stack Live on Minikube (Priority: P1)

As a platform engineer, I want a minikube-resident observability stand that deploys Prometheus + Grafana + Loki + Jaeger + MinIO + Spark History + DCGM (GPU) + Airflow statsd + OpenLineage, so that I can validate end-to-end metric/log/trace flow for Spark + Airflow jobs without touching production.

**Why this priority**: Without this US, the repo's observability claims are unverified. All downstream demos (smoke matrix, load tests) depend on this stack.

**Test scenarios**:
- AC1: `./scripts/deploy-observability-stand.sh` exits 0 on fresh minikube
- AC2: All expected pods `Ready` in `observability` + `spark-infra` namespaces
- AC3: Grafana UI reachable at `minikube service observability-demo-grafana -n observability --url`
- AC4: Prometheus targets all UP (Prometheus → SparkHistory /metrics/prometheus, MinIO /minio/v2/metrics/bucket, Airflow statsd, DCGM)
- AC5: Loki ingests logs from Spark driver/executor pods (verified via LogQL query)
- AC6: Jaeger receives traces from Spark jobs (via OTel collector)
- AC7: At least 10 reference dashboards imported and visible in Grafana UI

### User Story 2 - Reference Dashboards Imported (Priority: P2)

As an SRE, I want the Grafana stand to ship with curated community dashboards (Spark JVM, Spark-Operator, DCGM GPU, MinIO bucket, Airflow statsd) so I can immediately observe Spark workloads without authoring dashboards from scratch.

**Why this priority**: Without curated dashboards, operators must build them by hand — friction that defeats the stand's purpose.

**Test scenarios**:
- AC8: Grafana dashboards list includes at minimum:
  - Spark Performance Metrics (#7890)
  - JVM Overview (#7727)
  - Spark-Operator Scale Test (#23032)
  - NVIDIA DCGM Exporter (#12239)
  - MinIO Bucket Dashboard (#19237)
  - Airflow Cluster Dashboard (#20994)
  - Airflow StatsD (#14451)
- AC9: Each imported dashboard renders without "datasource not found" errors
- AC10: At least one panel on each dashboard shows live data after a sample Spark job

### User Story 3 - End-to-End Trace Correlation (Priority: P3)

As a developer debugging a slow DAG, I want to click from an Airflow DAG run to the corresponding Spark application trace in Jaeger, so I can pinpoint the slow stage without manual ID correlation.

**Why this priority**: Demonstrates OpenLineage + OTel integration; nice-to-have but not blocking for stand usability.

**Test scenarios**:
- AC11: OpenLineage provider installed in Airflow
- AC12: Spark-submit from Airflow DAG emits OpenLineage RunEvent with ParentRunFacet linking DAG run
- AC13: Jaeger trace contains both Airflow DAG task span and Spark driver span under same trace ID

## Requirements

### Functional

- **FR1**: Deploy observability-demo Helm chart (existing) + extensions
- **FR2**: Add DCGM Exporter as DaemonSet (skipped on non-GPU minikube, but chart wired)
- **FR3**: Wire MinIO Prometheus scrape (`/minio/v2/metrics/bucket`) via ServiceMonitor
- **FR4**: Enable Airflow statsd-exporter subchart sidecar
- **FR5**: Install OpenLineage provider in Airflow image
- **FR6**: Install OpenLineage Spark integration via `--packages` or baked into runtime image
- **FR7**: Deploy single script `scripts/deploy-observability-stand.sh` orchestrating all of above
- **FR8**: Deploy single script `scripts/verify-observability-stand.sh` for health checks

### Non-Functional

- **NFR1**: Full stand deploys in <15 minutes on minikube 6 CPU / 16GB
- **NFR2**: All pods reach Ready state within 5 minutes of helm install
- **NFR3**: No pod in CrashLoopBackoff after stand stabilization period
- **NFR4**: Resource requests total < 8GB RAM (minikube budget)

### Constraints

- minikube driver: docker (default) or kvm
- Existing `charts/observability-demo/` umbrella chart is base — extend, don't fork
- Existing canonical scripts (`scripts/check-demo-health.sh`, `scripts/restore-demo.sh`) MUST still pass after stand deploy
- New dashboards added under `charts/observability/grafana/dashboards/` (ConfigMap pattern, sidecar import)
- GPU stack (DCGM) conditional — flag-driven, no failure on non-GPU minikube

## E2E Test Plan (Acceptance)

### Acceptance Criteria

- [ ] AC1: `./scripts/deploy-observability-stand.sh` exits 0 on fresh minikube
- [ ] AC2: All expected pods `Ready` (Prometheus, Grafana, Loki gateway, Jaeger, OTel collector, demo-metrics-exporter, Airflow statsd sidecar, MinIO, Spark History)
- [ ] AC3: Grafana URL reachable via `minikube service`
- [ ] AC4: Prometheus `/api/v1/targets` shows all UP
- [ ] AC5: Loki LogQL query returns Spark driver logs from last 5 min
- [ ] AC6: Jaeger UI shows at least one trace after sample Spark job
- [ ] AC7: Grafana dashboards list ≥ 10 reference dashboards
- [ ] AC8: Specific dashboards present (see list above)
- [ ] AC9: Dashboards render without datasource errors
- [ ] AC10: At least one panel per dashboard shows live data
- [ ] AC11: OpenLineage provider in Airflow
- [ ] AC12: Spark-submit emits RunEvent with ParentRunFacet
- [ ] AC13: Jaeger trace contains both DAG + Spark spans

### Test Strategy

- **E2E shell**: `scripts/verify-observability-stand.sh` runs all AC checks, exits non-zero on failure
- **Smoke**: deploy + check-demo-health.sh
- **Sample workload**: trigger one Airflow DAG that submits Spark job, wait for completion, verify metrics/traces/logs land

## Out of Scope

- GPU hardware (DCGM wired but tested only structurally on non-GPU minikube)
- AWS S3 CloudWatch exporter (MinIO only — AWS is migration path documented in references)
- Lightbend / Datadog commercial integrations
- Production persistent storage (minikube ephemeral OK)
- Multi-cluster federation
