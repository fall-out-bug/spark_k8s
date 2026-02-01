# Phase 4: Docker Intermediate Layers

> **Status:** Draft
> **Priority:** P1 - Инфраструктура
> **Estimated Workstreams:** 4
> **Estimated LOC:** ~2500

## Goal

Создать промежуточные Docker слои (Spark core, Python deps, JDBC drivers, JARs) с unit тестами.

## Critical Design Questions

1. **Spark Core Layers:**
   - Как упаковывать Spark binary? (download vs copy)
   - Как переиспользовать слои между версиями Spark?

2. **Python Dependencies:**
   - Как организовать requirements.txt? (base, gpu, iceberg)
   - Как минимизировать слой python-deps?

3. **JARs Download:**
   - Как скачивать RAPIDS JARs? (nvidia repo, maven)
   - Как скачивать Iceberg JARs? (apache repo)

4. **Layer Reuse:**
   - Как организовать FROM --from= между слоями?
   - Как кешировать скачивание JARs?

## Proposed Workstreams

| WS | Task | Scope | Dependencies |
|----|------|-------|-------------|
| WS-004-01 | Spark core layers (4) + tests | MEDIUM (~800 LOC) | Phase 3 |
| WS-004-02 | Python dependencies layer + test | MEDIUM (~600 LOC) | Phase 3 |
| WS-004-03 | JDBC drivers layer + test | SMALL (~400 LOC) | Phase 3 |
| WS-004-04 | JARs layers (RAPIDS, Iceberg) + tests | MEDIUM (~700 LOC) | Phase 3 |

## Dependencies

- Phase 3 (Base layers)

## Success Criteria

1. ✅ 7 intermediate Dockerfiles созданы
2. ✅ 4 unit теста проходят
3. ✅ Слои переиспользуются правильно
4. ✅ JARs скачиваются и кешируются
