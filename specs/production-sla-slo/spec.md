---
feature: production-sla-slo
status: draft (backlog skeleton)
created: 2026-06-17
source: docs/drafts/feature-production-operations.md (WS-018-04, WS-018-07)
---

# Spec: Production SLA/SLO

## Problem (from backlog)

Constitution v1.1.0 (Consumers & Invariants, active backlog) records target SLOs:
99.9% Spark-Connect availability, RTO < 30 min, RPO < 1 h, MTTR < 30 min. As of the
2026-06-17 audit, only **3 of 17** production-operations workstreams are done
(`docs/archive/sdp-workstreams/MEMORIES.md` F18). There is no alerting wired to these
SLOs and no runbook for SLO breach.

## Goal

Operational SLOs that are **measurable and alerted**:
- Spark-Connect uptime ≥ 99.9% (rolling 30d), with a Prometheus alert on burn rate.
- Backup/restore runbook delivering RTO < 30 min / RPO < 1 h, tested.
- On-call escalation referencing MTTR targets.

## Scope (preliminary)

### Likely in scope
- SLO dashboards in Grafana (`spark-connect` availability, error budget)
- AlertManager rules: SLO burn-rate, Spark-Connect down, backup failure
- Restore-from-backup runbook + a tested restore drill
- Define an escalation-paths runbook (the prior `on-call/escalation-paths.md` was archived 2026-08-09 as enterprise-SRE theater; recreate a Spark-specific one when implementing)

### Likely out of scope
- Multi-cluster federation
- Cost SLOs (separate spec `cost-attribution`)

## Open questions (before plan.md)

- Q1: What defines "Spark-Connect availability" — the gRPC port, a synthetic query, or
  successful job-submission rate?
- Q2: Where are backups stored today (MinIO bucket? external?), and is RPO < 1h
  achievable with current backup cadence?
- Q3: 99.9% = ~43 min/month error budget — is that the right target for an analytics
  platform (vs. a stricter/weaker tier)?

## References

- Source draft: `docs/drafts/feature-production-operations.md`
- Constitution: `specs/_constitution.md` §Consumers & Invariants (active backlog)
- Existing dashboards: `charts/observability/grafana/dashboards/` (rto-rpo, slo-forecast, incident-metrics exist as static JSON — need live wiring)

## Next step

Resolve Q1-Q3 with the S7 team (primary consumer), then write `plan.md`.
