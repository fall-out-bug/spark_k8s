# Specs Index (legacy spec-kit)

> **These are legacy spec-kit specs, kept as reference.** New work goes through
> **OpenSpec** (`openspec/`). Do not add new specs here.
>
> This index was reconciled 2026-08-09 against shipped reality. Previous versions
> overstated several specs as "Plan + impl" when the work was aspirational or
> only partially delivered.

## Constitution

- [_constitution.md](_constitution.md) — project-wide principles + Consumers & Invariants, v1.1.0

## Status legend

- ✅ **DELIVERED** — work shipped and verified
- 🔧 **OPEN** — actively in progress or decision pending
- 💤 **ASPIRATIONAL** — idea / backlog skeleton, no plan or tasks; not started

## Specs

| Feature | Status | Notes |
|---------|--------|-------|
| Grafana Observability Stand | ✅ DELIVERED | 36/36 tasks, PR #9. The one fully completed spec. |
| Harden Default Credentials | ✅ DELIVERED | 25/25 shipped (PRs #23/#28/#29/#30/#31). 0 hardcoded creds, `required`-enforced, `test_credential_leak.py` guard. |
| GHCR Publish Pipeline | ✅ DELIVERED | 23/23 shipped (PRs #15/#22/#24/#33). `publish-images.yml` + ci-docker 4.1.1. GAP-1/GAP-3 resolved. |
| Spark Load Tests (10GB NYC Taxi) | 🔧 OPEN | 0/30 tasks. Infra exists; load tests not yet run. |
| Spark Operator v2 Migration | 🔧 OPEN | Decision pending: apache/spark-kubernetes-operator vs kubeflow/spark-operator. Current chart on deprecated googlecloudplatform image + 24,888 LOC vendored CRDs. |
| Airflow 3 Migration | 💤 ASPIRATIONAL | Chart still pins Airflow 2.11.0. Spec is open-questions only, no plan/tasks. (Index previously claimed impl — incorrect.) |
| Observability Charts Migration | 💤 ASPIRATIONAL | spark-4.1 observability deps still commented out. No tasks. |
| Smoke Scenario Generator Cleanup | 💤 ASPIRATIONAL | Backlog skeleton. Scripts-only, no chart change. |
| Cost Attribution | 💤 ASPIRATIONAL | cost-exporter exists; attribution/alerting loop unclosed. Spec only. |
| Job-Level CI/CD Pipeline | 💤 ASPIRATIONAL | No GitOps / Great-Expectations. Env values dirs only. |
| HA for Spark Standalone Master | 💤 ASPIRATIONAL | `master.yaml` hardcodes `replicas: 1`; no leader election. Spec only. |
| Production SLA/SLO | 💤 ASPIRATIONAL | Only primitive is backup-cronjob. No burn-rate alerts. Spec only. |

## New work

Use OpenSpec:

```
openspec new change "Add feature X"   # openspec/changes/<id>/
openspec apply <id>
openspec verify <id>
openspec archive <id>
```

Slash commands: `/opsx:new`, `/opsx:apply`, `/opsx:verify`, `/opsx:archive`.

## Historical Archive

Pre-migration (SDP workstream format, 35+ features, 28+ completed WS):

- [docs/archive/sdp-workstreams/MEMORIES.md](../docs/archive/sdp-workstreams/MEMORIES.md) — meta-library of historical project state (read-only provenance)
- [docs/archive/sdp-workstreams/INDEX.md](../docs/archive/sdp-workstreams/INDEX.md) — feature/WS index

Do NOT add new work to the archive or to `specs/`. New features use OpenSpec only.
