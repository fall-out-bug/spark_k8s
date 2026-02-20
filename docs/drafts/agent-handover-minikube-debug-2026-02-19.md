# Agent Handover: Minikube Debug Session 2026-02-19 (Updated)

## Цель сессии
Запустить и отладить сценарии 0/1/2 в minikube (Spark 3.5.7, Airflow 2.11):
- Сценарий 0: MinIO + Hive Metastore + History Server + Observability
- Сценарий 1: Jupyter + Spark Connect (Standalone backend)
- Сценарий 2: **Airflow + Standalone (прямое подключение, БЕЗ Spark Connect)**
- Smoke/load-тесты с проверкой артефактов в History Server
- Телеметрия джобов + Grafana дашборд

---

## Текущее состояние кластера (2026-02-20 10:45 UTC)

### Namespaces и поды

```
spark-infra:
  minio-69ddd645f9-p96ng                          1/1 Running  (OK)
  spark-infra-spark-35-history-554cbb77bc-*       1/1 Running  (OK - читает s3a://spark-logs/events)
  spark-infra-spark-35-metastore-7558786cc8-*     1/1 Running  (OK - pg_hba.conf md5)
  spark-infra-spark-base-postgresql-0             1/1 Running  (OK)

spark-35-jupyter-sa (сценарий 1):
  scenario1-spark-35-connect-*                    1/1 Running  (OK)
  scenario1-spark-35-jupyter-*                    1/1 Running  (OK)
  scenario1-spark-35-standalone-master-*          1/1 Running  (OK)
  scenario1-spark-35-standalone-worker-*          1/1 Running  (OK)

spark-35-airflow-sa (сценарий 2):
  ✅ НЕТ Spark Connect - удалён
  scenario2-spark-35-standalone-master-*          1/1 Running  (OK)
  scenario2-spark-35-standalone-worker-*          2/2 Running  (OK - 2 workers)

observability:
  otel-collector-ddbddcd9d-*                      1/1 Running  (OK - порт 4317 gRPC)
  grafana-*                                       1/1 Running  (OK - NodePort 30358)
```

---

## Решённые проблемы

### 1. Hive Metastore CrashLoopBackOff ✅ FIXED

**Проблема:** `authentication type 10 is not supported` (SCRAM-SHA-256 vs старый JDBC)

**Решение:**
```bash
# Патч pg_hba.conf напрямую
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  sh -c "sed -i 's/scram-sha-256/md5/g' /var/lib/postgresql/data/pg_hba.conf"

# Перезагрузить конфигурацию postgres (без рестарта)
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  su postgres -c "pg_ctl reload -D /var/lib/postgresql/data"

# Перезапустить Hive
kubectl rollout restart deployment/spark-infra-spark-35-metastore -n spark-infra
```

**Результат:** Hive Metastore теперь Running.

### 2. Grafana ✅ DEPLOYED

**Решение:** Развёрнута через манифест (helm repo недоступен):
```bash
kubectl apply -f - -n observability << 'EOF'
# ... manifest ...
EOF
```

**Доступ:** NodePort 30358, admin/admin

---

## Нерешённые проблемы

### 1. History Server и Spark Connect (сценарий 1)

**Причина:** Connect server - long-running приложение. Rolling event log пишет в `events_1_` но файл не коммитится в S3 пока:
- Не достигнет 128MB (`spark.eventLog.rolling.maxFileSize`)
- Приложение не остановится

**Для сценария 2 (Airflow + Standalone):** ✅ History Server работает, т.к. spark-submit завершается и event log коммитится.

### ~~2. Сценарий 2 (Airflow) — не проверялся~~ ✅ ИСПРАВЛЕНО

**Статус:** Теперь работает напрямую со Standalone (без Spark Connect).

**Изменения:**
1. Создан новый пресет `charts/spark-3.5/presets/scenarios/airflow-standalone.yaml`
2. Spark Connect удалён из сценария 2
3. Airflow будет использовать прямой `spark-submit --master spark://master:7077`
4. Создан скрипт `scripts/test-spark-standalone-load.sh` для тестирования

**Результат теста:**
```
=== Load Test PASSED ===
History Server shows 1 application(s)

Iteration results:
  Iter 1: Agg=4.98s, Filter+Count=1.22s
  Iter 2: Agg=1.91s, Filter+Count=0.88s
  Iter 3: Agg=1.05s, Filter+Count=0.49s
```

---

## Ключевые факты

| Параметр | Значение |
|----------|----------|
| MinIO FQDN | `minio.spark-infra.svc.cluster.local:9000` |
| MinIO credentials | `minioadmin / minioadmin` |
| Event log dir | `s3a://spark-logs/events` |
| History Server | `spark-infra-spark-35-history.spark-infra:18080` |
| **Сценарий 1 (Jupyter)** | Spark Connect → Standalone backend |
| Connect (scenario1) | `scenario1-spark-35-connect.spark-35-jupyter-sa:15002` |
| Standalone Master (s1) | `scenario1-spark-35-standalone-master.spark-35-jupyter-sa:7077` |
| **Сценарий 2 (Airflow)** | Прямое подключение к Standalone (БЕЗ Connect) |
| Standalone Master (s2) | `scenario2-spark-35-standalone-master.spark-35-airflow-sa:7077` |
| OTEL Collector | `otel-collector.observability:4317` |
| Grafana | NodePort 30358 (admin/admin) |
| Hive image | `spark-k8s/hive:3.1.3-pg` (в minikube docker, с JDBC 42.7.10) |
| Spark image | `spark-custom:3.5.7-new` (в minikube docker) |
| OpenTelemetry | **ОТКЛЮЧЁН** (`connect.openTelemetry.enabled=false`) |

## Архитектура сценариев

### Сценарий 1 (Jupyter): Spark Connect + Standalone
```
Jupyter → Spark Connect (gRPC:15002) → Standalone Master:7077 → Workers
```
- Для интерактивной работы в notebooks
- Pandas-like API через Spark Connect

### Сценарий 2 (Airflow): Прямой Standalone
```
Airflow → spark-submit --master spark://master:7077 → Workers
```
- Для batch ETL/пайплайнов
- Прямое подключение, без промежуточного слоя
- Event log коммитится в S3 → виден в History Server

---

## Быстрый старт для нового агента

### Шаг 1: Проверить статус кластера
```bash
kubectl get pods -n spark-infra
kubectl get pods -n spark-35-jupyter-sa
kubectl get pods -n spark-35-airflow-sa
kubectl get pods -n observability
```

### Шаг 2: Запустить load-тест (scenario1 - Jupyter + Connect)
```bash
cd /home/fall_out_bug/work/s7/spark_k8s
LOAD_REQUIRE_HISTORY_SERVER=false \
  ./scripts/test-spark-connect-standalone-load.sh \
  spark-35-jupyter-sa scenario1 scenario1-spark-35-standalone-master:7077
```

### Шаг 3: Запустить load-тест (scenario2 - Airflow + Standalone)
```bash
# НОВЫЙ СКРИПТ для прямого Standalone (без Connect)
LOAD_REQUIRE_HISTORY_SERVER=false \
  ./scripts/test-spark-standalone-load.sh \
  spark-35-airflow-sa scenario2 scenario2-spark-35-standalone-master:7077
```

### Шаг 4: Проверить Grafana
```bash
kubectl port-forward -n observability svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
```

### Шаг 5: Если нужно починить Hive снова
```bash
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  sh -c "sed -i 's/scram-sha-256/md5/g' /var/lib/postgresql/data/pg_hba.conf"
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  su postgres -c "pg_ctl reload -D /var/lib/postgresql/data"
kubectl rollout restart deployment/spark-infra-spark-35-metastore -n spark-infra
```

---

## Load Test Results (2026-02-19 19:20 UTC)

```
=== Spark Connect Standalone Backend Load Test (scenario1) ===
Load parameters: Rows=1000000 Partitions=50 Iterations=3 Mode=range

Iteration 1/3...
  Created DataFrame: 0.00s
  Aggregation: 1.59s (sum=499999500000)
  Filter+Count: 1.37s

Iteration 2/3...
  Created DataFrame: 0.00s
  Aggregation: 1.12s
  Filter+Count: 1.21s

Iteration 3/3...
  Created DataFrame: 0.00s
  Aggregation: 1.39s
  Filter+Count: 0.81s

✓ All load test iterations passed
```

---

## Почему OpenTelemetry отключён

`connect.openTelemetry.enabled=true` добавляет в spark-defaults:
```
spark.extraListeners=org.apache.spark.sql.telemetry.OpenTelemetryListener
spark.plugins=org.apache.spark.sql.telemetry.SparkTelemetryPlugin
```
Оба класса отсутствуют в `spark-custom:3.5.7-new` → `ClassNotFoundException` → Connect падает.

**Решение долгосрочное:** Добавить OTEL jar в `docker/spark-custom/Dockerfile.3.5.7` и пересобрать образ.

---

## Почему History Server не показывает приложения

1. Connect server - long-running приложение
2. Rolling event log пишет в буфер (`events_1_`)
3. Файл коммитится в S3 только при достижении 128MB или остановке приложения
4. Connect server никогда не останавливается → файл не коммитится
5. History Server видит только завершённые файлы

---

---

## Load Test Results (Final - 2026-02-20 10:45 UTC)

```
Scenario 1 (Jupyter + Connect):  ✅ PASSED (3/3 iterations)
  - Aggregation: 1.27-1.36s
  - Filter+Count: 0.62-1.01s
  - History Server: ⚠️ 0 apps (Connect long-running)

Scenario 2 (Airflow + Standalone): ✅ PASSED (3/3 iterations)
  - Aggregation: 1.05-4.98s
  - Filter+Count: 0.49-1.22s
  - History Server: ✅ 1 app (spark-submit завершается, event log коммитится)
```

### Observability Status

| Component | Status | Notes |
|-----------|--------|-------|
| Grafana | ✅ Running | v12.3.1, NodePort 30358 |
| Prometheus datasource | ✅ Added | spark-operations namespace |
| OTEL Collector | ✅ Running | Updated with Prometheus exporter |
| Spark → OTEL | ❌ Disabled | Requires OTEL jar in spark-custom image |

---

## Новые файлы (2026-02-20)

### Пресет для Airflow (прямой Standalone)
- `charts/spark-3.5/presets/scenarios/airflow-standalone.yaml`
- Отключает Spark Connect, включает Standalone master + workers

### Скрипты тестирования
- `scripts/test-spark-standalone-load.sh` - тест прямого Standalone
- `scripts/standalone_load_test.py` - Python-скрипт для load теста

---

**Updated:** 2026-02-20 10:45 UTC
**Previous update:** 2026-02-19 20:25 UTC
