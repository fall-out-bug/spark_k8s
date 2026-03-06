# ADR-0010: Observability-Demo Chart — Values Must Provide Grafana Subchart Defaults

## Status

Accepted (2026-03-06)

## Context

`charts/observability-demo` is an umbrella chart with subcharts: prometheus-spark, loki-spark, grafana-spark. The Grafana subchart (Bitnami) expects nested values: `sidecar.alerts.enabled`, `sidecar.notifiers.enabled`, `sidecar.plugins.enabled`, `imageRenderer.enabled`, `grafana.ini.paths`, `grafana.ini.unified_storage.index_path`, `persistence.inMemory.enabled`.

When `helm lint charts/observability-demo` runs with default `values.yaml`, these values can be nil — Grafana templates dereference them and fail with "nil pointer evaluating interface {}.enabled".

Initial fix used `-f values-demo.yaml` in CI. That violated "Right over fast" — workaround, not root cause fix.

## Decision

**values.yaml must provide all Grafana subchart defaults** required for `helm lint` to pass without `-f`:

- `prometheus-spark.prometheus-operator.grafana`: sidecar (alerts, notifiers, plugins), imageRenderer, grafana.ini, persistence.inMemory
- `grafana-spark.grafana`: same structure

`values-demo.yaml` overrides for demo (NodePort, datasources, targetNamespace) but base defaults live in `values.yaml`.

## Consequences

- **Pros:** helm lint passes; no CI workarounds; aligns with .cursorrules "helm lint passes AND helm template renders"
- **Cons:** values.yaml is longer; must be updated if Grafana subchart adds new required keys

## References

- F31 review: `docs/reports/review-F31-00-031-2026-03-06.md`
- MEMORIES: F16, F31 sections
