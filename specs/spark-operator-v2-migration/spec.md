---
feature: spark-operator-v2-migration
status: draft
created: 2026-06-17
---

# Spec: Spark Operator v2 Migration (GoogleCloudPlatform → Kubeflow)

> **Update 2026-08-09 — state re-audited.** The standalone `charts/spark-operator/`
> now ships `ghcr.io/kubeflow/spark-operator/controller:v2.5.1` (kubeflow migration
> landed for the operator chart itself). **BUT** the per-version operator image refs
> in `charts/spark-{3.5,4.0,4.1}/values.yaml` STILL point at
> `ghcr.io/googlecloudplatform/spark-operator` (deprecated). The divergence shifted,
> not resolved: standalone chart ✓ kubeflow · Spark-version charts ✗ googlecloudplatform.
> A THIRD operator now exists — official `apache/spark-kubernetes-operator` (ASF,
> May 2025) — resolved in Q0 (2026-08-09): **kubeflow**. Per-version image migration still pending.

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

### Q0: kubeflow/spark-operator vs apache/spark-kubernetes-operator? — DECISION: kubeflow (now)

Researched 2026-08-09. **Decision: migrate to kubeflow/spark-operator now; re-evaluate
apache in 6-12 months at the Spark 4.x upgrade.**

Key finding: `apache/spark-kubernetes-operator` **1.0.0 (2026-07-26) dropped Spark 3.5**
(Spark 4.0/4.1/4.2 only). This repo ships Spark 3.5.7, so apache 1.0.0 is a hard blocker;
apache 0.9.0 (last 3.5-supporting) is a dead-end branch. Meanwhile kubeflow is the
official, lowest-friction successor to the GCP operator already vendored here — same API
group (`sparkoperator.k8s.io`), same `SparkApplication` kind, supports Spark 2.3+ incl 3.5.

- `kubeflow/spark-operator` v2.5.2 (2026-07-31): operationally mature (large deployed
  base, ~2y stable v2.x, OpenSSF badge), but API still `v1beta2` / self-declared "beta".
- `apache/spark-kubernetes-operator` 1.0.0 (2026-07-26, ~2 weeks old): API-mature (stable
  CRD, `spark.apache.org` group), ASF-official, adds `SparkCluster` CRD + YuniKorn gang
  scheduling + native acceleration — but operationally young, JVM operator, full rewrite
  to adopt, and drops Spark 3.5.

Q1-Q4 proceed assuming kubeflow. apache re-evaluation deferred to the Spark 4.x upgrade.
Sources: github.com/apache/spark-kubernetes-operator/releases, github.com/kubeflow/spark-operator/releases,
blog.kubeflow.org migration announcement (Apr 2024 — only official GCP-migration guidance → kubeflow).

### Q1: Vendored chart vs upstream dependency?

Two options:
- **(A) Replace our `charts/spark-operator/` with an upstream Helm dependency**
  (`https://kubeflow.github.io/spark-operator/`). Least maintenance, but loses our
  custom values schema (breaks OSS backward-compat per constitution v1.1.0).
- **(B) Keep our chart, update the image + CRD to v2.x.** Preserves our values API,
  but means maintaining the 12k-line CRD manually (ongoing burden).

### Q2: v2.x API compatibility with our scenarios

v2.x may change:
- CRD field names / defaults (affects `values-scenario-airflow-operator.yaml`)
- RBAC permissions (affects our `rbac.yaml`)
- Metric label names (affects `spark-operator-scale.json` dashboard)
- Webhook mechanics

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
