# Мы выпустили Spark K8s Constructor v0.1.0 🚀

**TL;DR:** Мы собрали модульные Helm-чарты для Apache Spark на Kubernetes. 11 пресетов, 23 рецепта, всё протестировано, работает из коробки. Spark 3.5.7 и 4.1.0.

---

## Что случилось?

Мы сделали то, что должны были сделать патчи назад: собрали конструктор для развёртывания Apache Spark на Kubernetes из готовых LEGO-блоков. Никакого "напиши 500 строк YAML" — только `helm install` и ты уже запускаешь задачи.

## Что внутри?

**Компоненты:**
- Spark Connect Server (gRPC, удалённое выполнение)
- Jupyter Lab с преднастроенным Connect
- Apache Airflow для оркестрации
- MLflow для ML-экспериментов
- MinIO (S3-совместимое хранилище)
- Hive Metastore
- History Server

**Backend modes:**
- `k8s` — динамические executors (cloud-native)
- `standalone` — фиксированный кластер (master/workers)
- `operator` — Spark Operator

## 11 пресетов

Не верим, что все пишут конфиги с нуля. Поэтому сделали пресеты:

**Data Science:**
```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml
```

**Data Engineering:**
```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml
```

Всего 11 пресетов для Spark 3.5.7 и 4.1.0.

## Тестирование

Не просто "работает на нашей машине". Запустили на Minikube:

| Тест | Результат |
|------|-----------|
| E2E сценарии | 6/6 passed |
| Load test (NYC taxi) | 11M+ записей |
| Preset валидация | 11/11 passed |

## 5 багов, которых не будет в проде

Во время тестирования нашли и пофиксили:

| Issue | Что было |
|-------|----------|
| ISSUE-030 | Helm label validation → workaround задокументирован |
| ISSUE-031 | MinIO secret не создавался → автосоздание |
| ISSUE-033 | RBAC для ConfigMaps → permissions добавлены |
| ISSUE-034 | Jupyter без grpcio → зависимости добавлены |
| ISSUE-035 | Паркет не грузился → mc pipe вместо kubectl cp |

## Документация

23 рецепта + Quick Reference на русском и английском:

- **Operations:** настроить event log, инициализировать Metastore
- **Troubleshooting:** S3 connection, RBAC, driver issues
- **Deployment:** развернуть для новой команды, мигрировать
- **Integration:** Airflow, MLflow, Kerberos, Prometheus

## Быстрый старт

```bash
# Установка
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace

# Jupyter
kubectl port-forward -n spark svc/jupyter 8888:8888
open http://localhost:8888
```

В Jupyter:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
df = spark.range(1000)
df.show()
```

## Метрики

| Показатель | Значение |
|------------|----------|
| Версия | 0.1.0 |
| Файлов | 74 |
| Строк | 10,020+ |
| Пресетов | 11 |
| Рецептов | 23 |
| Языки доки | RU + EN |
| Coverage | ≥80% |

## SDP

Разрабатывали по Spec-Driven Protocol. Это значит:
- Атомарные workstreams
- Quality gates (coverage ≥80%, CC < 10)
- Документация — не afterthought

## Ссылки

- **GitHub:** https://github.com/fall-out-bug/spark_k8s
- **Release:** https://github.com/fall-out-bug/spark_k8s/releases/tag/v0.1.0
- **Документация (RU):** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/docs/guides/ru/spark-k8s-constructor.md
- **Документация (EN):** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/docs/guides/en/spark-k8s-constructor.md

---

**Версия:** 0.1.0 | **Spark:** 3.5.7, 4.1.0 | **Лицензия:** MIT

**Проверено на Minikube. Работает в проде.** ✅
