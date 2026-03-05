# Idea: Flatten Standalone/Airflow Subchart, Unify Naming

## Problem Statement

chart spark-3.5 имеет дублированную архитектуру Standalone:
- **Parent template** (`sparkStandalone`) — master+workers, без Airflow
- **Subchart** (`standalone` alias) — master+workers + Airflow + PostgreSQL + DAGs

Это приводит к:
1. Дублированию кода (master+worker в двух местах)
2. Путанице в нейминге (`sparkStandalone` vs `standalone` vs `spark-standalone`)
3. Helm condition gotcha: subchart грузится по умолчанию когда ключ отсутствует
4. Костылю в run-matrix: `standalone.enabled=false` при `sparkStandalone.enabled=true`
5. 9 инцидентов поломки demo из-за путаницы в именах и конфигурации

## Target State

Единое пространство имён, все templates в parent chart:

```yaml
connect:      { enabled: false }   # Spark Connect server
standalone:   { enabled: false }   # Spark Standalone (master + workers)
kubernetes:   { enabled: false }   # Spark on K8s (spark-submit --master k8s://)
airflow:      { enabled: false }   # Airflow orchestrator (independent)
```

Subchart `spark-standalone` удаляется. `sparkStandalone` и `sparkK8sNative` удаляются.

## Матрица сценариев

| Сценарий | connect | standalone | kubernetes | airflow | jupyter |
|----------|---------|-----------|------------|---------|---------|
| Matrix connect+k8s | true | false | false | false | false |
| Matrix connect+sa | true | true | false | false | false |
| Matrix k8s-native | false | false | true | false | false |
| Matrix standalone | false | true | false | false | false |
| Demo | false | true | false | true | true |

## Impact Analysis (inventory)

| Категория | Файлов |
|-----------|--------|
| `sparkStandalone` references | ~20 |
| `sparkK8sNative` references | ~6 |
| `standalone` subchart refs | ~45 |
| `spark-standalone` subchart name | ~35 |
| Airflow templates (subchart) | 5 |
| DAGs / spark_jobs | 7+8 |
| Scripts | ~20 |
| Tests | ~4 |
| Docs | ~35 |

## Constraints

- Demo (spark-infra) НЕ должна сломаться — helm upgrade, не uninstall
- DAGs (NYC Taxi, CitiBike, MovieLens) сохраняются, не откатываются к SparkPi
- Имена ресурсов: если меняются — document и обновить все scripts/DAGs
- PostgreSQL shared (spark-base) — единый для Metastore и Airflow
- Каждый WS имеет evidence: helm template before/after, helm lint, dry-run

## Quality Gates (PMBoK: Verification & Validation)

Каждый WS проходит:
1. **Provenance**: helm template snapshot before (baseline) и after — diff показывает только ожидаемые изменения
2. **Evidence**: `helm lint charts/spark-3.5` passes, `helm template` renders для всех 5 mode combos
3. **Trace**: каждое изменение имени (old → new) задокументировано в WS и проверяется grep
4. **No isExist**: тесты вызывают `helm template` / `helm lint` / script execution, не `Path.exists()`
5. **Lint**: shellcheck для скриптов, ruff для Python
6. **Dry-run**: `run-matrix.sh --dry-run` для 32 вариантов проходит

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Demo breakage | High | Critical | Baseline snapshot + helm upgrade (not reinstall) + rollback plan |
| Service name change breaks port-forwards | Medium | High | grep all hardcoded names, update atomically |
| DAGs break (hardcoded master URL) | Medium | High | Template or env-var driven, not hardcoded |
| PVC ownership labels change | Low | Critical | Verify helm diff shows no PVC deletions |
| Matrix regression | Medium | Medium | Dry-run all 320 before/after |

## Stakeholders

- Demo users (Jupyter, Airflow UI)
- Matrix test runner (320 scenarios)
- CI pipelines
- Documentation readers
