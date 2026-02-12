# UAT: F08 Phase 2 — Complete Smoke Tests

**Feature:** F08 - Phase 2 Complete Smoke Tests  
**Review Date:** 2026-02-10

---

## Overview

F08 provides 144 smoke test scenarios covering Jupyter, Airflow, MLflow, Spark Standalone, Operator mode, History Server, GPU, Iceberg, security, performance, and load categories. Includes run-smoke-tests.sh with parallel execution, retry, and resource-aware skip logic.

---

## Prerequisites

- `helm` 3.x
- `kubectl` (cluster access for smoke tests)
- `bash` 4+
- Python 3 with pandas, pyarrow (for generate-dataset.sh)

---

## Quick Verification (2 minutes)

### Smoke Test

```bash
# List scenarios (syntax check)
bash scripts/tests/smoke/run-smoke-tests.sh --help
# Expected: usage output

# Count scenarios
find scripts/tests/smoke/scenarios -name "*.sh" | wc -l
# Expected: 144

# Dataset utility
bash scripts/tests/data/generate-dataset.sh --help 2>/dev/null || bash scripts/tests/data/generate-dataset.sh small
# Expected: generates Parquet or usage
```

### Quick Check

```bash
# Syntax check runner and libs
bash -n scripts/tests/smoke/run-smoke-tests.sh
bash -n scripts/tests/lib/parallel.sh
bash -n scripts/tests/data/generate-dataset.sh
# Expected: no output (pass)
```

---

## Detailed Scenarios

### Scenario 1: Single Scenario (Dry Run)

```bash
# Run one scenario (requires cluster)
bash scripts/tests/smoke/run-smoke-tests.sh --scenario jupyter-connect-k8s-410
# Or: bash scripts/tests/smoke/scenarios/jupyter-connect-k8s-410.sh
```

### Scenario 2: Parallel Execution

```bash
bash scripts/tests/smoke/run-smoke-tests.sh --all --parallel --max-parallel 3
# Requires cluster; GPU/Iceberg scenarios skip if resources unavailable
```

### Scenario 3: Dataset Generation

```bash
bash scripts/tests/data/generate-dataset.sh small
ls -la scripts/tests/data/nyc-taxi-sample.parquet
# Expected: file exists
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | run-smoke-tests.sh fails to source libs | stderr (PROJECT_ROOT) | HIGH |
| 2 | Scenario scripts missing @meta | head of .sh files | MEDIUM |
| 3 | generate-dataset.sh fails | stderr | MEDIUM |
| 4 | TODO/FIXME in smoke scripts | grep | MEDIUM |

---

## Code Sanity Checks

```bash
# Scenario count
find scripts/tests/smoke/scenarios -name "*.sh" | wc -l
# Expected: 144

# All scenarios have @meta
grep -L "# @meta" scripts/tests/smoke/scenarios/*.sh
# Expected: empty (all have frontmatter)

# No TODO/FIXME
grep -rn "TODO\|FIXME" scripts/tests/smoke/ scripts/tests/lib/ scripts/tests/data/
# Expected: empty or acceptable
```

---

## Drift Notes

- **Scenario count:** Phase doc says 139; actual 144 (matrix expanded with load, perf, sec)
- **run-smoke-tests.sh --list:** May output empty if parse_yaml_frontmatter differs; scenarios exist on disk

---

## Sign-off Checklist

- [ ] 144 scenarios exist
- [ ] run-smoke-tests.sh --help works
- [ ] generate-dataset.sh runs
- [ ] parallel.sh syntax valid
- [ ] Red flags absent

---

## Related Documents

- Phase spec: `docs/phases/phase-02-smoke.md`
- Workstreams: `docs/workstreams/backlog/00-008-*.md`
- Drift report: `docs/reports/review-F08-drift-2026-02-10.md`
