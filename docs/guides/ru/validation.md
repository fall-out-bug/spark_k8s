# Runbook по валидации

**Тестировалось на:** Minikube  
**Подготовлено для:** Ограничений OpenShift (PSS `restricted` / SCC `restricted`)

## Обзор

Этот гайд документирует smoke-скрипты, предоставленные в репозитории, и что означает "зелёный" результат для каждого теста.

## Smoke-скрипты

### `scripts/test-spark-standalone.sh`

**Назначение:** End-to-end валидация кластера Spark Standalone (master + workers).

**Использование:**
```bash
./scripts/test-spark-standalone.sh <namespace> <release-name>

# Пример:
./scripts/test-spark-standalone.sh spark-sa spark-standalone
```

**Что проверяет:**
1. Поды готовы (master + workers)
2. Spark Master UI отвечает (HTTP 200 на порту 8080)
3. По крайней мере 1 worker зарегистрирован у master
4. Задание SparkPi завершается успешно (через `spark-submit`)
5. Опциональные сервисы существуют (Airflow, MLflow), если включены

**Ожидаемый вывод:**
```
=== Testing Spark Standalone Chart (spark-standalone in spark-sa) ===
1) Checking pods are ready...
   Master pod: spark-standalone-master-xxx
2) Checking Spark Master UI responds...
   OK
3) Checking at least 1 worker registered (best-effort)...
   OK (workers field present)
4) Running SparkPi via spark-submit (best-effort)...
   OK
5) Checking Airflow and MLflow services exist (if enabled)...
   OK
=== Done ===
```

**Код выхода:** `0` при успехе, не-ноль при ошибке.

### `scripts/test-prodlike-airflow.sh`

**Назначение:** Запуск и ожидание выполнения DAG Airflow в "prod-like" окружении.

**Использование:**
```bash
./scripts/test-prodlike-airflow.sh <namespace> <release-name> [dag1] [dag2] ...

# Пример:
./scripts/test-prodlike-airflow.sh spark-sa-prodlike spark-prodlike \
  example_bash_operator spark_etl_synthetic
```

**Переменные окружения:**
- `TIMEOUT_SECONDS` — Максимальное время ожидания на DAG (по умолчанию: `900`)
- `POLL_SECONDS` — Интервал опроса (по умолчанию: `10`)
- `SET_AIRFLOW_VARIABLES` — Автоматически заполнять Airflow Variables (по умолчанию: `true`)
- `FORCE_SET_VARIABLES` — Перезаписывать существующие переменные (по умолчанию: `false`)
- `SPARK_IMAGE_VALUE` — Образ Spark для DAG (по умолчанию: `spark-custom:3.5.7`)
- `SPARK_NAMESPACE_VALUE` — Namespace для заданий Spark (по умолчанию: аргумент namespace скрипта)
- `SPARK_MASTER_VALUE` — URL Spark Master (по умолчанию: `spark://<release>-spark-standalone-master:7077`)
- `S3_ENDPOINT_VALUE` — URL S3 endpoint (по умолчанию: `http://minio:9000`)
- `S3_ACCESS_KEY_VALUE` — S3 access key (по умолчанию: из секрета `s3-credentials`, если доступен)
- `S3_SECRET_KEY_VALUE` — S3 secret key (по умолчанию: из секрета `s3-credentials`, если доступен)

**Что проверяет:**
1. Deployment Airflow scheduler готов
2. Airflow CLI доступен
3. Airflow Variables автоматически заполняются (если `SET_AIRFLOW_VARIABLES=true`)
4. DAG запускаются и достигают состояния `success`

**Автоматическая настройка переменных:**
Скрипт автоматически устанавливает Airflow Variables, требуемые DAG (`spark_image`, `spark_namespace`, `spark_standalone_master`, `s3_endpoint`, `s3_access_key`, `s3_secret_key`), на основе:
- Аргументов скрипта (namespace, имя release)
- Секрета `s3-credentials` в namespace (если присутствует)
- Переопределений переменных окружения (если установлены)

Это обеспечивает детерминированную работу prod-like DAG тестов без ручной настройки переменных.

**Ожидаемый вывод:**
```
=== Airflow prod-like DAG tests (spark-prodlike in spark-sa-prodlike) ===
1) Waiting for scheduler deployment...
   Scheduler pod: spark-prodlike-spark-standalone-airflow-scheduler-xxx
2) Sanity: airflow CLI reachable...
   OK
3) Triggering DAG: example_bash_operator (run_id=prodlike-20260116-120000-example_bash_operator)
4) Waiting for DAG completion (timeout=900s, poll=10s)...
   example_bash_operator prodlike-20260116-120000-example_bash_operator: success
...
=== Done ===
```

**Код выхода:** `0` если все DAG достигают `success`, `1` если любой DAG падает, `2` при таймауте.

### `scripts/test-sa-prodlike-all.sh`

**Назначение:** Комбинированный smoke-тест (Spark E2E + Airflow DAG).

**Использование:**
```bash
./scripts/test-sa-prodlike-all.sh <namespace> <release-name>

# Пример:
./scripts/test-sa-prodlike-all.sh spark-sa-prodlike spark-prodlike
```

**Что проверяет:**
1. Запускает `test-spark-standalone.sh` (здоровье кластера Spark + SparkPi)
2. Запускает `test-prodlike-airflow.sh` (DAG Airflow: `example_bash_operator`, `spark_etl_synthetic`)

**Ожидаемый вывод:**
```
=== SA prod-like ALL tests (spark-prodlike in spark-sa-prodlike) ===

1) Spark Standalone E2E...
[... вывод из test-spark-standalone.sh ...]

2) Airflow prod-like DAG tests...
[... вывод из test-prodlike-airflow.sh ...]

=== ALL OK ===
```

**Код выхода:** `0` если все тесты проходят, не-ноль если любой тест падает.

## Известные режимы сбоев

### Задание SparkPi падает

**Симптомы:**
- Шаг 4 `test-spark-standalone.sh` падает
- Ошибка: `Connection refused: localhost:7077` или `No route to host`

**Устранение неполадок:**
```bash
# Проверка сервиса master
kubectl get svc -n <namespace> <release>-spark-standalone-master

# Проверка логов master pod
kubectl logs -n <namespace> deploy/<release>-spark-standalone-master | tail -50

# Проверка регистрации workers
kubectl exec -n <namespace> <master-pod> -- \
  curl -fsS http://localhost:8080/json/ | jq '.workers'
```

**Частые исправления:**
- Убедитесь, что `sparkMaster.service.ports.spark: 7077` в values
- Проверьте, что workers могут достичь DNS имени сервиса master
- Проверьте network policies (если включены)

### DAG Airflow завис в "running" или "queued"

**Симптомы:**
- `test-prodlike-airflow.sh` таймаутит
- DAG никогда не достигает `success` или `failed`

**Устранение неполадок:**
```bash
# Проверка логов scheduler
kubectl logs -n <namespace> deploy/<release>-spark-standalone-airflow-scheduler | tail -100

# Проверка worker подов (если KubernetesExecutor)
kubectl get pods -n <namespace> -l app=airflow-worker

# Проверка логов задач DAG через Airflow UI
kubectl port-forward svc/<release>-spark-standalone-airflow-webserver 8080:8080 -n <namespace>
# Откройте http://localhost:8080 и проверьте логи задач
```

**Частые исправления:**
- Проверьте, что `airflow.fernetKey` установлен (общий для всех подов)
- Проверьте, что образ worker KubernetesExecutor совпадает с образом Airflow
- Проверьте права RBAC для worker подов
- Проверьте лимиты ресурсов (worker поды могут быть OOMKilled)

### Перезапуск Airflow Scheduler после сбоя кластера

**Симптомы:**
- Под scheduler в состоянии `Error` после перезапуска кластера
- `test-prodlike-airflow.sh` падает с "timed out waiting for the condition"
- Логи scheduler показывают ошибки подключения к PostgreSQL

**Устранение неполадок:**
```bash
# Проверка статуса пода scheduler
kubectl get pods -n <namespace> -l app=airflow-scheduler

# Проверка логов scheduler
kubectl logs -n <namespace> deploy/<release>-spark-standalone-airflow-scheduler --all-containers | tail -100

# Проверка готовности PostgreSQL
kubectl exec -n <namespace> <postgres-pod> -- pg_isready -U airflow
```

**Частые исправления:**
- Перезапустите deployment scheduler: `kubectl rollout restart deploy/<release>-spark-standalone-airflow-scheduler -n <namespace>`
- Убедитесь, что под PostgreSQL в состоянии `Running` перед запуском scheduler
- Проверьте, что init контейнеры scheduler завершились успешно

### Workers не регистрируются

**Симптомы:**
- Шаг 3 `test-spark-standalone.sh` показывает "WARN: /json/ did not include workers field"
- Master UI показывает 0 workers

**Устранение неполадок:**
```bash
# Проверка worker подов
kubectl get pods -n <namespace> -l app=spark-worker

# Проверка логов worker
kubectl logs -n <namespace> deploy/<release>-spark-standalone-worker | tail -50

# Проверка DNS сервиса master
kubectl exec -n <namespace> <worker-pod> -- nslookup <release>-spark-standalone-master
```

**Частые исправления:**
- Убедитесь, что `sparkMaster.enabled: true`
- Проверьте, что worker может разрешить имя сервиса master
- Проверьте network policies (если включены)

## Быстрый чеклист валидации

Перед тем как считать деплой "зелёным":

- [ ] `helm lint charts/spark-standalone` проходит
- [ ] Все поды в состоянии `Running` (нет `CrashLoopBackOff`, `Pending`)
- [ ] `test-spark-standalone.sh` проходит
- [ ] Если Airflow включён: `test-prodlike-airflow.sh` проходит
- [ ] Нет неожиданных перезапусков (проверьте `kubectl get pods -w`)

## Справочник

- **Гайды по чартам:** [`docs/guides/ru/charts/`](charts/)
- **Заметки по OpenShift:** [`docs/guides/ru/openshift-notes.md`](openshift-notes.md)
- **Карта репозитория:** [`docs/PROJECT_MAP.md`](../../PROJECT_MAP.md)
- **English version:** [`docs/guides/en/validation.md`](../../en/validation.md)
