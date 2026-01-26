# ISSUE-014: Spark 4.1 Spark Connect fails because `envsubst` is missing

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect CrashLoopBackOff)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1.0 container fails to start because the image lacks `envsubst`,
yet the startup command relies on it to render templates:

```
/bin/sh: 1: envsubst: not found
```

**Impact:**
- Spark Connect pod CrashLoopBackOff
- K8s backend load tests cannot run

---

## Root Cause

`charts/spark-4.1/templates/spark-connect.yaml` runs `envsubst` in the main
container, but the `spark-custom:4.1.0` image does not include `envsubst`.

---

## Reproduction

1. Deploy `charts/spark-4.1` with Spark Connect enabled.
2. Pod logs show `envsubst: not found` and CrashLoopBackOff.

---

## Resolution

Render templates in an init container that installs `envsubst`:

- Add init container using `alpine:3.19`
- Install `gettext` (`envsubst`) and render templates into `/tmp/spark-conf`
- Main container starts Spark Connect using rendered config

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
