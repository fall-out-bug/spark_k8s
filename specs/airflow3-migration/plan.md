---
feature: airflow3-migration
status: draft
created: 2026-06-17
---

# Plan: Airflow 2.11 → 3.2.2 Migration

**Input:** `spec.md` (Q1-Q3 resolved below)

## Open questions — RESOLVED

### Q1 (target version): 3.2.2
Airflow 3.2.2 is the current stable (May 2026). 2.x is in limited maintenance.
Going to 3.x is the right long-term call; staying on 2.11.2 only delays the
inevitable major bump.

### Q2 (OTel strategy): UPGRADE OTel SDK to 1.35.0+ (the actual fix)
**Critical finding:** the memory leak (issue #53763) is in the **OpenTelemetry SDK
itself** (`MeterProvider` strong references), NOT in Airflow. The fix is to
**upgrade opentelemetry-sdk to 1.35.0+**. Our current pin `opentelemetry-sdk==1.20.0`
(the 2.11 workaround from T029) is **exactly the buggy version**.

Decision: replace the `==1.20.0` pins with `>=1.35.0` for all 4 OTel packages.
This fixes the leak on BOTH 2.11 and 3.x. The original T029 rationale (2.11 OTLP
payload bug) does not apply to 3.x's native tracing — 3.x uses a different code path.

### Q3 (DAG migration): MANUAL (6 files, reviewable)
6 DAGs is small enough to hand-migrate and review. The only required change is
`schedule_interval=` → `schedule=` (deprecated→renamed in 3.0; old name still works
with a warning in 3.x but is removed-target). Using the auto-migration tool adds
unreviewable churn. Hand-migrate + lint each DAG.

## Design decisions

### D1: Image target
`FROM apache/airflow:3.2.2-python3.11`. Image tag `spark-k8s/airflow:3.2.2`.

### D2: Provider bumps
Airflow 3.2 requires newer provider majors than our current `>=` floors allow.
- `apache-airflow-providers-openlineage>=2.18.0` (was >=1.7.0; 2.x line is Airflow-3-compatible)
- `apache-airflow-providers-cncf-kubernetes>=10.0.0` (was >=8.0.0; 10.x tracks Airflow 3)
- `apache-airflow-providers-apache-spark>=9.0.0` (bump for 3.x compat — verify)
- `apache-airflow-providers-amazon>=9.0.0` (bump for 3.x compat — verify)

### D3: OTel pin replacement
Remove the 4 `==1.20.0` pins, install `opentelemetry-sdk>=1.35.0` (single line; the
sdk pulls compatible api/proto/exporter transitively, but pin them too for determinism).

### D4: DAG migration scope
- `schedule_interval="0 6 * * *"` → `schedule="0 6 * * *"`
- `schedule_interval=None` → `schedule=None`
- Keep `catchup`, `max_active_runs` (semantics preserved in 3.x)
- No operator import changes needed (PythonOperator, KubernetesPodOperator paths valid in 3.x)

### D5: Version pins (7 places)
- `charts/spark-3.5/values.yaml:343` — tag 2.11.0 → 3.2.2
- `charts/spark-3.5/values-airflow-sc-final.yaml:89`
- `charts/spark-3.5/values-demo-full-pipeline.yaml:93`
- `charts/spark-3.5/presets/scenarios/airflow-standalone-minimal.yaml:62`
- `charts/spark-3.5/presets/airflow-openlineage.yaml:50`
- `charts/spark-3.5/presets/demo-full-spark-infra.yaml:119`
- `docker/optional/airflow/Dockerfile:2` — FROM apache/airflow:3.2.2-python3.11
- Docs (README, guides) — update references

## Files to change

| File | Change |
|------|--------|
| `docker/optional/airflow/Dockerfile` | FROM 3.2.2, provider bumps, OTel 1.35+ |
| 6 DAG files | `schedule_interval` → `schedule` |
| 6 values/preset files | tag 2.11.0 → 3.2.2 |
| `charts/spark-3.5/README-demo-full-pipeline.md` | doc update |
| `scripts/tests/minikube/run-minikube-scenarios.sh:84` | tag |
| `specs/airflow3-migration/{spec,plan}.md` | this |
| `docs/reports/airflow3-migration-2026-06-17.md` | new report |

## Verification

- `helm lint charts/spark-3.5` (airflow is a sidecar image ref, not a subchart — lint covers tag refs)
- `helm template` renders airflow-related templates with 3.2.2 tag
- `pre-commit run` — including ruff/black/mypy on DAGs (DAGs are now type-annotated from PR #19)
- Python syntax check on each migrated DAG (`python3 -m py_compile`)
- `pre-commit run ruff/black/mypy` on the 6 DAGs

## Risks revisited

- **R1 (OTel leak):** MITIGATED by OTel SDK 1.35+ upgrade (the actual upstream fix).
  Still MUST-VERIFY post-merge on live deploy (scheduler memory stable over time).
- **R2 (provider compat):** verify each provider's Airflow-3 constraint before pinning.
- **R3 (DAG schedule rename):** catch all 6 via grep; py_compile each.
- **R4 (OSS break):** major bump 2→3 is breaking for consumers; documented in PR +
  report. Constitution allows breaking with migration notes (this spec IS the notes).
