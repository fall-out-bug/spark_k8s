---
feature: observability-charts-migration
status: draft
created: 2026-06-17
---

# Plan: Observability Charts Migration (conservative scope)

**Input:** `spec.md` (Q1-Q4 resolved empirically below)

## Open questions — RESOLVED

### Q1 (grafana-community repo URL): RESOLVED
`https://grafana-community.github.io/helm-charts/` — verified working. Charts `grafana` (12.4.7) and `loki` (17.4.5) exist. **But chart versions diverged massively from old repo** (grafana 10.5 vs 12.4; loki 6.55 vs 17.4) — community-fork is far ahead.

### Q2 (loki target): RESOLVED → 6.55.0
grafana-community/loki starts at 17.x (no 6.x/7.x in community). Old `grafana/loki` still hosts 6.55.0 (last 6.x). **Decision: bump to 6.55.0 in old repo** (minimal delta, no schema break). Repo migration to grafana-community = separate future spec.

### Q3 (prometheus-operator): RESOLVED → DEFER
`prometheus-operator` 9.3.2 is the last version (frozen, appVersion 0.38.1). `kube-prometheus-stack` 86.x is the successor but 9→86 = massive breaking (CRD v1, values restructure, removed subcharts). **Decision: defer kube-prometheus-stack migration to a separate spec.** Leave prometheus-operator 9.3.2 as-is (still installs, still works — just frozen). Document as known-gap.

### Q4 (values-demo adaptation): RESOLVED → minimal
With conservative bumps (grafana 8→10, loki 6.53→6.55), values schema stays compatible. The `values-demo.yaml` overrides (prometheusOperator.*, loki.gateway.*, grafana.sidecar.*) all remain valid in these version ranges. No adaptation needed for this PR.

## Design decision: SCOPE THIS PR TO SAFE IN-REPO BUMPS

**This PR:** version bumps within current repositories (no repo migration, no prometheus-operator rename). Conservative, regression-safe.

**Future PRs (tracked, NOT this PR):**
- `grafana` + `loki` repo migration: `grafana.github.io/helm-charts` → `grafana-community.github.io/helm-charts` (chart versions 10→12, 6→17 — values adaptation needed)
- `prometheus-operator` → `kube-prometheus-stack` (9→86, massive breaking — own spec)

## What changes (this PR)

| Chart | Current | New | Repo |
|-------|---------|-----|------|
| spark-3.5 prometheus dep | `25.x.x` (locked 25.30.2) | `25.x.x` (re-lock latest 25.x) | prometheus-community (unchanged) |
| spark-3.5 grafana dep | `8.x.x` (locked 8.15.0) | `8.x.x` (re-lock latest 8.x) | grafana (unchanged) |
| spark-4.0 prometheus dep | `25.x.x` | `25.x.x` (re-lock) | prometheus-community |
| spark-4.0 grafana dep | `8.x.x` | `8.x.x` (re-lock) | grafana |
| spark-4.0 loki dep | `6.x.x` (locked 6.53.0) | `6.x.x` (re-lock latest 6.x = 6.55.0) | grafana |
| observability/grafana | `>=6.0.0` (locked 10.5.15) | no change (already latest in repo) | grafana |
| observability/loki | `>=2.0.0` (locked 6.53.0) | bump to 6.55.0 | grafana |
| observability/prometheus | `>=0.50.0` (locked 9.3.2) | no change (deferred — see Q3) | prometheus-community |

### Concrete tasks
1. Bump `loki` constraint in spark-4.0/Chart.yaml and observability/loki/Chart.yaml to allow 6.55.0
2. Re-lock all affected Chart.lock via `helm dependency update`
3. Tighten version constraints where they're overly loose (`>=2.0.0` → `~6.53`)
4. helm lint + helm template on all affected charts
5. Document deferred items (repo migration, kube-prometheus-stack) in spec + report

## Files touched
- `charts/spark-3.5/Chart.yaml` + `Chart.lock`
- `charts/spark-4.0/Chart.yaml` + `Chart.lock`
- `charts/observability/loki/Chart.yaml` + `Chart.lock`
- (possibly) `charts/observability/grafana/Chart.yaml` (tighten constraint)
- `specs/observability-charts-migration/spec.md` (resolve Q1-Q4, document scope decision)
- `docs/reports/observability-charts-bump-2026-06-17.md` (new report)

## Verification
- `helm lint` on spark-3.5, spark-4.0, observability/{loki,grafana,prometheus}, observability-demo
- `helm template` renders observability-demo with values-demo.yaml (datasources, sidecars intact)
- `pre-commit run` green
