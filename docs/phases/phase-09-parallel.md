# Phase 9: Parallel Execution & CI/CD

> **Status:** Backlog
> **Priority:** P2 - Ускорение выполнения
> **Feature:** F15
> **Estimated Workstreams:** 3
> **Estimated LOC:** ~2100

## Goal

Создать фреймворк для параллельного запуска тестов, агрегации результатов и CI/CD интеграции. Валидировать production-ready CI/CD pipeline с автоматическим тестированием.

## Current State

**Не реализовано** — Phase 9 только начинается. Design Decisions уже approved.

## Updated Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-015-01 | Parallel execution framework | MEDIUM (~800 LOC) | Phase 0, Phase 2, Phase 6, Phase 7 | backlog |
| WS-015-02 | Result aggregation | MEDIUM (~600 LOC) | WS-015-01 | backlog |
| WS-015-03 | CI/CD integration | MEDIUM (~700 LOC) | WS-015-02 | backlog |

## Design Decisions (Approved)

### 1. Parallel Execution

**Framework choice:**
- `gnu parallel` для мощной parallelизации
- `xargs -P` как fallback
- Background tasks для простых случаев

**Concurrency control:**
- Max parallel jobs: 4 (default)
- Configurable via `MAX_PARALLEL` env var
- Resource limits per test

### 2. Isolation

**Namespace isolation:**
- Unique namespace per test: `spark-test-{scenario}-{timestamp}`
- Automatic cleanup on completion/failure
- Retry mechanism for namespace conflicts

**Release name isolation:**
- Unique release per test: `spark-{scenario}-{random}`
- No conflicts between parallel tests

### 3. Result Aggregation

**Formats:**
- JSON for machine parsing
- JUnit XML for CI/CD integration
- HTML report for human review

**Partial failures:**
- Continue on individual test failures
- Aggregate all results
- Exit code indicates overall status

### 4. CI/CD Integration

**GitHub Actions:**
- Matrix strategy for parallel execution
- Scheduled runs (daily, weekly)
- PR validation workflow

**Triggers:**
- Push to main branch
- Pull request to main
- Schedule (cron)

## Dependencies

- **Phase 0 (F06):** Helm charts deployed
- **Phase 2 (F08):** Smoke tests passing
- **Phase 6 (F12):** E2E tests passing
- **Phase 7 (F13):** Load tests passing

## Success Criteria

1. ⏳ Параллельный запуск работает (4+ concurrent tests)
2. ⏳ Результаты агрегируются корректно (JSON + JUnit + HTML)
3. ⏳ GitHub Actions workflow создан
4. ⏳ Scheduled runs работают
5. ⏳ PR validation работает
6. ⏳ Cleanup после тестов работает
7. ⏳ Resource limits соблюдаются

## File Structure

```
scripts/
├── parallel/
│   ├── run_parallel.sh          # Main parallel execution script
│   ├── run_scenario.sh          # Single scenario runner
│   └── cleanup.sh               # Namespace/release cleanup
├── aggregate/
│   ├── aggregate_json.py        # JSON aggregation
│   ├── aggregate_junit.py       # JUnit XML generation
│   └── generate_html.py         # HTML report generation
└── .github/
    └── workflows/
        ├── smoke-tests.yml      # Smoke test workflow
        ├── e2e-tests.yml        # E2E test workflow
        ├── load-tests.yml       # Load test workflow
        └── scheduled-tests.yml  # Scheduled full run
```

## Integration with Other Phases

- **Phase 0 (F06):** Charts provide deployment base
- **Phase 2 (F08):** Smoke tests validate basic scenarios
- **Phase 6 (F12):** E2E tests provide comprehensive coverage
- **Phase 7 (F13):** Load tests validate performance
- **Phase 8 (F14):** Security tests validate hardening

## Beads Integration

```bash
# Feature
spark_k8s-xxx - F15: Phase 9 - Parallel Execution & CI/CD (P2)

# Workstreams
spark_k8s-xxx - WS-015-01: Parallel execution framework (P2)
spark_k8s-xxx - WS-015-02: Result aggregation (P2)
spark_k8s-xxx - WS-015-03: CI/CD integration (P2)

# Dependencies
WS-015-02 depends on WS-015-01
WS-015-03 depends on WS-015-02
All WS depend on F06, F08, F12, F13
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [phase-02-smoke.md](./phase-02-smoke.md)
- [phase-06-e2e.md](./phase-06-e2e.md)
- [phase-07-load.md](./phase-07-load.md)
