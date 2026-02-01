# Phase 3: Docker Base Layers

> **Status:** Draft
> **Priority:** P1 - Инфраструктура
> **Estimated Workstreams:** 3
> **Estimated LOC:** ~1050

## Goal

Создать базовые Docker слои (JDK 17, Python 3.10, CUDA 12.1) с unit тестами.

## Critical Design Questions

1. **Base Images:**
   - Какие официальные образы использовать? (eclipse-temurin, nvidia/cuda, python)
   - Как минимизировать размер базовых образов?

2. **Common Components:**
   - Что общего между базовыми образами? (entrypoint, utilities)
   - Как переиспользовать код между образами?

3. **Testing Strategy:**
   - Как тестировать CUDA layer без GPU?
   - Mock или skip?

4. **Build Optimization:**
   - Как кешировать слои для ускорения сборки?
   - Multi-stage builds?

## Proposed Workstreams

| WS | Task | Scope |
|----|------|-------|
| WS-003-01 | JDK 17 base layer + test | SMALL (~300 LOC) |
| WS-003-02 | Python 3.10 base layer + test | SMALL (~250 LOC) |
| WS-003-03 | CUDA 12.1 base layer + test | MEDIUM (~500 LOC) |

## Dependencies

- None (can run parallel with Phase 0-1)

## Success Criteria

1. ✅ 3 base Dockerfiles созданы
2. ✅ 3 unit теста проходят
3. ✅ Размер образов оптимизирован (<200MB для JDK, <100MB для Python)
