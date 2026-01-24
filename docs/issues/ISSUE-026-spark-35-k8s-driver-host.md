# ISSUE-026: Spark 3.5 K8s executors cannot resolve Connect driver host

**Created:** 2026-01-24  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (executors fail, SparkContext stops)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 3.5 with Kubernetes executors fails; executor pods error:
```
java.net.UnknownHostException: spark-connect
```

**Impact:**
- Executors cannot connect to driver
- SparkContext stops after max executor failures
- Load tests fail
- Pod `spark-connect` in CrashLoopBackOff

---

## Root Cause

Driver host defaults to `spark-connect`, which is not resolvable in K8s
namespace without a headless service / subdomain. The Connect service does not expose
driver and blockmanager ports for executor connectivity.

In K8s mode, executors need to resolve the driver's FQDN to connect,
not just a short service name.

---

## Reproduction

1. Deploy `charts/spark-3.5/charts/spark-connect` with `backendMode=k8s`.
2. Check pod logs:
   ```
   26/01/24 18:30:32 INFO SparkConnectServer: Spark Connect server started at: 0:0:0:0:0:0:0%0:15002
   ```
3. Check events:
   ```
   Liveness probe failed: dial tcp 10.244.7.213:15002: i/o timeout
   Readiness probe failed: dial tcp 10.244.7.213:15002: connect: connection refused
   ```

---

## Resolution

For K8s mode, set driver host to FQDN:
```
spark.driver.host=<service-name>.<namespace>.svc.cluster.local
```

The script `test-e2e-jupyter-connect.sh` already passes this correctly:
```bash
CONNECT_DRIVER_HOST="${CONNECT_SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
```

Fix charts/spark-3.5/charts/spark-connect/templates/configmap.yaml:
- When `backendMode=k8s`, set `spark.driver.host=<FQDN>` using a template variable
- When `backendMode=standalone`, keep current default behavior

---

## Affected Files

- `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml`
- `charts/spark-3.5/charts/spark-connect/values.yaml` (may need driver.host template variable)

---

## Related

- ISSUE-024: Spark 4.1 K8s executors cannot resolve Connect driver host (resolved)
- ISSUE-025: Connect standalone driver host FQDN (resolved)
