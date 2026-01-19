# ISSUE-007: Spark 4.1 assumes `s3-credentials` secret exists

**Created:** 2026-01-19  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (blocks runtime tests)  
**Feature:** F04 - Spark 4.1.0 Charts

---

## Problem Statement

Spark 4.1 components require a secret named `s3-credentials`, but the
chart does not create it. On a clean namespace, pods fail with:

```
Error: secret "s3-credentials" not found
```

**Impact:**
- Spark Connect, History Server, and Jupyter do not start
- Smoke and integration tests fail

---

## Root Cause

`charts/spark-4.1` references `s3-credentials` in multiple templates
without providing a way to create it or override the secret name.

---

## Reproduction

1. Deploy `charts/spark-4.1` in a clean namespace.
2. Pods fail with missing secret error.

---

## Resolution

Added configurable secret name:

- `global.s3.existingSecret` (default `s3-credentials`)
- Templates reference the configured secret

This keeps compatibility with OpenShift/PSS requirements.

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`
- `charts/spark-4.1/templates/history-server.yaml`
- `charts/spark-4.1/templates/jupyter.yaml`
- `charts/spark-base/templates/minio.yaml`

---

## Fix Reference

- Workstream: `docs/workstreams/completed/WS-BUG-007-s3-credentials-secret.md`

## Related

- `scripts/test-spark-41-smoke.sh`
- `scripts/test-spark-41-integrations.sh`
