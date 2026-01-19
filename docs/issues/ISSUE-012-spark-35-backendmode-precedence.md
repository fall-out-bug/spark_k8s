# ISSUE-012: Spark Connect 3.5 backendMode not authoritative

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🟠 HIGH (misconfiguration risk)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

In Spark Connect 3.5, `backendMode` is only checked for `standalone`. If a user
sets `backendMode=k8s` but leaves legacy `sparkConnect.master=local`, the chart
falls back to local mode and ignores the backend mode selection.

**Impact:**
- `backendMode` does not reliably control behavior
- Users can silently run in local mode instead of K8s executors

---

## Root Cause

`spark-defaults.conf` rendering prioritizes legacy `master` unless
`backendMode=standalone`. There is no branch for `backendMode=k8s`.

---

## Reproduction

1. Set `sparkConnect.backendMode=k8s` and `sparkConnect.master=local`.
2. Render the configmap.
3. `spark.master` becomes `local[*]` instead of Kubernetes master.

---

## Resolution

Make `backendMode` authoritative:

- If `backendMode=standalone`, use Standalone master.
- Else if `backendMode=k8s`, use Kubernetes master.
- Else fall back to legacy `master` for backward compatibility.

---

## Affected Files

- `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml`

---

## Related

- `charts/spark-3.5/charts/spark-connect/values.yaml`
