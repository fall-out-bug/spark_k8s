# Idea: Chart Architecture DRY (F28)

**Date:** 2026-02-13
**Source:** repo-audit-2026-02-13.md (Architecture Quality, items AR-1..AR-7)
**Priority:** Medium

## Problem

Significant template duplication between spark-3.5 and spark-4.1 charts:
- hive-metastore, postgresql, monitoring templates are near-identical
- Duplicate templates within spark-4.1 (rbac.yaml + rbac/, keda + autoscaling/)
- values.yaml > 460 LOC without schema validation
- No `values.schema.json` for Helm validation
- No `templates/tests/` for `helm test`

## Solution

Extract shared templates to spark-base library chart, remove duplicates, add JSON Schema validation.

## Users Affected

- Maintainers (less duplication to maintain)
- DevOps (schema validation catches errors early)

## Success Metrics

- Zero duplicate templates
- values.schema.json validated on `helm install`
- `helm test` passes for both charts
