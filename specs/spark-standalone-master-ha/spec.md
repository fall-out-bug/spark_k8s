---
feature: spark-standalone-master-ha
status: draft (backlog skeleton)
created: 2026-06-17
source: docs/adr/ADR-0001-spark-standalone-master-ha-pvc.md
---

# Spec: HA for Spark Standalone Master

## Problem (from backlog)

Constitution v1.1.0 (active backlog) lists HA for Spark Standalone Master as a real want.
ADR-0001 documents the design (Zookeeper-based leader election + shared WAL on PVC), but
the 2026-06-17 audit could **not confirm** whether the chart actually implements it. A
single Master is a SPOF for standalone-mode scenarios (`values-scenario-*-standalone.yaml`).

## Goal

Spark Standalone Master runs in HA (≥ 2 replicas with leader election), so a Master pod
failure does not kill running applications or block new submissions in standalone mode.

## Scope (preliminary)

### Likely in scope
- Verify / implement ADR-0001 in `charts/spark-3.5/charts/spark-standalone/templates/`
- Zookeeper (or alternative: Kubernetes lease) for leader election
- Shared WAL storage (PVC or S3 — note S3 path already in `charts/values-common.yaml`)
- Update standalone scenarios + docs

### Likely out of scope
- Spark Connect HA (different architecture — Spark Connect is stateless, HA = replicas
  behind a Service; likely already works, verify separately)
- Spark Operator HA (covered by `spark-operator-v2-migration` spec)

## Open questions (before plan.md)

- Q1: **Verify current state first** — does `charts/spark-3.5/charts/spark-standalone/`
  already support `master.replicas > 1`? Need to read the template.
- Q2: Leader election backend — Zookeeper (heavyweight, ADR-0001's choice) vs the
  lighter Kubernetes `spark.master` HA via `--deploy-mode cluster`?
- Q3: Is standalone mode still a primary use case, or has Spark Connect (invariant #8)
  largely superseded it? Affects whether this is worth the Zookeeper complexity.

## References

- ADR-0001: `docs/adr/ADR-0001-spark-standalone-master-ha-pvc.md`
- Constitution: `specs/_constitution.md` §Consumers & Invariants (active backlog)
- Standalone chart: `charts/spark-3.5/charts/spark-standalone/`

## Next step

Resolve Q1 (verify current template state) first — it may turn this into a small fix or
confirm a full implementation is needed. Then Q2-Q3, then `plan.md`.
