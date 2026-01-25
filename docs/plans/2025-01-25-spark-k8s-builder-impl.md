# Spark K8s Builder: Implementation Plan

**Дата:** 2025-01-25
**Версия:** 0.1.0
**Статус:** Draft

---

## Overview

Данный план описывает шаги для превращения текущих Helm чартов и тестовых сценариев в полноценный "конструктор" для DataOps инженеров.

**Цель:** Облегчить работу инженеров данных, дата-саентистов и датаопсов с Spark в Kubernetes путём создания:
1. Preset values файлов
2. Recipes библиотеки
3. Валидационных скриптов

---

## Что сделано

✅ **E2E Test Matrix завершена**
- Все 6 сценариев протестированы для Spark 3.5 и 4.1
- Результаты: `docs/testing/F06-e2e-matrix-report.md`

✅ **Документация создана**
- Usage Guide: `docs/guides/ru/spark-k8s-constructor.md`
- Architecture Doc: `docs/architecture/spark-k8s-charts.md`

---

## Priority 0: Preset Values Files

### Задача
Превратить test-скрипты с `--set` флагами в values-файлы

### Spark 4.1 Presets

| Preset файл | Источник | Статус | Компоненты | Key Config |
|-------------|----------|--------|------------|------------|
| `values-scenario-jupyter-connect-k8s.yaml` | `test-e2e-jupyter-connect.sh` | ✅ Tested | Connect + Jupyter + MinIO | `backendMode=k8s` |
| `values-scenario-jupyter-connect-standalone.yaml` | `test-e2e-jupyter-connect.sh` | ✅ Tested | Connect + Jupyter + Standalone | `driver.host=spark-connect FQDN` |
| `values-scenario-airflow-connect-k8s.yaml` | `test-e2e-airflow-connect.sh` | ✅ Tested | Airflow + Connect + MinIO | `deleteWorkerPods=false` |
| `values-scenario-airflow-connect-standalone.yaml` | `test-e2e-airflow-connect.sh` | ✅ Tested | Airflow + Connect + Standalone | `driver.host=...`, `deleteWorkerPods=false` |
| `values-scenario-airflow-k8s-submit.yaml` | `test-e2e-airflow-k8s-submit.sh` | ✅ Tested | Airflow + MinIO | — |
| `values-scenario-airflow-operator.yaml` | `test-e2e-airflow-operator.sh` | ✅ Tested | Airflow + Spark Operator + MinIO | `crds.create=false`, increased timeouts |

### Spark 3.5 Presets

| Preset файл | Источник | Статус | Компоненты |
|-------------|----------|--------|------------|
| `spark-connect/values-scenario-jupyter-connect-k8s.yaml` | `test-e2e-jupyter-connect.sh` | ✅ Tested | Connect + Jupyter + MinIO |
| `spark-connect/values-scenario-jupyter-connect-standalone.yaml` | `test-e2e-jupyter-connect.sh` | ✅ Tested | Connect + Jupyter + Standalone + MinIO |
| `spark-standalone/values-scenario-airflow-connect.yaml` | `test-e2e-airflow-connect.sh` | ✅ Tested | Airflow + Connect + Standalone + MinIO |
| `spark-standalone/values-scenario-airflow-k8s-submit.yaml` | `test-e2e-airflow-k8s-submit.sh` | ✅ Tested | Airflow + MinIO |
| `spark-standalone/values-scenario-airflow-operator.yaml` | `test-e2e-airflow-operator.sh` | ✅ Tested | Airflow + Spark Operator + MinIO |

### Key Config изменения

```yaml
# Spark Connect (3.5) Standalone
sparkConnect:
  sparkConf:
    spark.driver.host: "{{ .Release.Name }}-spark-connect.{{ .Release.Namespace }}.svc.cluster.local"
  env:
    SPARK_DRIVER_HOST: "{{ .Release.Name }}-spark-connect.{{ .Release.Namespace }}.svc.cluster.local"

# Airflow Connect
airflow:
  kubernetesExecutor:
    deleteWorkerPods: false  # для логов

# Spark Operator
sparkOperator:
  crds:
    create: false  # avoid conflicts

# Operator DAG (4.1)
airflow:
  dags:
    sparkOperator:
      timeouts: ... # увеличенные
```

### Метод создания

1. Извлечь `--set` флаги из test-скриптов
2. Конвертировать в YAML формат
3. Сохранить как `values-scenario-{name}.yaml`
4. Протестировать: `helm template test . -f values-scenario-{name}.yaml --dry-run`

---

## Priority 1: Recipes Library

### Категория B: Operations

| Issue → Recipe | Статус | Сложность |
|----------------|--------|-----------|
| ISSUE-013: MinIO events prefix | → `operations/configure-event-log-prefix.md` | Easy |
| ISSUE-022: Event log prefix missing (4.1) | → `operations/enable-event-log-41.md` | Easy |
| ISSUE-029: Hive Metastore init | → `operations/initialize-metastore.md` | Medium |

### Категория D: Troubleshooting

| Issue → Recipe | Статус | Сложность |
|----------------|--------|-----------|
| ISSUE-004: Config readonly (4.1 Connect) | → `troubleshoot/readonly-config.md` | Medium |
| ISSUE-005: Metastore config readonly (4.1) | → `troubleshoot/metastore-readonly.md` | Medium |
| ISSUE-006: History log prefix missing (4.1) | → `troubleshoot/history-server-empty.md` | Easy |
| ISSUE-007: Missing S3 credentials secret | → `troubleshoot/s3-connection-failed.md` | Easy |
| ISSUE-008: Jupyter runtime dir permissions | → `troubleshoot/jupyter-permissions.md` | Medium |
| ISSUE-009: Metastore PSS user | → `troubleshoot/metastore-pss-user.md` | Medium |
| ISSUE-016: Connect daemon exit | → `troubleshoot/connect-crashloop.md` | Medium |
| ISSUE-018: Properties file unsupported (4.1) | → `troubleshoot/properties-file-format.md` | Medium |
| ISSUE-019: Properties format | → `troubleshoot/properties-syntax.md` | Easy |
| ISSUE-020: Connect launcher (4.1) | → `troubleshoot/connect-launch-failed.md` | Medium |
| ISSUE-021: RBAC ConfigMap create (4.1) | → `troubleshoot/rbac-permissions.md` | Medium |
| ISSUE-023: Zstandard missing (4.1) | → `troubleshoot/compression-library-missing.md` | Easy |
| ISSUE-024: Connect driver host (4.1) | → `troubleshoot/driver-not-starting.md` | Medium |
| ISSUE-025: Driver host FQDN | → `troubleshoot/driver-host-resolution.md` | Medium |

### Категория A: Deployment

| Новые рецепты | Источник | Сложность |
|---------------|----------|-----------|
| `deployment/deploy-spark-connect-new-team.md` | E2E matrix | Easy |
| `deployment/migrate-standalone-to-k8s.md` | E2E matrix | Medium |
| `deployment/add-history-server-ha.md` | History Server guide | Medium |
| `deployment/setup-resource-quotas.md` | Deployment recipes | Easy |

### Категория C: Integration

| Новые рецепты | Источник | Сложность |
|---------------|----------|-----------|
| `integration/airflow-spark-connect.md` | E2E matrix | Easy |
| `integration/mlflow-spark-connect.md` | Integration recipes | Medium |
| `integration/external-hive-metastore.md` | Integration recipes | Medium |
| `integration/kerberos-authentication.md` | Integration recipes | Hard |
| `integration/prometheus-monitoring.md` | Integration recipes | Medium |

### Формат рецепта (шаблон)

```markdown
# [Название]

## Symptoms
*Что наблюдается*

## Diagnosis
```bash
# Команды для диагностики
```

## Solution
```bash
# Команды для исправления
```

## References
- Ссылки на официальную документацию
- Связанные issues
```

---

## Priority 1: Jupyter Notebooks & Bash Scripts

### Jupyter Notebooks (`notebooks/recipes/troubleshoot/`)

| Notebook | Recipe | Назначение |
|----------|--------|------------|
| `executor-oom.ipynb` | Troubleshoot OOM | Интерактивная диагностика памяти |
| `driver-not-starting.ipynb` | Driver connection issues | Проверка сети и FQDN |
| `s3-connection-failed.ipynb` | S3 connectivity | Тестирование S3 endpoint |
| `job-hangs.ipynb` | Job stuck | Анализ heartbeats и timeouts |

### Bash Scripts (`scripts/recipes/troubleshoot/`)

| Script | Recipe | Назначение |
|--------|--------|------------|
| `check-executor-logs.sh` | Executor OOM/Crash | Извлечение логов |
| `check-driver-logs.sh` | Driver issues | Проверка driver состояния |
| `test-s3-connection.sh` | S3 connectivity | Тест S3 endpoint |
| `analyze-spark-ui.sh` | Job stuck | Парсинг Spark UI метрик |
| `check-rbac.sh` | RBAC permissions | Проверка прав доступа |

### Example: `check-executor-logs.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"
SELECTOR="${2:-spark-role=executor}"

echo "=== Checking executor pods in ${NAMESPACE} ==="
kubectl get pods -n "${NAMESPACE}" -l "${SELECTOR}"

echo -e "\n=== Checking for OOMKilled ==="
kubectl get pods -n "${NAMESPACE}" -l "${SELECTOR}" -o json | \
  jq -r '.items[] | select(.status.containerStatuses[0].state.terminated.reason == "OOMKilled") | .metadata.name'

echo -e "\n=== Recent executor logs ==="
POD=$(kubectl get pod -n "${NAMESPACE}" -l "${SELECTOR}" -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n "${NAMESPACE}" "${POD}" --tail=50 | grep -i "error\|exception\|oom" || echo "No errors found"
```

---

## Priority 0: Validation Scripts

### `scripts/validate-presets.sh`

```bash
#!/usr/bin/env bash
# Проверка что все preset values рендерятся без ошибок

set -euo pipefail

echo "=== Validating preset values files ==="

for chart in charts/spark-3.5/charts/spark-connect charts/spark-3.5/charts/spark-standalone charts/spark-4.1; do
  echo "Chart: ${chart}"

  for values_file in "${chart}"/values-scenario-*.yaml; do
    if [[ -f "${values_file}" ]]; then
      echo "  Validating: ${values_file}"
      helm template test "${chart}" -f "${values_file}" --dry-run >/dev/null 2>&1 || {
        echo "  ❌ FAILED: ${values_file}"
        exit 1
      }
      echo "  ✅ PASSED"
    fi
  done
done
```

### `scripts/smoke-test-preset.sh`

```bash
#!/usr/bin/env bash
# Деплой preset в test namespace, запуск spark-submit --help

PRESET_FILE="${1}"
NAMESPACE="${2:-spark-test}"
RELEASE="${3:-spark-test}"

# 1. Деплой
helm upgrade --install "${RELEASE}" . -f "${PRESET_FILE}" -n "${NAMESPACE}" --create-namespace

# 2. Ждём готовности
kubectl wait --for=condition=ready pod -n "${NAMESPACE}" -l app=spark-connect --timeout=300s

# 3. Тест
kubectl exec -n "${NAMESPACE}" deploy/spark-connect -- /opt/spark/bin/spark-submit --help

# 4. Cleanup
helm uninstall "${RELEASE}" -n "${NAMESPACE}"
```

### CI Integration

**`.github/workflows/validate-presets.yml`:**
```yaml
name: Validate Preset Values

on:
  pull_request:
    paths:
      - 'charts/**/values-scenario-*.yaml'
      - 'charts/**/templates/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Helm
        uses: azure/setup-helm@v3
      - name: Validate all preset values
        run: ./scripts/validate-presets.sh
```

---

## Priority 2: Policy Validation (опционально)

### `policies/spark-values.rego`

```rego
package spark

# Запрет privileged pods
deny[msg] {
  input.connect.security.privileged == true
  msg := "Privileged pods are not allowed"
}

# Требуем resource limits
deny[msg] {
  not input.connect.resources.limits.memory
  msg := "Memory limits are required"
}

# Требуем S3 credentials
deny[msg] {
  not input.global.s3.existingSecret
  not input.global.s3.accessKey
  msg := "S3 credentials must be configured"
}
```

### Validation command

```bash
conftest verify charts/spark-*/values-*.yaml -p policies/spark-values.rego
```

---

## Очередность выполнения

| Phase | Task | Priority | Effort |
|-------|------|----------|--------|
| 1 | Preset values files (Spark 4.1) | P0 | Medium |
| 1 | Preset values files (Spark 3.5) | P0 | Medium |
| 1 | validate-presets.sh | P0 | Low |
| 2 | Recipes: Operations (B) | P1 | Medium |
| 2 | Recipes: Troubleshooting (D) | P1 | High |
| 2 | Jupyter notebooks | P1 | Low |
| 2 | Bash scripts | P1 | Low |
| 2 | Recipes: Deployment (A) | P1 | Medium |
| 2 | Recipes: Integration (C) | P1 | High |
| 3 | smoke-test-preset.sh | P0 | Low |
| 3 | CI integration | P0 | Low |
| 4 | Policy validation | P2 | Low |
| Future | spark-scaffold CLI (Go) | P3 | High |

---

## Summary

**Что нужно реализовать:**

| Task | Priority | Effort | Owner |
|------|----------|--------|-------|
| Создать preset values files | P0 | Medium | Другой агент (тесты) |
| Мигрировать issues → recipes | P1 | Medium | Документация |
| Создать Jupyter notebooks | P1 | Low | Документация |
| Создать bash скрипты | P1 | Low | Automation |
| Валидационные скрипты | P0 | Low | CI/CD |
| Policy-as-code (опционально) | P2 | Low | Security |
| Quick Reference Card | P1 | Low | Docs |

---

## Полезные ссылки

- **Usage Guide:** `docs/guides/ru/spark-k8s-constructor.md`
- **Architecture:** `docs/architecture/spark-k8s-charts.md`
- **E2E Report:** `docs/testing/F06-e2e-matrix-report.md`
- **Issues:** `docs/issues/`
