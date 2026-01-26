# ISSUE-025: Spark Connect Standalone backend fails across namespaces

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (jobs never get resources)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect (standalone backend) in a different namespace from the Standalone
cluster stalls with:
```
Initial job has not accepted any resources
```

**Impact:**
- Jobs never acquire resources
- Load tests hang indefinitely

---

## Root Cause

`spark.driver.host` defaults to `spark-connect`, which is only resolvable inside
the same namespace. Standalone workers in a different namespace cannot resolve
the driver host.

---

## Resolution

Allow configuring driver host/ports via values and use FQDN when cross-namespace:
```
sparkConnect.driver.host=spark-connect.<ns>.svc.cluster.local
```

---

## Affected Files

- `charts/spark-3.5/charts/spark-connect/values.yaml`
- `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml`
