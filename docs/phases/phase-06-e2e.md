# Phase 6: E2E Tests

> **Status:** Draft
> **Priority:** P1 - Полная проверка
> **Estimated Workstreams:** 6
> **Estimated LOC:** ~4900

## Goal

Создать 80 E2E сценариев с полным датасетом (NYC Taxi 11GB) для всех комбинаций версий, компонентов, режимов и фич.

## Critical Design Questions

1. **Dataset Management:**
   - Где хранить NYC Taxi full dataset (11GB)? (S3, local, generate)
   - Как загружать датасет в тестах?

2. **Query Set:**
   - Какие SQL запросы выполнять? (4 queries из матрицы)
   - Как валидировать результаты?

3. **Duration Control:**
   - Как ограничить время выполнения E2E тестов?
   - Timeout机制 для каждого query?

4. **Metrics Collection:**
   - Какие метрики собирать? (execution time, throughput, resources)
   - Как сохранять результаты? (JSON, logs)

## Proposed Workstreams

| WS | Task | Scope | Dependencies |
|----|------|-------|-------------|
| WS-006-01 | Core E2E (24) | LARGE (~1500 LOC) | Phase 0, Phase 1, Phase 5 |
| WS-006-02 | GPU E2E (16) | MEDIUM (~900 LOC) | Phase 0, Phase 5 (GPU images) |
| WS-006-03 | Iceberg E2E (16) | MEDIUM (~900 LOC) | Phase 0, Phase 5 (Iceberg images) |
| WS-006-04 | GPU+Iceberg E2E (8) | MEDIUM (~500 LOC) | Phase 0, Phase 5 (GPU+Iceberg images) |
| WS-006-05 | Standalone E2E (8) | MEDIUM (~500 LOC) | Phase 0, Phase 1 |
| WS-006-06 | Library compatibility (8) | MEDIUM (~600 LOC) | Phase 0, Phase 1 |

## Dependencies

- Phase 0 (Helm charts)
- Phase 1 (Security)
- Phase 5 (Final images)

## Success Criteria

1. ✅ 80 E2E сценариев созданы
2. ✅ NYC Taxi full dataset (11GB) используется
3. ✅ Все сценарии проходят
4. ✅ Метрики собираются корректно
