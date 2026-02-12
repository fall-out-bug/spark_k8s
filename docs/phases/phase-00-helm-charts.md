# Phase 0: Helm Charts Update

> **Status:** Completed
> **Priority:** P0 - Foundation for all tests
> **Estimated Workstreams:** 8-12
> **Estimated LOC:** ~4000

## Goal

Обновить Helm чарты (spark-3.5, spark-4.1) для поддержки всех комбинаций: GPU, Iceberg, Connect, с помощью templates и presets.

## Scope

**Templates + Presets approach:**
- Templates поддерживают GPU, Iceberg, Connect через conditional logic
- Values управляются через presets (baseline, gpu, iceberg, gpu-iceberg)
- Документация на каждый чарт

## Critical Design Questions

1. **Template Structure:**
   - Как организовать conditional logic для GPU/Iceberg/Connect?
   - Использовать отдельные под-чарты или один чарт с фичами?

2. **Preset Organization:**
   - Как структурировать presets/ директорию?
   - Базовые preset + override или независимые preset?

3. **Documentation:**
   - Какой формат документации для каждого чарта?
   - README.md + values.yaml schema + examples?

4. **Version Compatibility:**
   - Как обрабатывать различия между Spark 3.5 и 4.1?
   - Общие values vs version-specific?

## Proposed Workstreams

| WS | Task | Scope |
|----|------|-------|
| WS-000-01 | Design chart template structure | SMALL (~200 LOC docs) |
| WS-000-02 | Implement GPU templates | MEDIUM (~600 LOC) |
| WS-000-03 | Implement Iceberg templates | MEDIUM (~600 LOC) |
| WS-000-04 | Implement Connect templates (3.5) | MEDIUM (~600 LOC) |
| WS-000-05 | Create baseline presets | MEDIUM (~400 LOC) |
| WS-000-06 | Create GPU presets | MEDIUM (~400 LOC) |
| WS-000-07 | Create Iceberg presets | MEDIUM (~400 LOC) |
| WS-000-08 | Create combo presets (GPU+Iceberg) | MEDIUM (~400 LOC) |
| WS-000-09 | Document spark-3.5 chart | MEDIUM (~600 LOC) |
| WS-000-10 | Document spark-4.1 chart | MEDIUM (~600 LOC) |

## Dependencies

- None (foundation for all other phases)

## Success Criteria

1. ✅ Templates поддерживают GPU, Iceberg, Connect
2. ✅ Presets покрывают все комбинации
3. ✅ Документация создана для обоих чартов
4. ✅ Тесты могут использовать чарты с пресетами
