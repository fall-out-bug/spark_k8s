---
feature: spark-operator-v2-migration
status: draft
created: 2026-06-17
---

# Spec: Spark Operator v2 Migration (GoogleCloudPlatform → Kubeflow)

## Problem

The Spark Operator image referenced in this repo points at the **deprecated**
`googlecloudplatform` namespace, which is frozen. The project was donated to
**Kubeflow** (`github.com/kubeflow/spark-operator`) and the v2.x line is actively
developed there. This is an invariant #8 concern (Spark Connect as primary access
model depends on a working operator for `SparkApplication` submission).

Additionally there are **two divergent image references** for the same operator:

| Location | Repository | Tag |
|----------|-----------|-----|
| `charts/spark-operator/values.yaml:2` | `gcr.io/spark-operator/spark-operator` | `v1beta2-1.3.8-3.1.1` |
| `charts/spark-3.5/values.yaml:619` | `ghcr.io/googlecloudplatform/spark-operator` | `v1beta2-1.3.8-3.5.0` |

Different registries AND different Spark-version suffixes (3.1.1 vs 3.5.0) — broken chain.

## Current state (audit)

- **Our chart `charts/spark-operator/`** is a self-maintained chart with:
  - Manually-vendored CRD: `templates/crds/sparkapplication-crd.yaml` (**12,414 lines**)
  - `scheduledsparkapplication-crd.yaml` (33 lines, looks truncated/placeholder)
  - `operator-deployment.yaml`, `rbac.yaml`, `webhook-service.yaml`
  - No upstream Helm dependency — everything vendored
- **Usage in scenarios:** `values-scenario-airflow-operator.yaml` exists only in
  `charts/spark-4.0/` and `charts/spark-4.1/`. Spark 3.5 wires the operator via
  `presets/spark-infra.yaml` and the `airflow-*-3.5.*.yaml` scenario files. All three
  Spark versions enable `sparkOperator` in some form.
- **Grafana dashboard** `spark-operator-scale.json` scrapes metrics via PromQL filters
  on BOTH `namespace="spark-operator"` AND `container="spark-operator-controller"`
  (e.g. `workqueue_depth{container="spark-operator-controller"}`). Either selector may
  change in v2.x — must be re-verified post-migration.

## Goal

A working, maintained Spark Operator that supports the Spark versions we ship (3.5.7,
4.1.x), on a non-deprecated image, without the registry/tag divergence.

## Open questions (must resolve BEFORE plan.md)

### Q1: Vendored chart vs upstream dependency?

Two options:
- **(A) Replace our `charts/spark-operator/` with an upstream Helm dependency**
  (`https://kubeflow.github.io/spark-operator/`). Least maintenance, but loses our
  custom values schema (breaks OSS backward-compat per constitution v1.1.0).
- **(B) Keep our chart, update the image + CRD to v2.x.** Preserves our values API,
  but means maintaining the 12k-line CRD manually (ongoing burden).

### Q1-Q4 RESOLVED (spike research, 2026-06-22)

**Surprise finding: the vendored CRD is ALREADY v2.x-aligned.** The
`sparkapplication-crd.yaml` carries Kubeflow-era annotations
(`api-approved.kubernetes.io: kubeflow/spark-operator#1298`,
`controller-gen v0.17.1`) and serves `v1beta2` — matching upstream v2.5.1
byte-essentially. Only the **metadata drifted**: `Chart.yaml appVersion`
still says `v1beta2-1.3.8-3.1.1` and `values.yaml` image points at the dead
`gcr.io/spark-operator/spark-operator` path.

**Q1 → Replace with upstream Helm dependency.** Upstream publishes
`https://kubeflow.github.io/spark-operator/` (chart `spark-operator`).
Vendored chart is a strict subset — missing `image.pullSecrets`,
`hook.upgradeCrd` CRD-lifecycle job, leader-election, PDB, full
proxy/affinity/tolerations. Value keys remap cleanly (`sparkJobNamespace` →
`spark.jobNamespaces`, image path changes to `ghcr.io/kubeflow/spark-operator/controller`).

**Q2 → CRD no breaking change; RBAC + ScheduledSparkApplication do.**
- CRD apiVersion stays `sparkoperator.k8s.io/v1beta2`.
- `scheduledsparkapplication-crd.yaml` is a **33-line stub** (truncated, references
  nonexistent `.Values.crds.create`). Upstream has the full 12,473-line schema —
  ScheduledSparkApplication validation is currently disabled. Migration must adopt full CRD.
- RBAC (`templates/rbac.yaml`) is **overly broad and missing permissions**: no
  `events`, `ingresses`, `customresourcedefinitions`, `*/finalizers`, or the new
  `sparkconnects` resources. Upstream v2.5.1 applied least-privilege (PR #2914).
- New `SparkConnect` CRD exists upstream (not in vendored) — optional but standard.

**Q3 → Pin v2.5.1** (latest stable, 2026-06-15). Image
`ghcr.io/kubeflow/spark-operator/controller:v2.5.1`. Operator is NOT Spark-version-coupled
at runtime (app images are user-supplied via `spec.image`). 3.5.x and 4.0.x are safe;
4.1.x is NOT yet officially validated (open issue kubeflow/spark-operator#2883).

**Q4 → Operator IS used.** RBAC, KEDA scaledobject
(`charts/spark-4.0/templates/autoscaling/keda-operator-scaledobject.yaml`), grafana
dashboard, alertmanager rules all reference SparkApplication CRD. Not redundant with
Spark Connect. Migration needed.

Need to diff our vendored CRD against v2.x CRD before deciding.

### Q3: Which v2.x version?

Kubeflow spark-operator latest is v2.5.x (per audit). Need to confirm it supports
both Spark 3.5.7 and 4.1.x, and pick a pinned version.

### Q4: Spark Connect interaction (invariant #8)

Spark Connect (primary access model) and the Operator (SparkApplication submission)
are complementary, not redundant. Confirm the operator is still needed for the
`airflow-operator` scenario, or whether Spark Connect supersedes it there.

## Scope (preliminary, pending Q1-Q4)

### Likely in scope
- Unify the two image references into one
- Migrate image to `ghcr.io/kubeflow/spark-operator:<v2.x>` (or chosen equivalent)
- Update CRD + RBAC to v2.x (or replace with upstream dependency)
- Update `spark-operator-scale.json` dashboard metric labels if changed
- Update scenario values if CRD fields changed

### Likely out of scope
- Spark Operator HA (covered by separate backlog spec "HA Master")
- GPU-specific operator behavior

## Risks

- **R1 (high):** Manual CRD maintenance is a 12k-line liability; any miss = silent breakage.
- **R2:** v2.x breaking changes could break existing `airflow-operator` scenarios for OSS
  consumers — needs careful compat testing.
- **R3:** The Grafana dashboard (`spark-operator-scale.json`, part of invariant #2
  observability) may stop showing data if metric labels change.

## References

- Audit: `docs/reports/` (spark_k8s review 2026-06-17)
- Kubeflow Spark Operator: https://github.com/kubeflow/spark-operator
- Migration announcement: https://blog.kubeflow.org/operators/2024/04/15/kubeflow-spark-operator.html
- New docs: https://kubeflow.github.io/spark-operator/
- Constitution invariants #2 (observability), #8 (Spark Connect)

## Next step

Resolve Q1-Q4 (likely needs a CRD diff + a spike on v2.5 with our scenarios), then
write `plan.md`.
