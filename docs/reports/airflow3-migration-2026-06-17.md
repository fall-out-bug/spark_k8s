# Report: Airflow 2.11 → 3.2.2 migration (2026-06-17)

Branch: `feat/airflow3-migration`

## Summary

Migrated the Airflow stack from 2.11.0 to 3.2.2 (current stable), including the
critical fix for the OpenTelemetry memory leak that threatened invariant #2.

## Key finding: the OTel "workaround" was the bug

The previous image pinned `opentelemetry-sdk==1.20.0` as a workaround for Airflow
2.11's OTLP payload bug (`specs/grafana-observability-stand/` T029). Investigation
of issue [apache/airflow#53763](https://github.com/apache/airflow/issues/53763)
revealed the Airflow-3.x memory leak is in **the OpenTelemetry SDK itself**
(`MeterProvider` strong references), and the fix is to **upgrade OTel SDK to
≥1.35.0**. Our `1.20.0` pin was exactly the buggy version line.

The T029 workaround is now removed; OTel packages are pinned `>=1.35.0`. This fixes
the leak on both 2.11 and 3.x. Airflow 3.x's native tracing uses a different code
path that works correctly with modern OTel SDKs.

## What changed

### Image (`docker/optional/airflow/Dockerfile`)
- `FROM apache/airflow:2.11.0-python3.11` → `3.2.2-python3.11`
- Providers bumped for Airflow-3 compat: openlineage `>=2.18.0`, cncf-kubernetes
  `>=10.0.0`, apache-spark `>=9.0.0`, amazon `>=9.0.0`
- OTel pin replaced: `==1.20.0` (buggy) → `>=1.35.0` (leak-fixed) for all 4 packages

### DAGs (6 files) — `schedule_interval=` → `schedule=`
Airflow 3.0 renamed the `DAG()` kwarg. Old name still warns but is removal-target.
- `dags/nyc_taxi_ml_full_pipeline.py`
- `charts/spark-3.5/dags/citibike_analytics_pipeline.py`
- `charts/spark-3.5/dags/nyc_taxi_ml_full_pipeline.py`
- `charts/spark-3.5/dags/spark_openlineage_demo.py`
- `charts/spark-3.5/dags/spark_standalone_load_demo.py`
- `charts/spark-3.5/dags/movielens_recommendation_pipeline.py`

Import paths (`airflow.operators.python`, `airflow.providers.cncf.kubernetes`) are
unchanged — valid in 3.x. No operator moves required.

### Version pins (8 places) — `2.11.0` → `3.2.2`
6 values/preset files, 1 minikube script `--set`, 2 doc files, minikube README.

## ⚠️ MUST-VERIFY post-merge (live deploy)

The OTel SDK 1.35+ upgrade is the **upstream fix** for the memory leak, but this
session could not run a live Airflow deploy to confirm scheduler memory stability
over time. Post-merge verification:
1. Build `spark-k8s/airflow:3.2.2` (via `publish-images.yml` once it supports Airflow,
   or local `docker build`)
2. Deploy with OTel tracing enabled
3. Monitor scheduler memory over ~1h of DAG runs — must stay bounded
4. Confirm Jaeger still receives Airflow spans (invariant #2 trace correlation)

## Verification done (this session)
- `py_compile` on all 6 migrated DAGs → OK
- `helm lint charts/spark-3.5` → 0 failures
- `helm template` with airflow-openlineage preset → renders `spark-k8s/airflow:3.2.2`
  in scheduler/webserver templates
- `pre-commit run` on changed files → green

## OSS-consumer impact (constitution v1.1.0)

Major bump 2→3 is breaking. Consumers with 2.11-based deployments must:
- Rebuild their Airflow image from the updated Dockerfile
- Re-run any custom DAGs through the `schedule_interval`→`schedule` rename
This spec + report serve as the migration notes required by the constitution.

## References
- Airflow 3 upgrade guide: https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html
- OTel leak: github.com/apache/airflow/issues/53763
- Prior workaround: `specs/grafana-observability-stand/` T029
- Constitution invariants #2, #6
