# ISSUE-005: Spark 4.1 Hive Metastore cannot write hive-site.xml

**Created:** 2026-01-19  
**Status:** Open  
**Severity:** 🔴 CRITICAL (blocks runtime tests)  
**Feature:** F04 - Spark 4.1.0 Charts

---

## Problem Statement

Hive Metastore 4.0.0 fails because it tries to write `hive-site.xml`
into `/opt/hive/conf`, which is a ConfigMap mount and read-only.
As a result, schema initialization fails and the metastore crashes.

**Observed errors:**
```
/bin/bash: line 1: /opt/hive/conf/hive-site.xml: Permission denied
MetaException(message:Version information not found in metastore.)
```

**Impact:**
- Hive Metastore never starts
- Spark Connect and SQL workloads fail
- Smoke and integration tests fail

---

## Root Cause

The chart renders `hive-site.xml` by overwriting the template path mounted
from ConfigMap, which is read-only.

---

## Reproduction

1. Deploy `charts/spark-4.1` with `hiveMetastore.enabled=true`.
2. Metastore pod CrashLoopBackOff with permission errors.

---

## Proposed Fix

Render `hive-site.xml` into a writable path (e.g. `/tmp/hive-conf`) and
point Hive to it:

- Mount `emptyDir` at `/tmp/hive-conf`
- Write rendered config there
- Set `HIVE_CONF_DIR=/tmp/hive-conf`

This keeps PSS `restricted` compatibility (no privileged paths).

---

## Affected Files

- `charts/spark-4.1/templates/hive-metastore.yaml`
- `charts/spark-4.1/templates/hive-metastore-configmap.yaml`

---

## Related

- `scripts/test-spark-41-smoke.sh`
- `scripts/test-spark-41-integrations.sh`
