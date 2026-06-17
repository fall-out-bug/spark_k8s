---
feature: job-cicd-pipeline
status: draft (backlog skeleton)
created: 2026-06-17
source: docs/drafts/feature-production-operations.md (WS-018-08, WS-018-09)
---

# Spec: Job-Level CI/CD Pipeline

## Problem (from backlog)

Constitution v1.1.0 (active backlog) lists job-level CI/CD as a real want. Today, Spark
jobs and Airflow DAGs are deployed as config (`dags/`, Helm values) with repo-level CI
(`ci-charts.yml`, `ci-docker.yml`), but there is no per-job lifecycle: validate → promote
→ rollback, with data-quality gates. A broken DAG or SparkApplication can reach the
cluster without job-specific validation.

## Goal

A CI/CD pipeline per Spark application / Airflow DAG that:
1. Validates (lints, dry-runs, runs data-quality checks on a sample)
2. Promotes through stages (dev → staging → prod)
3. Supports rollback on failure or data-quality breach

## Scope (preliminary)

### Likely in scope
- Per-job validation gate: `spark-submit --verify` / DAG lint + a sample-run in an ephemeral env
- Data-quality gate (e.g. Great Expectations — `docs/recipes/data-quality/great-expectations-guide.md` exists)
- Promotion mechanism: GitOps (ArgoCD/Flux) OR Helm release per stage
- Rollback runbook + automation

### Likely out of scope
- Full ML pipeline CI/CD (MLflow model promotion — covered by MLflow usage, invariant #7)
- Cross-cluster replication

## Open questions (before plan.md)

- Q1: GitOps tool — ArgoCD, Flux, or manual Helm? Affects the promotion design heavily.
- Q2: Where do data-quality gates run — in CI (GH Actions) or in-cluster (an init step)?
- Q3: Stages — how many (dev/staging/prod)? OpenShift Projects as stage boundaries?
- Q4: Relationship to existing `charts/spark-3.5/presets/` — do presets become the "job templates" promoted?

## References

- Source draft: `docs/drafts/feature-production-operations.md`
- Constitution: `specs/_constitution.md` §Consumers & Invariants
- Data-quality recipe: `docs/recipes/data-quality/great-expectations-guide.md`
- Existing CI: `.github/workflows/ci-charts.yml`, `ci-matrix-p0.yml`

## Next step

Resolve Q1-Q4 (especially Q1 GitOps choice), then write `plan.md`.
