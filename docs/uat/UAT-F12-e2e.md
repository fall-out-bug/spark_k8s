# UAT: F12 Phase 6 — E2E Tests

**Feature:** F12 - Phase 6 E2E Tests  
**Review Date:** 2026-02-10

---

## Overview

F12 provides 80 E2E test scenarios across 6 categories: Core (24), GPU (16), Iceberg (16), GPU+Iceberg (8), Standalone (8), Library compatibility (8). Uses pytest, NYC Taxi dataset (sample/full), standard SQL queries (Q1-Q4), metrics collection.

---

## Prerequisites

- Python 3.10+ with pytest, pyspark
- Optional: k8s cluster, GPU nodes, Hive Metastore (tests skip if unavailable)

---

## Quick Verification (2 minutes)

### Smoke Test

```bash
# Syntax check
python -m py_compile scripts/tests/e2e/conftest.py
python -m py_compile scripts/tests/e2e/test_jupyter_k8s_357.py

# List test files
ls scripts/tests/e2e/test_*.py | wc -l
# Expected: 26+

# Run single test (may skip if no cluster)
cd scripts/tests/e2e && pytest test_jupyter_k8s_357.py -v --timeout=60 2>&1 | head -30
```

### Quick Check

```bash
# Verify structure
ls scripts/tests/e2e/conftest.py
ls scripts/tests/e2e/queries/*.sql
ls scripts/tests/e2e/fixtures_*.py
# Expected: conftest, 4 queries, 4 fixture files
```

---

## Detailed Scenarios

### Scenario 1: Core E2E

```bash
cd scripts/tests/e2e
pytest -v -k "jupyter_k8s or airflow_k8s or jupyter_connect or airflow_connect" --timeout=1200
```

### Scenario 2: GPU E2E (requires GPU)

```bash
pytest -v -k "gpu" --timeout=1200
```

### Scenario 3: Iceberg E2E

```bash
pytest -v -k "iceberg" --timeout=1200
```

### Scenario 4: Standalone E2E

```bash
pytest -v -k "standalone" --timeout=1200
```

### Scenario 5: Library Compatibility

```bash
pytest -v -k "compatibility" --timeout=60
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | Import error in e2e | pytest output | HIGH |
| 2 | conftest.py missing | ls | HIGH |
| 3 | queries/*.sql missing | ls | MEDIUM |

---

## Code Sanity Checks

```bash
# All categories present
grep -l "def test_" scripts/tests/e2e/test_*.py | wc -l
# Expected: 26+

# Queries exist
ls scripts/tests/e2e/queries/*.sql
# Expected: q1_count, q2_aggregation, q3_join, q4_window
```

---

## Sign-off Checklist

- [ ] conftest.py, pytest.ini exist
- [ ] All 6 WS categories have test files
- [ ] pytest -v --collect-only succeeds
- [ ] Red flags absent

---

## Related Documents

- Phase spec: `docs/phases/phase-06-e2e.md`
- Summary: `scripts/tests/e2e/E2E_TEST_SUMMARY.md`
- Workstreams: `docs/workstreams/completed/00-012-*.md`
