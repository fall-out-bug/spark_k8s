# ISSUE-010: Spark Connect 3.5 Standalone backend lacks driver/blockmanager ports

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (Standalone backend unusable)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 3.5 Standalone backend sets `spark.driver.host=spark-connect`,
but the chart exposes driver/blockmanager ports **only** in K8s executors mode.
Standalone executors cannot connect back to the driver.

**Observed error (example):**
```
org.apache.spark.SparkException: Failed to connect to driver at spark-connect:7078
```

**Impact:**
- Standalone backend jobs fail to start or hang
- Connect+Standalone mode is not functional
- Load tests for Standalone backend fail

---

## Root Cause

`charts/spark-3.5/charts/spark-connect/templates/spark-connect.yaml` only
opens ports `7078/7079` when `backendMode=k8s` or legacy `master=k8s`.
Standalone backend needs these ports open as well.

---

## Reproduction

1. Deploy `charts/spark-3.5` with `sparkConnect.backendMode=standalone`.
2. Submit a Spark job via Spark Connect.
3. Executors fail to connect to driver host/ports.

---

## Resolution

Expose driver/blockmanager ports when `backendMode=standalone`:

- Add `7078/7079` container ports in Standalone backend mode
- Add `7078/7079` service ports in Standalone backend mode

This preserves PSS/OpenShift compatibility.

---

## Affected Files

- `charts/spark-3.5/charts/spark-connect/templates/spark-connect.yaml`

---

## Related

- `scripts/test-spark-connect-standalone-load.sh`
