# Report: Observability charts conservative bump (2026-06-17)

Branch: `feat/grafana-loki-prometheus-migration`

## Context

Grafana/Loki/Prometheus subcharts faced two issues: (1) the `grafana/helm-charts`
repository migrated to `grafana-community/helm-charts` (Jan 30 / Mar 16 2026);
(2) `prometheus-operator` was renamed to `kube-prometheus-stack` and is now ~86.x
(we were on 9.3.2). Both involve **massive breaking changes** (loki 6→17, prom-op 9→86).

To protect invariant #2 (Airflow + Spark monitoring in Grafana), this PR takes a
**conservative path**: version bumps within the current repositories, deferring
the repo-migration and the prometheus-operator rename to separate specs.

## What changed (this PR)

| Chart | Before | After | Note |
|-------|--------|-------|------|
| `observability/loki` Chart.yaml constraint | `>=2.0.0` (admits 17.x from community!) | `>=6.53.0,<7.0.0` | Tightened — blocks accidental 7.x+ jump |
| `observability/loki` Chart.lock | 6.53.0 | **6.55.0** | Last 6.x in grafana repo |
| `observability/grafana` Chart.yaml constraint | `>=6.0.0` (admits 12.x!) | `>=10.0.0,<11.0.0` | Tightened — blocks 11.x+ |
| `observability/grafana` Chart.lock | 10.5.15 | 10.5.15 | Already latest (no version change) |
| `spark-4.0/Chart.lock` (loki entry) | 6.53.0 | **6.55.0** | Re-locked |

**Caught a regression during implementation:** my first constraint attempt used
`~6.53` (semver tilde) which means `>=6.53.0, <6.54.0` — it would have *pinned* to
6.53.x and silently prevented the 6.55.0 bump. Similarly `~10.0` would have
**downgraded** grafana from 10.5.15 to 10.0.0. Fixed to explicit range bounds
(`>=X,<Y`) which are unambiguous.

## Why conservative (what's NOT in this PR)

### Deferred to `specs/observability-charts-migration/` future PRs:

1. **grafana + loki repo migration** (`grafana.github.io` → `grafana-community.github.io`):
   community fork chart versions are grafana 12.x / loki 17.x — far ahead of our
   10.5 / 6.55. Values-schema adaptation required (datasources, sidecar, gateway
   config all may have moved). Self-contained migration spec.

2. **prometheus-operator 9.3.2 → kube-prometheus-stack 86.x**: ~77 major versions
   of breaking changes (CRD v1, values restructure, removed subcharts like
   kubeStateMetrics/nodeExporter). Massive effort; own spec. The current 9.3.2 is
   frozen/deprecated but still installs and works.

3. **Alertmanager + Jaeger**: lower priority (alertmanager repo unchanged; jaeger
   separate).

## Verification done

- `helm lint` on spark-3.5, spark-4.0, spark-4.1, observability/{loki,grafana,prometheus} → all pass
- `helm lint observability-demo` → **pre-existing** nil-pointer in grafana subchart
  (documented in `specs/grafana-observability-stand/` T032); NOT a regression (same
  on clean dev via `git stash` test)
- `helm template observability-demo -f values-demo.yaml` → renders clean (loki:3100,
  grafana image, datasources all present)
- `pre-commit run` → green

## Verification NOT done (requires live cluster)

- Live observability-demo deploy after loki 6.53→6.55 (demo not deployed this session)
- Spark logs flowing into Loki 6.55 (LogQL query sanity)

## References

- Migration: github.com/grafana/helm-charts/issues/4087, github.com/grafana/loki/issues/20705
- Spec: `specs/observability-charts-migration/`
- Constitution: invariant #2
