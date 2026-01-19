# ISSUE-008: Jupyter 4.1 fails to start (runtime dir permission)

**Created:** 2026-01-19  
**Status:** Open  
**Severity:** 🔴 CRITICAL (blocks runtime tests)  
**Feature:** F04 - Spark 4.1.0 Charts

---

## Problem Statement

Jupyter 4.1.0 fails to start with permission errors when creating
runtime directories under `/nonexistent/.local/...`.

**Observed error:**
```
PermissionError: [Errno 13] Permission denied: '/nonexistent'
```

**Impact:**
- Jupyter pod CrashLoopBackOff
- Integration tests fail (Jupyter + Spark Connect)

---

## Root Cause

The container runs as a non-root user without a valid home directory.
Jupyter defaults to `/nonexistent` and cannot create runtime directories.

---

## Reproduction

1. Deploy `charts/spark-4.1` with `jupyter.enabled=true`.
2. Jupyter pod fails with runtime dir permission errors.

---

## Proposed Fix

Set writable runtime directories in the chart:

- `HOME=/home/spark`
- `JUPYTER_RUNTIME_DIR=/tmp/jupyter-runtime`
- Mount `emptyDir` at `/tmp/jupyter-runtime` if needed

This remains compatible with PSS `restricted`.

---

## Affected Files

- `charts/spark-4.1/templates/jupyter.yaml`
- `docker/jupyter-4.1/Dockerfile` (optional, if HOME needs creation)

---

## Related

- `scripts/test-spark-41-integrations.sh`
