# Phases Index

Указатель всех фаз для реализации полной тестовой матрицы Spark K8s.

**Last updated:** 2026-02-01

---

## Обзор

| Phase | Название | WS | LOC | Priority | Status |
|-------|----------|----|-----|----------|--------|
| Phase 0 | Helm Charts Update | 8-12 | ~4000 | P0 | Draft |
| Phase 1 | Critical Security + Chart Updates | 4 | ~1250 | P0 | Draft |
| Phase 2 | Complete Smoke Tests | 5 | ~3900 | P0 | Draft |
| Phase 3 | Docker Base Layers | 3 | ~1050 | P1 | Draft |
| Phase 4 | Docker Intermediate Layers | 4 | ~2500 | P1 | Draft |
| Phase 5 | Docker Final Images | 3 | ~3900 | P1 | Draft |
| Phase 6 | E2E Tests | 6 | ~4900 | P1 | Draft |
| Phase 7 | Load Tests | 5 | ~3000 | P2 | Draft |
| Phase 8 | Advanced Security | 7 | ~4400 | P1 | Draft |
| Phase 9 | Parallel Execution & CI/CD | 3 | ~2100 | P2 | Draft |
| **ИТОГО** | **10 фаз** | **48-52 WS** | **~32000 LOC** | | **Draft** |

---

## Описание фаз

### Phase 0: Helm Charts Update

**Файл:** [phase-00-helm-charts.md](phase-00-helm-charts.md)

**Цель:** Обновить Helm чарты для поддержки GPU, Iceberg, Connect через templates и presets.

**Workstreams:** 8-12
- Chart template structure design
- GPU templates implementation
- Iceberg templates implementation
- Connect templates (3.5)
- Presets: baseline, GPU, Iceberg, GPU+Iceberg
- Documentation for spark-3.5 and spark-4.1

**Ключевые вопросы:**
- Template structure for conditional logic
- Preset organization
- Documentation format
- Version compatibility

**Success Criteria:**
- ✅ Templates поддерживают GPU, Iceberg, Connect
- ✅ Presets покрывают все комбинации
- ✅ Документация создана

### Phase 1: Critical Security + Chart Updates

**Файл:** [phase-01-security.md](phase-01-security.md)

**Цель:** OpenShift security compatibility: PSS labels, podSecurityStandards, OpenShift presets.

**Workstreams:** 4
- namespace.yaml templates
- Enable podSecurityStandards by default
- OpenShift presets
- PSS/SCC smoke tests (8 scenarios)

**Success Criteria:**
- ✅ namespace.yaml с PSS labels
- ✅ podSecurityStandards: true
- ✅ OpenShift presets созданы
- ✅ 8 security smoke тестов

### Phase 2: Complete Smoke Tests

**Файл:** [phase-02-smoke.md](phase-02-smoke.md)

**Цель:** 139 smoke сценариев для всех комбинаций.

**Workstreams:** 5
- Baseline (25)
- Connect for 3.5 (18)
- GPU (36)
- Iceberg (36)
- GPU+Iceberg (24)

**Success Criteria:**
- ✅ 139 smoke сценариев
- ✅ Последовательное выполнение
- ✅ Параллельное выполнение
- ✅ YAML frontmatter

### Phase 3: Docker Base Layers

**Файл:** [phase-03-docker-base.md](phase-03-docker-base.md)

**Цель:** Базовые Docker слои (JDK 17, Python 3.10, CUDA 12.1).

**Workstreams:** 3
- JDK 17 base layer + test
- Python 3.10 base layer + test
- CUDA 12.1 base layer + test

**Success Criteria:**
- ✅ 3 base Dockerfiles
- ✅ 3 unit теста
- ✅ Размер оптимизирован

### Phase 4: Docker Intermediate Layers

**Файл:** [phase-04-docker-intermediate.md](phase-04-docker-intermediate.md)

**Цель:** Промежуточные слои (Spark core, Python deps, JDBC, JARs).

**Workstreams:** 4
- Spark core layers (4) + tests
- Python dependencies layer + test
- JDBC drivers layer + test
- JARs layers (RAPIDS, Iceberg) + tests

**Success Criteria:**
- ✅ 7 intermediate Dockerfiles
- ✅ 4 unit теста
- ✅ Слои переиспользуются

### Phase 5: Docker Final Images

**Файл:** [phase-05-docker-final.md](phase-05-docker-final.md)

**Цель:** Финальные образы (Spark, Jupyter со всеми вариантами).

**Workstreams:** 3
- Spark 3.5 images (8) + tests
- Spark 4.1 images (8) + tests
- Jupyter images (12) + tests

**Success Criteria:**
- ✅ 18 final Dockerfiles
- ✅ 28 integration тестов
- ✅ Размер уменьшен на 60-80%
- ✅ GPU/Iceberg работают

### Phase 6: E2E Tests

**Файл:** [phase-06-e2e.md](phase-06-e2e.md)

**Цель:** 80 E2E сценариев с полным датасетом (11GB).

**Workstreams:** 6
- Core E2E (24)
- GPU E2E (16)
- Iceberg E2E (16)
- GPU+Iceberg E2E (8)
- Standalone E2E (8)
- Library compatibility (8)

**Success Criteria:**
- ✅ 80 E2E сценариев
- ✅ NYC Taxi 11GB используется
- ✅ Все проходят
- ✅ Метрики собираются

### Phase 7: Load Tests

**Файл:** [phase-07-load.md](phase-07-load.md)

**Цель:** 20 load сценариев для производительности (30 min sustained).

**Workstreams:** 5
- Baseline load (4)
- GPU load (4)
- Iceberg load (4)
- Comparison load (4)
- Security stability (4)

**Success Criteria:**
- ✅ 20 load сценариев
- ✅ 30 min sustained
- ✅ Метрики собираются
- ✅ Стабильность подтверждена

### Phase 8: Advanced Security

**Файл:** [phase-08-security.md](phase-08-security.md)

**Цель:** 54 security сценариев (PSS, SCC, Network Policies, RBAC, Secrets, Container, S3).

**Workstreams:** 7
- PSS tests (8)
- SCC tests (12)
- Network policies (6)
- RBAC (6)
- Secret management (8)
- Container security (8)
- S3 security (6)

**Success Criteria:**
- ✅ 54 security сценариев
- ✅ PSS restricted confirmed
- ✅ SCC compatible
- ✅ Network policies work
- ✅ RBAC correct

### Phase 9: Parallel Execution & CI/CD

**Файл:** [phase-09-parallel.md](phase-09-parallel.md)

**Цель:** Параллельный запуск тестов, агрегация, CI/CD.

**Workstreams:** 3
- Parallel execution framework
- Result aggregation
- CI/CD integration

**Success Criteria:**
- ✅ Параллельный запуск
- ✅ Результаты агрегируются
- ✅ GitHub Actions workflow

---

## Порядок проектирования

### Вариант 1: Последовательный (рекомендуется)

Проектировать фазы по порядку, утверждать каждую перед переходом к следующей:

1. **Phase 0** (Helm Charts) → утверждение → создание WS
2. **Phase 1** (Security) → утверждение → создание WS
3. **Phase 2** (Smoke) → утверждение → создание WS
4. ... и так далее

### Вариант 2: Критический путь

Сначала спроектировать критические фазы, потом остальные:

1. **Phase 0** (Helm Charts) → утверждение
2. **Phase 1** (Security) → утверждение
3. **Phase 2** (Smoke) → утверждение
4. **Phase 5** (Docker Final) → утверждение
5. Остальные фазы

---

## Зависимости между фазами

```
Phase 0 (Helm Charts) → ALL phases
    ↓
Phase 1 (Security) → Phase 2, Phase 6, Phase 8
    ↓
Phase 2 (Smoke) → Phase 6, Phase 7, Phase 9
    ↓
Phase 3 (Base) → Phase 4 → Phase 5 → Phase 2 (GPU/Iceberg)
    ↓
Phase 5 (Final Images) → Phase 6 → Phase 7
    ↓
Phase 8 (Advanced Security) → parallel with Phase 7
    ↓
Phase 9 (Parallel) → Phase 2, 6, 7
```

**Параллельные потоки:**
- Phase 3 может быть параллелен с Phase 0-1
- Phase 6 следует за Phase 5
- Phase 8 может быть параллелен с Phase 7

---

## Next Steps

1. **Выбрать фазу** для проектирования
2. **Запустить Plan агент** для детального проектирования выбранной фазы
3. **Утвердить design** → создать workstreams
4. **Повторить** для следующих фаз

**Команда для проектирования Phase 0:**
```
/design phase-00-helm-charts
```
