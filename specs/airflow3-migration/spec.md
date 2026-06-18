---
feature: airflow3-migration
status: draft
created: 2026-06-17
---

# Spec: Airflow 2.11 → 3.x Migration

## Problem

The Airflow stack is pinned at **2.11.0** (custom image `spark-k8s/airflow:2.11.0`).
The Airflow 2.x line is in **limited maintenance** (per Airflow release plan, 2.x
support phased out by ~May 2026). This affects invariant #2 (Airflow + Spark
monitoring in Grafana) and invariant #6 (OpenLineage + Airflow provider).

The current image carries an **OTel-SDK pin workaround** (`opentelemetry-sdk==1.20.0`)
that was required to fix Airflow 2.11's native-traces OTLP/HTTP payload bug
(see `specs/grafana-observability-stand/` T029). This workaround must be re-evaluated
for Airflow 3.x.

## Current state (audit)

### Image
- `docker/optional/airflow/Dockerfile`: `FROM apache/airflow:2.11.0-python3.11`
- Custom image name `spark-k8s/airflow`, tag `2.11.0`
- OTel SDK pinned at 1.20.0 (4 packages: sdk/api/exporter-otlp-proto-http/proto)
- Providers: apache-spark>=4.7.0, cncf-kubernetes>=8.0.0, amazon>=8.19.0, openlineage>=1.7.0
- pyspark>=3.5.0, boto3>=1.34.0, Java 17 (for spark-submit)

### DAGs (6 affected)
All use the Airflow 2.x `DAG()` constructor with **`schedule_interval=`** — deprecated
in 3.0 (renamed to `schedule=`). Locations:
- `dags/nyc_taxi_ml_full_pipeline.py:500`
- `charts/spark-3.5/dags/citibike_analytics_pipeline.py:117`
- `charts/spark-3.5/dags/nyc_taxi_ml_full_pipeline.py:169`
- `charts/spark-3.5/dags/spark_openlineage_demo.py:20`
- `charts/spark-3.5/dags/spark_standalone_load_demo.py:11`
- `charts/spark-3.5/dags/movielens_recommendation_pipeline.py:156`

Import paths (`from airflow.operators.python import PythonOperator`,
`from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator`)
are valid in 3.x — no change needed there.

### Version pins in repo (7 places)
`charts/spark-3.5/values.yaml:343`, 2 other values files, 3 presets, Dockerfile, docs.

## ⚠️ Critical risk: OTel tracing memory leak in Airflow 3.x

Airflow 3.x introduced **native OpenTelemetry tracing** (the very feature our 2.11
workaround enables). However, there is a **known memory leak** in the OTel tracing
path affecting schedulers and triggerers:
- GitHub Issue [#53763](https://github.com/apache/airflow/issues/53763)
- Discussion [#53771](https://github.com/apache/airflow/discussions/53771)
- **Partial fix in Airflow 3.1.1**; **full fix NOT confirmed** for 3.2.x as of 2026-06.

This directly threatens invariant #2 (Airflow→Jaeger trace correlation) at runtime —
a leaking scheduler is a production outage. The OTel pin workaround (1.20.0) was
Airflow-2.11-specific and may be irrelevant or harmful in 3.x.

## Goal

Airflow on a **current, maintained** version with working trace correlation
(invariant #2) and OpenLineage integration (invariant #6), without runtime memory
leaks.

## Scope (preliminary, pending Q1-Q3)

### Likely in scope
- Target version decision (3.2.2 vs 2.11.2 — see Q1)
- DAG migration: `schedule_interval=` → `schedule=` (6 files)
- Image Dockerfile update (FROM, providers, OTel pin re-evaluation)
- Update all 7 version pins in repo
- OTel configuration validation against the chosen version's behavior
- helm lint + template gate

### Out of scope
- DAG logic changes (only signature/API migration, not business logic)
- Airflow chart rewrite (we don't ship an Airflow chart — it's a sidecar image +
  DAGs; the orchestrator chart is separate)
- Provider major bumps (only what 3.x requires)

## Open questions (must resolve BEFORE implementation)

### Q1: Target version — 3.2.2 or 2.11.2?
- **3.2.2** = latest stable, but OTel memory-leak risk (invariant #2 at stake)
- **2.11.2** = last 2.x patch (security only), safe, but stays on EOL line
- Decision hinges on Q2 (can we have OTel without the leak?)

### Q2: OTel strategy in chosen version
- If 3.2.2: is the memory leak fixed enough for production? Or do we disable tracing
  (losing invariant #2) until upstream confirms? Or pin a specific 3.x patch known-good?
- If 2.11.2: does the existing 1.20.0 OTel pin still apply, or does 2.11.2 fix the
  original bug natively (making the pin unnecessary)?

### Q3: DAG migration tooling
Airflow ships auto-migration rules (GitHub issue #41641). Should we use them, or
hand-migrate the 6 DAGs (small enough to do manually and review)?

## Risks

- **R1 (high):** OTel memory leak → scheduler OOM in production. Mitigation: if 3.2.2,
  validate leak status empirically (cannot fully verify without live deploy this
  session — document as MUST-VERIFY post-merge).
- **R2:** Provider incompatibility — Airflow 3.x may require newer provider majors
  (openlineage, cncf-kubernetes) than our pins allow. Provider changelogs needed.
- **R3:** DAG `schedule=` rename is a silent no-op if missed (DAG runs on old
  schedule or errors). Must catch all 6.
- **R4:** OSS consumers with existing 2.11-based deployments — major bump breaks
  their setup. Constitution v1.1.0 OSS-compat clause applies.

## References

- Airflow 3 upgrade guide: https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html
- Astronomer guide: https://www.astronomer.io/docs/learn/airflow-upgrade-2-3
- OTel leak: github.com/apache/airflow/issues/53763
- Auto-migration: github.com/apache/airflow/issues/41641
- Current OTel workaround: `specs/grafana-observability-stand/` T029
- Constitution invariants #2 (Airflow/Spark Grafana monitoring), #6 (OpenLineage)

## Next step

Resolve Q1-Q3 (especially Q1+Q2 — version + OTel), then `plan.md`.
