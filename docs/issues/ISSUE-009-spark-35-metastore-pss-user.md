# ISSUE-009: Spark 3.5 Hive Metastore fails with PSS `runAsNonRoot`

**Created:** 2026-01-19  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (blocks coexistence/benchmark tests)  
**Feature:** F04 - Spark 4.1.0 Charts (coexistence)

---

## Problem Statement

Spark 3.5 Hive Metastore (`apache/hive:3.1.3`) fails to start under
PSS `restricted` because Kubernetes cannot verify that the image user
(`hive`) is non-root.

**Observed error:**
```
Error: container has runAsNonRoot and image has non-numeric user (hive),
cannot verify user is non-root
```

**Impact:**
- Spark 3.5 metastore pod stays in `CreateContainerConfigError`
- `helm install --wait` times out for 3.5 chart
- Coexistence and benchmark tests fail

---

## Root Cause

The image defines a non-numeric user name (`hive`), and the chart enforces
`runAsNonRoot` under PSS. Kubernetes requires a numeric UID to validate
`runAsNonRoot`.

---

## Reproduction

1. Deploy `charts/spark-3.5` with PSS enabled (`security.podSecurityStandards=true`).
2. Metastore pod fails with `CreateContainerConfigError`.

---

## Resolution

Explicitly set numeric `runAsUser`/`runAsGroup` for the metastore container
when PSS is enabled, and expose UID/GID under `hiveMetastore.security` for
OpenShift ranges (avoids affecting Spark master/worker UIDs).

This preserves OpenShift compatibility without relaxing PSS.

---

## Affected Files

- `charts/spark-3.5/charts/spark-standalone/values.yaml`
- `charts/spark-3.5/charts/spark-standalone/templates/hive-metastore.yaml`

---

## Fix Reference

- Workstream: `docs/workstreams/completed/WS-BUG-009-spark-35-metastore-uid.md`

## Related

- `scripts/test-coexistence.sh`
- `scripts/benchmark-spark-versions.sh`
