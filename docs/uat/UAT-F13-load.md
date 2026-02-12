# UAT: F13 Phase 7 — Load Tests

**Feature:** F13 - Phase 7 Load Tests  
**Review Date:** 2026-02-10

---

## Overview

F13 provides 20 load test scenarios across 5 categories: Baseline (4), GPU (4), Iceberg (4), Comparison (4), Security stability (4). Sustained load 30 min per test. Metrics: throughput, latency percentiles, error rate, GPU utilization, Iceberg ops.

---

## Prerequisites

- Python 3.10+ with pytest, pyspark
- Spark Connect deployment (for baseline, GPU, Iceberg, comparison)
- Optional: GPU nodes, Iceberg catalog, k8s cluster

---

## Quick Verification (2 minutes)

### Smoke Test

```bash
# Syntax check
python -m py_compile scripts/tests/load/conftest.py
python -m py_compile scripts/tests/load/baseline/test_baseline_select_358.py

# List test files
ls scripts/tests/load/baseline/*.py scripts/tests/load/gpu/*.py scripts/tests/load/iceberg/*.py scripts/tests/load/comparison/*.py scripts/tests/load/security/*.py | wc -l
# Expected: 20

# Collect tests (no run)
cd scripts/tests/load && pytest --collect-only -q 2>&1 | tail -5
```

### Quick Check

```bash
# Verify structure
ls scripts/tests/load/conftest.py scripts/tests/load/run-load-tests.sh
ls scripts/tests/load/baseline/ scripts/tests/load/gpu/ scripts/tests/load/iceberg/
ls scripts/tests/load/comparison/ scripts/tests/load/security/
# Expected: 5 directories with 4 tests each
```

---

## Detailed Scenarios

### Scenario 1: Baseline Load

```bash
cd scripts/tests/load
pytest baseline/ -v --timeout=2400
# Requires Spark Connect + nyc_taxi table
```

### Scenario 2: GPU Load

```bash
pytest gpu/ -v --timeout=2400
# Requires GPU-enabled Spark
```

### Scenario 3: Iceberg Load

```bash
pytest iceberg/ -v --timeout=2400
# Requires Iceberg catalog
```

### Scenario 4: Comparison Load

```bash
pytest comparison/ -v --timeout=3600
# Requires both 3.5.8 and 4.1.1
```

### Scenario 5: Security Stability

```bash
pytest security/ -v --timeout=2400
# Requires k8s + security presets
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | Import error in load tests | pytest output | HIGH |
| 2 | conftest.py missing | ls | HIGH |
| 3 | run-load-tests.sh fails | bash output | MEDIUM |

---

## Code Sanity Checks

```bash
# All categories present
for d in baseline gpu iceberg comparison security; do
  echo -n "$d: "; ls scripts/tests/load/$d/test_*.py 2>/dev/null | wc -l
done
# Expected: 4 each
```

---

## Sign-off Checklist

- [ ] conftest.py, pytest.ini exist
- [ ] All 5 categories have 4 test files
- [ ] pytest --collect-only succeeds
- [ ] Red flags absent

---

## Related Documents

- Phase spec: `docs/phases/phase-07-load.md`
- README: `scripts/tests/load/README.md`
- Workstreams: `docs/workstreams/completed/00-013-*.md`
