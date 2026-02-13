# @oneshot F027 Execution Report

**Feature:** F27 — Code Quality A*  
**Date:** 2026-02-13  
**Status:** Partial

## Summary

| WS | Name | Status |
|----|------|--------|
| WS-027-01 | Create pyproject.toml and Enforce Coverage | completed |
| WS-027-02 | Split Oversized Test Files | partial |
| WS-027-03 | Split Scripts + Add Pre-commit | partial |

## Deliverables

### WS-027-01: pyproject.toml (Complete)
- `pyproject.toml` — pytest, ruff, black, mypy config; coverage ≥80%
- `requirements-dev.txt` — pytest, pytest-cov, ruff, black, mypy, pre-commit
- `requirements-test.txt` — CI test deps
- `pytest.ini` removed (migrated)
- `.ruffignore` — documented exclusions for tests/, scripts/, examples/

### WS-027-02: Test Split (Partial)
- `test_runbooks.py` (443 LOC) split into 3 modules:
  - `test_runbooks_core.py` (107 LOC)
  - `test_runbooks_validation.py` (152 LOC)
  - `test_runbooks_integration.py` (148 LOC)
- **Remaining:** 12 test files >200 LOC (test_real_k8s_deployment, test_gpu, test_iceberg, etc.)

### WS-027-03: Pre-commit (Partial)
- `.pre-commit-config.yaml` — ruff, black, mypy, trailing-whitespace, end-of-file-fixer
- **Deferred:** Split iceberg_examples.py, rightsizing_calculator.py, gpu_operations_notebook.py

## Next Steps

1. **WS-027-02:** Split remaining 12 test files (see `wc -l tests/**/*.py`)
2. **WS-027-03:** Split 3 Python scripts to ≤200 LOC
3. Run `pre-commit install` and `pre-commit run --all-files`
