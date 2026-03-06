# Chart Hallucination Audit — 2026-03-05

Аудит чартов на ссылки на несуществующие классы, конфиги и API.

## Резюме

| Категория | Статус | Действие |
|-----------|--------|----------|
| **org.apache.spark.openTelemetry.OpenTelemetryListener** | ❌ Галлюцинация | Удалить из Airflow presets и DAGs |
| **io.openlineage.spark.OpenLineageSparkListener** | ❌ Неверный класс | Заменить на `io.openlineage.spark.agent.OpenLineageSparkListener` |
| **spark.openlineage.host** | ❌ Устаревший/неверный | Заменить на `spark.openlineage.transport.url` + `transport.type=http` |
| **com.nvidia.spark.SQLPlugin** | ✅ Реальный | NVIDIA RAPIDS, в deps |
| **org.apache.spark.scheduler.ResourceWaitTracker** | ✅ Реальный | Кастомный JAR в репо |
| **org.apache.spark.shuffle.celeborn.RssShuffleManager** | ✅ Реальный | Apache Celeborn |
| **org.apache.iceberg.***, org.apache.hadoop.*** | ✅ Реальные | Стандартные библиотеки |

---

## 1. OTEL — org.apache.spark.openTelemetry.OpenTelemetryListener

**Проблема:** Класс не существует в Apache Spark 3.5.x и 4.x. При включении OTEL через `spark.extraListeners` — `ClassNotFoundException`.

**Файлы:**
- `charts/spark-3.5/airflow-connect-standalone-3.5.7.yaml`
- `charts/spark-3.5/airflow-connect-standalone-3.5.8.yaml`
- `charts/spark-3.5/airflow-connect-k8s-3.5.7.yaml`
- `charts/spark-3.5/airflow-connect-k8s-3.5.8.yaml`
- `charts/spark-3.5/airflow-iceberg-connect-k8s-3.5.7.yaml`
- `charts/spark-3.5/airflow-iceberg-connect-k8s-3.5.8.yaml`
- `charts/spark-3.5/airflow-gpu-connect-k8s-3.5.7.yaml`
- `charts/spark-3.5/airflow-gpu-connect-k8s-3.5.8.yaml`
- `charts/spark-3.5/dags/nyc_taxi_ml_full_pipeline.py`

**Решение:** Удалить `spark.extraListeners` и `spark.openTelemetry.*` из этих файлов. OTEL уже реализован через Java agent (`opentelemetry-javaagent.jar`) в Connect deployment — не дублировать через Spark config.

---

## 2. OpenLineage — неверный класс и конфиг

**Проблема 1:** Класс `io.openlineage.spark.OpenLineageSparkListener` неверный.
Правильный: `io.openlineage.spark.agent.OpenLineageSparkListener` (см. [OpenLineage docs](https://openlineage.io/docs/integrations/spark/configuration/usage/)).

**Проблема 2:** `spark.openlineage.host` — устаревший/недокументированный параметр.
Правильно: `spark.openlineage.transport.type=http` и `spark.openlineage.transport.url=<endpoint>`.

**Файлы:**
- `charts/spark-4.0/templates/spark-connect-configmap.yaml`
- `charts/spark-4.1/templates/spark-connect-configmap.yaml`

**Текущий фрагмент:**
```yaml
spark.extraListeners=io.openlineage.spark.OpenLineageSparkListener
spark.openlineage.host={{ .Values.features.openLineage.endpoint | default "http://marquez:5000" }}
```

**Исправление:**
```yaml
spark.extraListeners=io.openlineage.spark.agent.OpenLineageSparkListener
spark.openlineage.transport.type=http
spark.openlineage.transport.url={{ .Values.features.openLineage.endpoint | default "http://marquez:5000" }}
```

**Примечание:** OpenLineage JAR (`openlineage-spark_2.13`) есть в `docker/spark-4.1/deps/pom.xml`. Для spark-3.5 — проверить наличие в образе.

---

## 3. Проверенные и корректные ссылки

| Класс/конфиг | Источник |
|--------------|----------|
| `com.nvidia.spark.SQLPlugin` | NVIDIA RAPIDS, `rapids-4-spark_2.13` в deps |
| `org.apache.spark.scheduler.ResourceWaitTracker` | Кастомный JAR `docker/spark-3.5/listeners/resource-wait-tracker/` |
| `org.apache.spark.shuffle.celeborn.RssShuffleManager` | Apache Celeborn client |
| `org.apache.iceberg.spark.*` | Iceberg Spark runtime |
| `org.apache.hadoop.fs.s3a.S3AFileSystem` | Hadoop AWS |
| `org.apache.spark.metrics.sink.PrometheusServlet` | Spark metrics (встроено) |
| `org.apache.spark.deploy.history.FsHistoryProvider` | Spark History Server |
| `org.apache.spark.sql.connect.service.SparkConnectServer` | Spark Connect (3.5+, 4.x) |

---

## 4. Matrix-сценарии: обязательные инъекции в run-matrix.sh

| Инъекция | Условие | Причина |
|----------|---------|---------|
| `jupyter.enabled=false` | Всегда | Default=true; Jupyter не нужен в matrix, экономит ресурсы |
| `connect.backendMode=standalone` | connect=true и k8s_mode=standalone | SCENARIO-0036 и др.: Connect+Standalone без этого падает (default=k8s) |
| `features.openLineage.enabled=true` | openlineage=true и spark 4.1.x | Сценарии используют openlineage.enabled, chart — features.openLineage.enabled |

**Статус:** Добавлено в `scripts/run-matrix.sh` (2026-03-05).

---

## 5. Рекомендации

1. **OTEL:** Удалить все `spark.extraListeners=org.apache.spark.openTelemetry.*` и `spark.openTelemetry.*` из Airflow presets и DAGs.
2. **OpenLineage:** Исправить класс и transport config в spark-4.0 и spark-4.1.
3. **spark-3.5 + OpenLineage:** ✅ Цепочка завершена (2026-03-06): добавлен блок в `spark-connect-configmap.yaml` и JAR `openlineage-spark_2.12-1.24.0` в `docker/spark-custom/Dockerfile.3.5.7` и `Dockerfile.3.5.8`.

4. **tests/evidence/*** — snapshot-артефакты. Регенерация: `./scripts/generate-helm-evidence.sh baseline` и `./scripts/generate-helm-evidence.sh final`. ✅ Выполнено.

5. **extraListeners conflict (spark-3.5):** При включении OpenLineage и resource-wait-tracker второй перезаписывал первый. ✅ Исправлено: объединение через запятую.
