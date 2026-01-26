# ISSUE-011: Connect load test scripts assume wrong service name

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (load tests fail immediately)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

The new load test scripts port-forward `svc/${RELEASE}-connect`, but actual
service names differ by chart:

- Spark 3.5 Connect service: `spark-connect` (static)
- Spark 4.1 Connect service: `${RELEASE}-spark-41-connect`

This causes immediate failures:

```
error: services "<release>-connect" not found
```

**Impact:**
- Both load test scripts fail before running any workload
- Validation docs are misleading

---

## Root Cause

Scripts hardcode `svc/${RELEASE}-connect` and do not resolve the real service
name by labels or chart-specific naming.

---

## Reproduction

1. Deploy Spark Connect (3.5 or 4.1).
2. Run `scripts/test-spark-connect-*-load.sh`.
3. `kubectl port-forward` fails with "service not found".

---

## Resolution

Resolve the Spark Connect service name by labels:

```
kubectl get svc -l "app=spark-connect,app.kubernetes.io/instance=${RELEASE}" ...
```

Use the detected service name for port-forward.

---

## Affected Files

- `scripts/test-spark-connect-k8s-load.sh`
- `scripts/test-spark-connect-standalone-load.sh`

---

## Related

- `docs/guides/en/validation.md`
- `docs/guides/ru/validation.md`
