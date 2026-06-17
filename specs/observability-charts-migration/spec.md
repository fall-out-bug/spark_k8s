---
feature: observability-charts-migration
status: draft
created: 2026-06-17
---

# Spec: Grafana/Loki/Prometheus Charts Migration

## Problem

Three observability chart dependencies are on **deprecated/migrated** sources or
**massively outdated**. This affects invariant #2 (Airflow + Spark monitoring/profiling
in Grafana) — the observability stack must keep working.

| Chart | Current (in repo) | Issue | Resolution |
|-------|-------------------|-------|------------|
| `grafana` (spark-3.5, 4.0, observability/grafana) | `8.15.0` / `10.5.15` @ `grafana.github.io/helm-charts` | Repo migrated to `grafana-community` (Jan 30 2026); old repo frozen | Move to `grafana-community.github.io/helm-charts`, bump |
| `loki` (spark-4.0, observability/loki) | `6.53.0` @ `grafana.github.io/helm-charts` | Repo migrated (Mar 16 2026); last old version 6.55.0; new 7.x+ in community. **Loki 8.0 removed GEL** | Move to `grafana-community.github.io/helm-charts`; pick 6.55.0 (safe) or 7.x (test) |
| `prometheus-operator` (observability/prometheus) | `9.3.2` @ `prometheus-community.github.io/helm-charts` | Chart **renamed** to `kube-prometheus-stack` (~86.x now); 9.x→86.x is massive breaking | Rename dep + bump; values schema heavily changed |

## Goal

All observability subchart dependencies point at **maintained** repositories with
**current** versions, without breaking the observability-demo stack (invariant #2) or
OSS-consumer backward-compat (constitution v1.1.0).

## Scope

### Affected charts (7 Chart.yaml + 7 Chart.lock)
- `charts/spark-3.5/Chart.yaml` — prometheus + grafana deps
- `charts/spark-4.0/Chart.yaml` — prometheus + grafana + loki deps
- `charts/spark-4.1/Chart.yaml` — (deps commented out; uncomment + migrate)
- `charts/observability/grafana/Chart.yaml` — grafana dep
- `charts/observability/loki/Chart.yaml` — loki dep
- `charts/observability/prometheus/Chart.yaml` — prometheus-operator → kube-prometheus-stack
- `charts/observability-demo/Chart.yaml` — umbrella (transitive, via file:// subcharts)

### In scope
- Update `repository:` URLs to new repos where migrated (grafana, loki)
- Rename `prometheus-operator` → `kube-prometheus-stack` dep + version bump
- Bump version constraints (`version: "8.x.x"` → appropriate)
- Regenerate Chart.lock files (`helm dependency update`)
- Adapt `values-*.yaml` overrides where the new chart version broke the schema
- helm lint + helm template gate on all affected charts

### Out of scope
- Live deploy verification (demo not deployed this session — offline gates only)
- Alertmanager migration (separate, lower risk — `prometheus-community` repo unchanged)
- Jaeger migration (separate)
- Dashboard JSON content changes (unless metric names changed)

## Open questions (must resolve BEFORE implementation)

### Q1: grafana-community repo URL
Is the new Helm repo `https://grafana-community.github.io/helm-charts/`? Confirm exact URL
(chart names `grafana`, `loki` preserved?). Need to verify via `helm repo add` + `helm search`.

### Q2: Loki version target — 6.55.0 or 7.x?
- 6.55.0 = last in old repo, also first fork point in community — safest (minimal values delta)
- 7.x = current community line, may need values adaptation
- 8.x = removes GEL (we don't use GEL, but big jump)
**Recommendation:** 6.55.0 first (minimal change), document 7.x as follow-up.

### Q3: prometheus-operator 9.3.2 → kube-prometheus-stack version
9.x→86.x is ~77 major versions of breaking changes (CRD v1, values restructure, removed
subcharts). Full migration is a project. **Options:**
- (A) Just rename dep + pin to a kube-prometheus-stack version close to old behavior (risky)
- (B) Keep prometheus-operator name if still resolvable (deprecated alias?) — verify
- (C) Defer prometheus-operator rename, do grafana+loki only this PR

### Q4: values-demo.yaml adaptation depth
The umbrella overrides reach into `prometheus-spark.prometheus-operator.prometheusOperator.*`,
`loki-spark.loki.gateway.*`, `grafana-spark.grafana.sidecar.*`. If subchart schemas changed
in new versions, these overrides silently no-op or error. Need to validate each.

## Risks

- **R1 (high):** kube-prometheus-stack 86.x values schema is wildly different from
  prometheus-operator 9.x — `prometheusOperator:`, `kubeStateMetrics:`, etc. keys may
  have moved. `values-demo.yaml` overrides could break silently.
- **R2:** Loki 7.x `gateway` config changed (nginx → default disabled in some modes);
  `loki-spark.loki.gateway.affinity: null` override may not apply.
- **R3:** grafana-community fork may have subtle divergence from grafana/helm-charts
  (the migration was a fork, not a rename — values mostly compatible but not guaranteed).
- **R4:** OSS consumers running old chart versions — bumping major breaks their pins.

## References

- Migration: github.com/grafana/helm-charts/issues/4087, github.com/grafana/loki/issues/20705
- Upgrade guide: grafana.com/docs/loki/latest/setup/upgrade/upgrade-to-community/
- Constitution: `specs/_constitution.md` invariant #2
- Current state: `charts/observability-demo/values-demo.yaml` (deep overrides)

## Next step

Resolve Q1-Q4 (especially Q3 — prometheus-operator scope decision), then `plan.md`.
