# Карта техдолга

**Обновлено:** 2026-02-13  
**Источник:** beads (label: tech-debt)

---

## По фичам

### F15 — Parallel Execution & CI/CD

| ID | Задача | Приоритет | Блокер | Статус |
|----|--------|-----------|--------|--------|
| spark_k8s-ksz | Split generate_html.py (200 LOC) | P0 | spark_k8s-dyz | ✅ CLOSED |
| spark_k8s-zjq | Wire smoke-tests-parallel с run_parallel.sh | P1 | spark_k8s-dyz | ✅ CLOSED |
| spark_k8s-78m | Add retry for namespace conflicts in run_scenario.sh | P2 | spark_k8s-dyz | ✅ CLOSED |
| spark_k8s-wcb | Create scheduled-tests.yml (daily full run) | P2 | spark_k8s-dyz | ✅ CLOSED |
| spark_k8s-dyz.8 | Fix scheduled-tests aggregate args (--results-dir) | P2 | spark_k8s-dyz | ✅ CLOSED |

### F16 — Observability

| ID | Задача | Приоритет | Блокер | Статус |
|----|--------|-----------|--------|--------|
| spark_k8s-8h5 | Fix grafana values.yaml YAML syntax | P0 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-dee | Split test_observability.py (200 LOC) | P1 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-emp | Run helm dependency build for prometheus | P1 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-kcj | Fix prometheus/loki templates (spark.name scope) | P1 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-ozu | Run helm dependency build for grafana | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-74z.8 | Fix grafana helm template (datasources jsonData type) | P1 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-74z.9 | Skip Spark 3.5 in tests when paths missing | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-k5r | Split tests >200 LOC | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-ci6 | Create test_metrics.sh | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-mgv | Add runtime tests | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-2qk | Parameterize tests Spark 3.5/4.1 | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-31l | Consolidate dashboards | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-74z.10 | Fix 4 failing observability tests | P2 | spark_k8s-74z | ✅ CLOSED |
| spark_k8s-8e9 | Fix F18 references F16 as completed | P2 | spark_k8s-74z | ✅ CLOSED (via 7xp) |

### F14 — Phase 8 Advanced Security

| ID | Задача | Приоритет | Блокер | Статус |
|----|--------|-----------|--------|--------|
| spark_k8s-rlk | Fix 17 failing security tests | P1 | spark_k8s-cy5 | ✅ CLOSED |
| spark_k8s-bch | Add PYTHONPATH for security tests | P2 | spark_k8s-cy5 | ✅ CLOSED |

### F17 — Spark Connect Go Client

| ID | Задача | Приоритет | Блокер | Статус |
|----|--------|-----------|--------|--------|
| spark_k8s-ecz | Align WS-017-01 code template with gRPC/proto API | P1 | spark_k8s-cqy | ✅ CLOSED |
| spark_k8s-85e | Re-verify Spark Connect Go/Proto source | P1 | spark_k8s-cqy | ✅ CLOSED |
| spark_k8s-bok | Add Go test to CI | P2 | spark_k8s-cqy | ✅ CLOSED |
| spark_k8s-cqy.6 | Split Go files >200 LOC (connect 217, connect_test 280, smoke 316, load 349, e2e 493) | P1 | spark_k8s-cqy | ✅ CLOSED |

### F18 — Production Operations Suite

| ID | Задача | Приоритет | Блокер | Статус |
|----|--------|-----------|--------|--------|
| spark_k8s-yck | Add pytest test_* to test_runbooks.py | P2 | spark_k8s-d5e | ✅ CLOSED |
| spark_k8s-117 | Complete WS-018-01 (on-call, escalation, declare-incident) | P2 | spark_k8s-d5e | ✅ CLOSED |
| spark_k8s-7xp | Update F16 dependency references | P2 | spark_k8s-d5e | ✅ CLOSED |
| spark_k8s-6ki | Split ops scripts > 200 LOC (или exemption) | P3 | spark_k8s-d5e | ✅ CLOSED |
| spark_k8s-d5e.20 | Increase test_runbooks.py coverage to ≥80% (current 70%) | P2 | spark_k8s-d5e | ✅ CLOSED |
| spark_k8s-d5e.21 | Fix ops-scripts-assessment.md (incorrect NOT FOUND) | P3 | spark_k8s-d5e | ✅ CLOSED |

### F25 — Spark 3.5 Charts Production-Ready

| ID | Задача | Приоритет | Блокер | Статус |
|----|--------|-----------|--------|--------|
| spark_k8s-pb8 | WS-025-11: Add prepare-nyc-taxi-data.sh | P2 | spark_k8s-ju2 | ✅ CLOSED |
| spark_k8s-2f9 | WS-025-11: Add F25-load-test-report.md + report-template.md | P2 | spark_k8s-ju2 | ✅ CLOSED |
| spark_k8s-7nn | WS-025-12: Verify/publish resource-wait-tracker JAR | P2 | spark_k8s-ju2 | open |
| spark_k8s-bbk | WS-025-12: Add Job Phase Timeline + Spark Profiling links to observability-stack.md | P3 | spark_k8s-ju2 | ✅ CLOSED |
| spark_k8s-y0m | Document LOC exemption for test-spark-35-minikube.sh (599 LOC) | P3 | spark_k8s-ju2 | ✅ CLOSED |

---

## По типу

### Quality gate (200 LOC)

| ID | Feature | Описание | Статус |
|----|---------|----------|--------|
| spark_k8s-ksz | F15 | generate_html.py | ✅ CLOSED |
| spark_k8s-dee | F16 | test_observability.py | ✅ CLOSED |
| spark_k8s-6ki | F18 | ops scripts (6 шт.) | ✅ CLOSED |
| spark_k8s-y0m | F25 | test-spark-35-minikube.sh | ✅ CLOSED |
| spark_k8s-cqy.6 | F17 | Go: connect.go, connect_test.go, smoke, load, e2e | ✅ CLOSED |

### Docs

| ID | Feature | Описание | Статус |
|----|---------|----------|--------|
| spark_k8s-2f9 | F25 | F25-load-test-report.md, report-template.md |
| spark_k8s-7xp | F18 | F16 dependency refs | ✅ CLOSED |
| spark_k8s-bbk | F25 | observability-stack.md links |
| spark_k8s-d5e.21 | F18 | ops-scripts-assessment.md (fix NOT FOUND) | ✅ CLOSED |

### Tests

| ID | Feature | Описание | Статус |
|----|---------|----------|--------|
| spark_k8s-yck | F18 | test_runbooks.py test_* | ✅ CLOSED |
| spark_k8s-d5e.20 | F18 | test_runbooks.py coverage ≥80% | ✅ CLOSED |

### CI/Infra

| ID | Feature | Описание | Статус |
|----|---------|----------|--------|
| spark_k8s-zjq | F15 | smoke-tests-parallel wiring | ✅ CLOSED |
| spark_k8s-wcb | F15 | scheduled-tests.yml | ✅ CLOSED |
| spark_k8s-emp | F16 | helm dependency build (prometheus) | ✅ CLOSED |

### Charts/Templates

| ID | Feature | Описание |
|----|---------|----------|
| spark_k8s-8h5 | F16 | grafana values.yaml |
| spark_k8s-kcj | F16 | prometheus/loki templates |
| spark_k8s-pb8 | F25 | prepare-nyc-taxi-data.sh |
| spark_k8s-7nn | F25 | resource-wait-tracker JAR |

### Feature completeness

| ID | Feature | Описание |
|----|---------|----------|
| spark_k8s-117 | F18 | WS-018-01 deliverables |
| spark_k8s-ecz | F17 | WS-017-01 code template |
| spark_k8s-85e | F17 | Go/Proto source verification |

---

## По приоритету

| P0 | P1 | P2 | P3 |
|----|----|----|-----|
| spark_k8s-8h5 | spark_k8s-ecz | spark_k8s-yck | spark_k8s-6ki |
| spark_k8s-ksz | spark_k8s-85e | spark_k8s-117 | spark_k8s-bbk |
| | spark_k8s-dee | spark_k8s-7xp | spark_k8s-y0m |
| | spark_k8s-emp | spark_k8s-pb8 | |
| | spark_k8s-kcj | spark_k8s-2f9 | |
| | spark_k8s-zjq | spark_k8s-7nn | |

---

## Граф зависимостей (features → tech-debt)

```
F15 (dyz) ──► ksz, zjq, 78m, wcb, dyz.8
F14 (cy5) ──► rlk, bch
F16 (74z) ──► 8h5, dee, emp, kcj, 74z.8, 74z.9, k5r, 2qk, 31l, 74z.10
F17 (cqy) ──► ecz, 85e, bok, cqy.6
F18 (d5e) ──► yck, 117, 7xp, 6ki, d5e.20, d5e.21
F25 (ju2) ──► pb8, 2f9, 7nn, bbk, y0m
```

---

## Команды

```bash
# Все tech-debt
bd list | grep tech-debt

# По фиче
bd list | grep F25

# Детали
bd show spark_k8s-pb8
```
