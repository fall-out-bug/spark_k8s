---
feature: cost-attribution
status: draft (backlog skeleton)
created: 2026-06-17
source: docs/drafts/feature-production-operations.md (WS-018-10, WS-018-11)
---

# Spec: Per-Job / Per-Team Cost Attribution

## Problem (from backlog)

Constitution v1.1.0 (active backlog) lists cost attribution as a real want. There is
no mechanism today to attribute Spark/Airflow resource cost to a job or team, and no
budget alerts. The `cost-by-job.json` and `cost-by-team.json` Grafana dashboards exist
as static JSON but have no data source feeding them (no cost-exporter, no label-based
attribution).

## Goal

Every Spark application and Airflow DAG run can be attributed a resource cost
(CPU-seconds, memory-GB-seconds, optionally $), aggregatable by team/namespace/label,
with a budget alert when a threshold is exceeded.

## Scope (preliminary)

### Likely in scope
- Attribution key: standardized labels (`team=`, `cost-center=`, `project=`) on
  SparkApplications / Airflow DAGs / pods
- A cost-exporter or kube-prometheus-stack integration that derives cost from
  `container_cpu_usage_seconds_total` / `container_memory_working_set_bytes` × node price
- Wire `cost-by-job.json` + `cost-by-team.json` dashboards to real data
- AlertManager rule: budget threshold breach per team

### Likely out of scope
- Cloud provider billing integration (AWS Cost Explorer / GCP)
- GPU-hour accounting (depends on invariant #4 GPU migration)

## Open questions (before plan.md)

- Q1: What's the attribution key scheme? Existing `docs/recipes/governance/naming-conventions.md`
  has prefixes (`prod_`, `analytics_`) — reuse or define labels?
- Q2: Node price source — static `$` map per instance type, or scrape cloud billing?
- Q3: Is OpenShift (invariant #10) the target, where Project quota already exists? Reuse
  OpenShift quota as the attribution boundary?

## References

- Source draft: `docs/drafts/feature-production-operations.md`
- Constitution: `specs/_constitution.md` §Consumers & Invariants
- Existing dashboards: `charts/observability/grafana/dashboards/cost-by-{job,team}.json`
- Naming conventions: `docs/recipes/governance/naming-conventions.md`

## Next step

Resolve Q1-Q3, then write `plan.md`.
