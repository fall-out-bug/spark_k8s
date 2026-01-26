# ISSUE-023: Spark 4.1 Connect client missing zstandard dependency

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (Connect client fails)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect client fails with:
```
pyspark.errors.exceptions.base.PySparkImportError:
[PACKAGE_NOT_INSTALLED] zstandard >= 0.25.0 must be installed; however, it was not found.
```

**Impact:**
- Spark Connect load tests fail
- Jupyter / client containers cannot connect to Spark Connect

---

## Root Cause

`zstandard` Python package is missing from Spark 4.1 client images, but it is a
mandatory dependency for PySpark Connect.

---

## Reproduction

1. Run Spark Connect 4.1 load test in-cluster.
2. PySpark Connect fails during session creation.

---

## Resolution

Add `zstandard>=0.25.0` to Spark 4.1 client images:
- `docker/spark-4.1/deps/requirements.txt`
- `docker/jupyter-4.1/Dockerfile`

---

## Affected Files

- `docker/spark-4.1/deps/requirements.txt`
- `docker/jupyter-4.1/Dockerfile`
