# UAT Guide: F18 — Production Operations Suite

**Feature:** F18  
**Date:** 2026-02-10  

---

## Overview

F18 provides runbooks, recovery scripts, and operational procedures for Spark on Kubernetes. WS-018-02 (Spark Failure Runbooks) and WS-018-03 (Data Recovery) are the primary deliverables.

---

## Prerequisites

- [ ] Kubernetes cluster with Spark deployment
- [ ] `kubectl` configured
- [ ] Hive Metastore, MinIO/S3 available (for recovery scripts)

---

## Quick Verification (30 seconds)

### Runbook docs exist

```bash
ls docs/operations/runbooks/spark/*.md | wc -l  # Expected: 8
ls docs/operations/runbooks/data/*.md | wc -l   # Expected: 4
```

### Recovery scripts syntax

```bash
for f in scripts/operations/recovery/*.sh; do bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"; done
```

### Spark diagnose scripts

```bash
ls scripts/operations/spark/diagnose-*.sh | wc -l  # Expected: 7
```

---

## Detailed Scenarios

### Scenario 1: Runbook structure validation

```bash
python tests/operations/test_runbooks.py  # When pytest tests added
```

### Scenario 2: Recovery script dry-run

```bash
./scripts/operations/recovery/check-metadata-consistency.sh --help
./scripts/operations/recovery/restore-hive-metastore.sh --help
```

### Scenario 3: Spark diagnosis

```bash
./scripts/operations/spark/diagnose-driver-crash.sh --help
```

---

## Red Flags

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | bash -n fails on any script | 🔴 HIGH |
| 2 | Runbook missing required sections | 🟡 MEDIUM |
| 3 | pytest tests/operations/ collects 0 | 🟡 MEDIUM |

---

## Sign-off

- [ ] All recovery scripts pass bash -n
- [ ] 8 spark runbooks + 4 data runbooks exist
- [ ] pytest tests/operations/ has discoverable tests

---

**Human tester:** Complete UAT before F18 deployment.
