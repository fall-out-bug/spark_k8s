# WS-C5M: Split test_security.py into modules ≤200 LOC

> **Status:** In Progress
> **Priority:** P0 - F14 review blocker
> **Feature:** F14 - Phase 8 Advanced Security
> **Type:** task
> **Estimate:** MEDIUM (~600 LOC)

## Goal

Разделить `tests/security/test_security.py` (252 LOC) на модули по 200 LOC каждый, чтобы пройти quality gate.

## Description

F14 review (review-F14-full-2026-02-10.md) определил, что `test_security.py` превышает лимит 200 LOC и блокирует approval. Требуется разделить файл на модули.

## Current State

Файл `tests/security/test_security.py` (252 LOC) содержит все тесты в одном файле.
- `TestNetworkPolicies` (строки 17-46 ~29 LOC)
- `TestRBAC` (строки 50-89 ~39 LOC)
- `TestSecretsHardcoded` (строки 92-166 ~74 LOC)
- `TestSecurityContext` (строки 178-221 ~43 LOC)
- `TestCompliance` (строки 224-252 ~28 LOC)

## Solution

Разделить `test_security.py` на отдельные модули:

1. **`tests/security/network/test_network_policies.py`** — TestNetworkPolicies класс
2. **`tests/security/rbac/test_rbac.py`** — TestRBAC класс
3. **`tests/security/secrets/test_secrets.py`** — TestSecretsHardcoded класс
4. **`tests/security/context/test_security_context.py`** — TestSecurityContext класс
5. **`tests/security/compliance/test_compliance.py`** — TestCompliance класс

Каждый модуль должен быть ≤200 LOC.

## Success Criteria

1. [ ] `tests/security/network/test_network_policies.py` создан (≤200 LOC)
2. [ ] `tests/security/rbac/test_rbac.py` создан (≤200 LOC)
3. [ ] `tests/security/secrets/test_secrets.py` создан (≤200 LOC)
4. [ ] `tests/security/context/test_security_context.py` создан (≤200 LOC)
5. [ ] `tests/security/compliance/test_compliance.py` создан (≤200 LOC)
6. [ ] `tests/security/test_security.py` удалён (заменён импортами новых модулей)
7. [ ] Все тесты проходят (`pytest tests/security/ -v`)
8. [ ] Каждый файл <200 LOC (`wc -l tests/security/*/*.py`)

## Dependencies

- **Independent:** Нет зависимостей

## Execution Order

1. Создать структуру директорий для новых модулей
2. Разделить `TestNetworkPolicies` → `test_network_policies.py`
3. Разделить `TestRBAC` → `test_rbac.py`
4. Разделить `TestSecretsHardcoded` → `test_secrets.py`
5. Разделить `TestSecurityContext` → `test_security_context.py`
6. Разделить `TestCompliance` → `test_compliance.py`
7. Обновить `test_security.py` (импорты из новых модулей)
8. Запустить все тесты и проверить

## File Structure

```
tests/security/
├── network/
│   └── test_network_policies.py
├── rbac/
│   └── test_rbac.py
├── secrets/
│   └── test_secrets.py
├── context/
│   └── test_security_context.py
├── compliance/
│   └── test_compliance.py
└── test_security.py  (updated - aggregator)
```

## References

- [review-F14-full-2026-02-10.md](../../../reports/review-F14-full-2026-02-10.md) - Source review report
- [test_security.py](../../tests/security/test_security.py) - Original file to split
