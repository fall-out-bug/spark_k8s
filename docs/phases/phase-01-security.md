# Phase 1: Critical Security + Chart Updates

> **Status:** Draft
> **Priority:** P0 - OpenShift compatibility
> **Estimated Workstreams:** 4
> **Estimated LOC:** ~1250

## Goal

OpenShift security compatibility: namespace.yaml с PSS labels, podSecurityStandards по умолчанию, OpenShift presets, security smoke tests.

## Critical Design Questions

1. **Namespace Labels:**
   - Какие PSS labels использовать (restricted/baseline/privileged)?
   - Нужно ли поддерживать все 3 профиля или только restricted?

2. **UID Ranges:**
   - Какие UID ranges использовать для OpenShift?
   - Как обрабатывать different SCC (restricted, anyuid, nonroot)?

3. **Security Defaults:**
   - Include readOnlyRootFilesystem по умолчанию?
   - Какие capabilities drop по умолчанию?

4. **Testing:**
   - Как проверять PSS compliance в smoke тестах?
   - Нужно ли kubectl validation или достаточно helm template?

## Proposed Workstreams

| WS | Task | Scope |
|----|------|-------|
| WS-001-01 | Create namespace.yaml templates | SMALL (~150 LOC) |
| WS-001-02 | Enable podSecurityStandards by default | SMALL (~100 LOC) |
| WS-001-03 | Create OpenShift presets | MEDIUM (~400 LOC) |
| WS-001-04 | Create PSS/SCC smoke tests (8 scenarios) | MEDIUM (~600 LOC) |

## Dependencies

- Phase 0 (Helm charts update)

## Success Criteria

1. ✅ namespace.yaml с PSS labels
2. ✅ podSecurityStandards: true
3. ✅ OpenShift presets для spark-3.5 и spark-4.1
4. ✅ 8 security smoke сценариев
