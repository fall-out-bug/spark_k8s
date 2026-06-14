# Feature Specification: Spark Load Tests with 10GB NYC Taxi Dataset

**Feature Branch**: `025-load-tests-10gb-nyc-taxi`

**Created**: 2026-06-14 (migrated from WS-025-11)

**Status**: Draft

**Source**: Migrated from legacy `WS-025-11` (archived at `docs/archive/sdp-workstreams/backlog/WS-025-11.md`)

## User Scenarios & Testing

### User Story 1 - Full Pipeline on 10GB Parquet (Priority: P1)

As a Spark-on-K8s operator, I want to run a 5-stage pipeline (Read → GroupBy/Agg → Join → Window → Write) against 10GB NYC Taxi parquet in MinIO, across all 4 deployment scenarios (jupyter-k8s, jupyter-standalone, airflow-k8s, airflow-standalone), without OOM or crash.

**Why this priority**: This is the core value — proving Spark K8s charts handle realistic workloads end-to-end. Without this US, the feature has no MVP.

**Test scenarios (all must pass)**:
- AC3: `jupyter-connect-k8s-3.5.7` — all 5 operations succeed
- AC4: `jupyter-connect-standalone-3.5.7` — all 5 operations succeed
- AC5: `airflow-connect-k8s-3.5.7` — spark-submit batch job succeeds
- AC6: `airflow-connect-standalone-3.5.7` — spark-submit batch job succeeds

### User Story 2 - Observable Metrics Under Load (Priority: P2)

As an SRE, I want Grafana dashboards to display real metrics (execution time, peak memory, shuffle, GC, executor count) under load, so I can verify the observability stack works at scale.

**Why this priority**: Demonstrates that monitoring infra is functional; not blocking for pipeline correctness but required for production readiness.

**Test scenarios**:
- AC7: Execution time, peak memory, shuffle read/write bytes, GC time captured per scenario
- AC8: Dynamic allocation (k8s mode): executor scale-up observed, scale-down after idle
- AC9: Grafana Spark Overview shows executor count, memory, jobs rate
- AC10: Grafana Executor Metrics shows per-executor memory/cores/tasks
- AC11: Grafana Job Performance shows duration percentiles, shuffle throughput

### User Story 3 - Comparative Report (Priority: P3)

As a platform engineer, I want a side-by-side comparison table (k8s vs standalone, 4 scenarios × 5 operations) so I can recommend the right deployment mode.

**Why this priority**: Deliverable artifact for stakeholders; not required for technical validation.

**Test scenarios**:
- AC12: Comparative report saved at `docs/reports/F25-load-test-report.md`

## Requirements

### Functional

- **FR1**: NYC Taxi Yellow Taxi parquet (~10GB, 12-18 months) downloaded and loaded into MinIO bucket `raw-data`
- **FR2**: Load test script executes 5 operations in order: Read parquet from S3 (full scan), GroupBy + aggregation (total_amount by pickup_location), Join (trips + zones lookup), Window functions (running avg fare per driver), Write results back to S3 (parquet + partitioned) into bucket `processed-data`
- **FR3**: MinIO bucket `spark-logs` receives event log per Spark version

### Non-Functional

- **NFR1**: No OOM, no crash, no data loss in any scenario
- **NFR2**: Total pipeline runtime within baseline: 10–26 minutes per scenario
- **NFR3**: Minikube resource floor: 6 CPU / 16GB RAM / 50GB disk

### Constraints

- Spark version pinned to 3.5.7 (legacy matrix target)
- All S3 access via MinIO (`s3a://`, path-style, no SSL)
- Event log persisted to S3, History Server deployed for log read-back

## E2E Test Plan (Acceptance)

### Dataset

**NYC Taxi Trip Records (Yellow Taxi)**:
- Source: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Format: Parquet
- Size: ~10GB (12-18 months)
- Columns: pickup/dropoff datetime, locations, distances, fares, tips, payment types

### Performance Baseline (expected ranges)

| Operation         | k8s (3 executors) | standalone (2 workers) |
|-------------------|-------------------|------------------------|
| Full scan 10GB    | 2-5 min           | 2-5 min                |
| GroupBy/Agg       | 1-3 min           | 1-3 min                |
| Join              | 2-5 min           | 2-5 min                |
| Window            | 3-8 min           | 3-8 min                |
| Write partitioned | 2-5 min           | 2-5 min                |
| **Total**         | **10-26 min**     | **10-26 min**          |

### Minikube Requirements

```bash
minikube start --cpus=6 --memory=16g --disk-size=50g
```

### Acceptance Criteria

- [ ] AC1: NYC Taxi dataset (~10GB parquet) downloaded and loaded into MinIO bucket `raw-data`
- [ ] AC2: Load test script executes 5 operations (Read, GroupBy/Agg, Join, Window, Write)
- [ ] AC3: jupyter-connect-k8s-3.5.7 — all 5 operations succeed
- [ ] AC4: jupyter-connect-standalone-3.5.7 — all 5 operations succeed
- [ ] AC5: airflow-connect-k8s-3.5.7 — spark-submit batch succeeds
- [ ] AC6: airflow-connect-standalone-3.5.7 — spark-submit batch succeeds
- [ ] AC7: Metrics captured (execution time, peak memory, shuffle, GC)
- [ ] AC8: Dynamic allocation scale-up/down observed (k8s)
- [ ] AC9: Grafana Spark Overview displays executor count/memory/jobs rate
- [ ] AC10: Grafana Executor Metrics displays per-executor breakdown
- [ ] AC11: Grafana Job Performance displays percentiles + shuffle throughput
- [ ] AC12: Comparative k8s-vs-standalone report saved

## Out of Scope

- 100GB+ scale (separate WS)
- GPU / Iceberg extensions (separate matrix scenarios)
- Spark 4.1.x variants (this WS targets 3.5.7 baseline only)
