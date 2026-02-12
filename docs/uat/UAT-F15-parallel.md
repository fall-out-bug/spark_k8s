# UAT Guide: F15 — Phase 9 Parallel Execution & CI/CD

**Feature:** F15  
**Date:** 2026-02-10  

---

## Overview

F15 provides a parallel test execution framework, result aggregation (JSON, JUnit, HTML), and CI/CD workflows. Tests run in isolated namespaces with configurable concurrency.

---

## Prerequisites

- [ ] `kubectl` + Kubernetes cluster (or kind/minikube)
- [ ] `helm` installed
- [ ] `parallel` (GNU) or `xargs`
- [ ] Python 3 with standard library

---

## Quick Verification (30 seconds)

### Local run_parallel.sh

```bash
# Dry run (requires scenarios dir)
MAX_PARALLEL=2 ./scripts/parallel/run_parallel.sh --help
```

### Aggregate scripts

```bash
mkdir -p test-results
echo '{"status":"passed","duration":1}' > test-results/dummy.json
python3 scripts/aggregate/aggregate_json.py test-results
python3 scripts/aggregate/aggregate_junit.py test-results
python3 scripts/aggregate/generate_html.py test-results
ls test-results/
# Expected: aggregated.json, junit.xml, report.html
```

---

## Detailed Scenarios

### Scenario 1: Parallel execution

```bash
export MAX_PARALLEL=2
./scripts/parallel/run_parallel.sh
# Requires cluster + scenarios. Check test-results/*.json
```

### Scenario 2: Cleanup

```bash
./scripts/parallel/cleanup.sh --results-dir test-results
```

### Scenario 3: GitHub Actions

Trigger `smoke-tests-parallel` via workflow_dispatch or PR.

---

## Red Flags

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | generate_html.py > 200 LOC | 🟡 MEDIUM |
| 2 | aggregate-results creates fake summary (passed: 0) | 🔴 HIGH |
| 3 | run_parallel.sh not used in smoke workflow | 🔴 HIGH |

---

## Code Sanity

```bash
wc -l scripts/parallel/*.sh scripts/aggregate/*.py | awk '$1 > 200 {print "OVER 200:", $0}'
```

---

## Sign-off

- [ ] run_parallel.sh runs (with cluster)
- [ ] Aggregate pipeline produces aggregated.json, junit.xml, report.html
- [ ] All files < 200 LOC
- [ ] Smoke workflow uses run_parallel or proper aggregate integration

---

**Human tester:** Complete UAT before F15 deployment.
