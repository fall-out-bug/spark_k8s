---
feature: spark-operator-v2-migration
status: draft
created: 2026-06-22
---

# Plan: Spark Operator v2 Migration

**Input:** `spec.md` (Q1-Q4 resolved via spike research)

## Key insight

The vendored CRD is **already v2.x-aligned** (Kubeflow annotations, v1beta2 served).
Only metadata drifted (stale `appVersion`, dead `gcr.io` image path) and the
ScheduledSparkApplication CRD is a truncated stub. Migration is smaller than feared:
**replace vendored chart with upstream Helm dependency + remap values + adopt full CRD**.

## Design decision: replace with upstream Helm dependency (Q1 → A)

Rationale: vendored chart is a strict subset of upstream, missing
`hook.upgradeCrd` (CRD lifecycle — critical for upgrades), leader-election,
PDB, and least-privilege RBAC. Maintaining 12k-line CRD by hand is a liability
(the ScheduledSparkApplication stub proves it — silently broken).

Trade-off: value key remapping needed (breaking for OSS consumers with existing
`sparkOperator.*` overrides). Documented as migration notes per constitution.

## What changes

### 1. Replace `charts/spark-operator/` with upstream dependency
- Delete vendored chart (templates/, crds/, rbac.yaml, etc.)
- Add upstream as dependency in parent charts that reference it:
  `charts/spark-3.5/Chart.yaml`, `charts/spark-4.0/Chart.yaml`, `charts/spark-4.1/Chart.yaml`
  ```yaml
  - name: spark-operator
    version: "2.5.1"
    repository: "https://kubeflow.github.io/spark-operator/"
    condition: sparkOperator.enabled
    alias: sparkOperator
  ```
- Pin **v2.5.1** (latest stable).

### 2. Value remapping (breaking — migration notes)
| Old (vendored) | New (upstream v2.5.1) |
|----------------|----------------------|
| `image.repository` + `image.tag` | `image.registry` (`ghcr.io`) + `image.repository` (`kubeflow/spark-operator/controller`) + `image.tag` (`v2.5.1`) |
| `sparkJobNamespace` | `spark.jobNamespaces` (default `["*"]`) |
| `webhook.enable` / `webhook.port` | same names (aligned) |
| `rbac.create` | same (aligned) |
| `replicas`, `resources` | same names |

### 3. Update scenario values referencing operator
- `charts/spark-{3.5,4.0,4.1}/values-scenario-airflow-operator.yaml` — update
  `sparkOperator.*` keys to new schema
- Presets that enable operator (`presets/scenarios/airflow-operator.yaml`)

### 4. CRD lifecycle
- Upstream chart handles CRD install/upgrade via `hook.upgradeCrd` job — no
  manual 12k-line CRD maintenance.
- ScheduledSparkApplication CRD now gets the FULL schema (was truncated stub).

### 5. Dashboard + alertmanager
- `spark-operator-scale.json` metric labels: verify against v2.5.1 (labels may
  have shifted with least-privilege RBAC changes). Likely unchanged (Prometheus
  metrics are stable across v2.x).
- `alertmanager/templates/prometheus-rules.yaml` SparkApplicationCompleted alert:
  verify metric name unchanged.

## Spark 4.1.x caveat (Q3)

Operator v2.5.1 officially supports 3.5.x and 4.0.x. Spark 4.1.x is **not yet
officially validated** (kubeflow/spark-operator#2883 open). However the operator
is NOT Spark-version-coupled at runtime (app images are user-supplied). Practical
guidance: pin operator v2.5.1, pin app Spark images explicitly per SparkApplication.
Monitor #2883 for 4.1.x official sign-off.

## Risks

- **R1 (OSS break):** value key remapping breaks consumers with existing
  `sparkOperator.image.repository` overrides. Mitigation: migration notes (this
  spec) + chart major version bump if we version our umbrella charts.
- **R2 (4.1.x unvalidated):** if a SparkApplication uses a 4.1.x app image,
  operator behavior is untested upstream. Mitigation: document; pin 4.0.x for
  operator-submitted apps until #2883 closes.
- **R3 (dashboard labels):** if v2.5.1 changed metric labels, dashboard silently
  shows no data. Mitigation: verify metrics scrape after deploy (post-merge).

## Verification (post-implementation)
- `helm lint` on spark-3.5/4.0/4.1 with operator enabled
- `helm template` renders upstream operator correctly with remapped values
- Scenario `values-scenario-airflow-operator.yaml` applies cleanly
- Grafana dashboard metrics still scrape (post-deploy verify)

## Out of scope
- SparkApplication YAML examples in docs (separate)
- GPU-specific operator config (invariant #4, separate)
- Migrating actual SparkApplication submissions to 4.1.x (waits on #2883)
