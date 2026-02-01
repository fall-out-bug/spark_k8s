# Phase 2: Complete Smoke Tests

> **Status:** Draft
> **Priority:** P0 - Базовая функциональность
> **Estimated Workstreams:** 5
> **Estimated LOC:** ~3900

## Goal

Создать 139 smoke сценариев для всех комбинаций версий Spark, компонентов, режимов и фич.

## Critical Design Questions

1. **Scenario Organization:**
   - Как организовать 139 файлов? По версиям? По компонентам?
   - Как называть файлы consistently?

2. **Parameterization:**
   - Какая параметризация в run-smoke-tests.sh?
   - Фильтрация по версии, компоненту, режиму, фиче?

3. **Dataset:**
   - Какой использовать датасет (~100MB NYC Taxi sample)?
   - Где хранить/генерировать датасет?

4. **GPU/Iceberg Dependencies:**
   - Baseline smoke тесты могут идти без Phase 5 (Docker images)?
   - Или ждать GPU/Iceberg образов?

## Proposed Workstreams

| WS | Task | Scope | Dependencies |
|----|------|-------|-------------|
| WS-002-01 | Baseline scenarios for all (25) | MEDIUM (~800 LOC) | Phase 0, Phase 1 |
| WS-002-02 | Connect for Spark 3.5 (18) | MEDIUM (~600 LOC) | Phase 0, Phase 1 |
| WS-002-03 | GPU scenarios (36) | MEDIUM (~900 LOC) | Phase 0, Phase 5 |
| WS-002-04 | Iceberg scenarios (36) | MEDIUM (~900 LOC) | Phase 0, Phase 5 |
| WS-002-05 | GPU+Iceberg scenarios (24) | MEDIUM (~700 LOC) | Phase 0, Phase 5 |

## Dependencies

- Phase 0 (Helm charts with GPU/Iceberg/Connect support)
- Phase 1 (Security templates)

## Success Criteria

1. ✅ 139 smoke сценариев созданы
2. ✅ Все проходят последовательно
3. ✅ Все проходят параллельно
4. ✅ YAML frontmatter в каждом сценарии
