# ISSUE-024: Spark 4.1 K8s executors cannot resolve Connect driver host

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (executors fail, SparkContext stops)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 with Kubernetes executors fails; executor pods error:
```
java.net.UnknownHostException: sc41-connect-spark-41-connect-...
```

**Impact:**
- Executors cannot connect to driver
- SparkContext stops after max executor failures
- Load tests fail

---

## Root Cause

Driver host defaults to the Connect pod name, which is not resolvable in K8s
without a headless service / subdomain. The Connect service does not expose
driver and blockmanager ports for executor connectivity.

---

## Reproduction

1. Deploy `charts/spark-4.1` with `connect.backendMode=k8s`.
2. Run any Spark Connect workload.
3. Executors fail to resolve driver host.

---

## Resolution

Set stable driver host/ports and expose them via the Connect service:
- `spark.driver.host={{ include "spark-4.1.fullname" . }}-connect`
- `spark.driver.port=7078`
- `spark.driver.blockManager.port=7079`
- Expose ports 7078/7079 in Deployment and Service

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect-configmap.yaml`
- `charts/spark-4.1/templates/spark-connect.yaml`
