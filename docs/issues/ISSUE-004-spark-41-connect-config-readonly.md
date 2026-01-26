# ISSUE-004: Spark 4.1 Spark Connect cannot write config (read-only ConfigMap)

**Created:** 2026-01-19  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (blocks runtime tests)  
**Feature:** F04 - Spark 4.1.0 Charts

---

## Problem Statement

Spark Connect 4.1.0 fails to start because the entrypoint tries to write
generated configs into `/opt/spark/conf-k8s`, which is a ConfigMap mount
and read-only. This causes CrashLoopBackOff and blocks smoke/integration tests.

**Observed error:**
```
/bin/sh: 1: cannot create /opt/spark/conf-k8s/spark-properties.conf: Permission denied
```

**Impact:**
- Spark Connect never becomes ready
- Smoke tests fail (`scripts/test-spark-41-smoke.sh`)
- Integration tests fail (`scripts/test-spark-41-integrations.sh`)

---

## Root Cause

The chart mounts templates from ConfigMaps at `/opt/spark/conf-k8s` and then
uses `envsubst` to write the rendered files into the same read-only path.

---

## Reproduction

1. Deploy `charts/spark-4.1` with Spark Connect enabled.
2. Pod enters CrashLoopBackOff with permission error.

---

## Resolution

Rendered config files are written into a writable `emptyDir` (`/tmp/spark-conf`)
and `SPARK_CONF_DIR` points to that directory:

- Templates mounted read-only at `/opt/spark/conf-k8s-templates`
- Rendered files written to `/tmp/spark-conf`
- Spark started with `--properties-file /tmp/spark-conf/spark-properties.conf`

This is compatible with PSS `restricted`.

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`
- `charts/spark-4.1/templates/spark-connect-configmap.yaml`
- `charts/spark-4.1/templates/executor-pod-template-configmap.yaml`

---

## Fix Reference

- Workstream: `docs/workstreams/completed/WS-BUG-004-spark-41-connect-readonly-config.md`

## Related

- `scripts/test-spark-41-smoke.sh`
- `scripts/test-spark-41-integrations.sh`
