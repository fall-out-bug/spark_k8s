# F08 Full Review — Drift Analysis

**Feature:** F08 - Phase 2 Complete Smoke Tests  
**Review Date:** 2026-02-10  
**Mode:** Full review with drift checks, sub-agent verification

---

## 1. Drift Checks Performed

### 1.1 Scenario Count

| Source | Count | Notes |
|-------|-------|-------|
| beads spark_k8s-ikw | 139 | Closed, notes say 139/139 |
| F08-review.md | 139 | Target and actual |
| find scenarios/*.sh | 144 | **+5 drift** |
| run-smoke-tests.sh line 54 | "14 scenarios" | **Comment outdated** |

### 1.2 run-smoke-tests.sh — CRITICAL BUGS

**Bug 1: PROJECT_ROOT wrong (P0)**  
- **Line 27:** `PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"`  
- **Result:** PROJECT_ROOT = `scripts/` (one level too high)  
- **Effect:** `source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"` → `scripts/scripts/tests/lib` — **path does not exist**  
- **Fix:** `PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"` (3 levels up to repo root)

**Bug 2: @meta block not commented (P0)**  
- **Lines 6-17:** `name:`, `type:`, etc. without `#` prefix  
- **Result:** Bash executes them as commands → `name:: command not found`  
- **Effect:** `run-smoke-tests.sh --list` fails immediately  
- **Fix:** Add `#` before each line in @meta block (or use block comment)

### 1.3 Executability

| Check | Result |
|-------|--------|
| bash -n run-smoke-tests.sh | OK (syntax) |
| bash run-smoke-tests.sh --list | FAIL (bugs above) |
| bash -n scenarios/*.sh | OK (sampled) |

### 1.4 Phase-02 vs Actual Matrix

**Documented (phase-02):**
- Jupyter GPU/Iceberg: 12
- Standalone: 24
- Operator: 32
- History Server: 32
- MLflow: 24

**Actual (scenarios/):**
- jupyter-*: 49
- airflow-*: 42
- mlflow-*: 48
- history-server-*: 12
- Total: 144 (doc said 139)

**Drift:** Matrix structure expanded (load, perf, sec categories added). Count 139 vs 144.

### 1.5 Dataset Utilities

- `scripts/tests/data/generate-dataset.sh` — exists
- phase-02 references `nyc-taxi-sample.parquet` — not in repo (generated)

---

## 2. Findings Summary

| ID | Severity | Description |
|----|----------|-------------|
| F08-D1 | P0 | run-smoke-tests.sh PROJECT_ROOT wrong (../.. → ../../..) |
| F08-D2 | P0 | run-smoke-tests.sh @meta block lines not commented |
| F08-D3 | P2 | run-smoke-tests.sh line 54: "14 scenarios" comment outdated |
| F08-D4 | P2 | Scenario count drift: 139 (doc) vs 144 (actual) |

---

## 3. Beads Created

- spark_k8s-ikw.2 (P0): Fix run-smoke-tests.sh PROJECT_ROOT and @meta
- spark_k8s-ikw.3 (P2): Update run-smoke-tests comment, reconcile 139 vs 144

---

**Report ID:** review-F08-drift-2026-02-10
