# Пресс-релиз: Spark K8s Constructor v0.1.0

**ДЛЯ НЕЗАМЕДЛИТЕЛЬНОГО РАСПРОСТРАНЕНИЯ**

---

## Вышел первый релиз Spark K8s Constructor: готовое решение Apache Spark на Kubernetes

**26 января 2025 года** — Команда Spark K8s Constructor анонсирует выпуск версии 0.1.0 — модульных Helm-чартов для развёртывания Apache Spark на Kubernetes. Релиз предоставляет data engineering-командам готовые пресеты конфигураций для быстрого запуска Spark 3.5.7 и 4.1.0 в Kubernetes-инфраструктуре.

### Что такое Spark K8s Constructor?

Spark K8s Constructor — это набор модульных Helm-чартов, который позволяет разворачивать Apache Spark на Kubernetes без необходимости писать Kubernetes-манифесты с нуля. Проект поддерживает три режима работы (K8s native, Spark Standalone, Spark Operator) и включает интеграции с ключевыми компонентами дата-платформы.

**Основные возможности:**

| Компонент | Назначение |
|-----------|-------------|
| **Spark Connect Server** | Удалённое выполнение Spark через gRPC |
| **Jupyter Lab** | Интерактивные ноутбуки с удалённым Spark |
| **Apache Airflow** | Оркестрация Spark-задач |
| **MLflow** | Отслеживание ML-экспериментов |
| **MinIO** | S3-совместимое хранилище |
| **Hive Metastore** | Метаданные таблиц |
| **History Server** | Мониторинг и логирование задач |

### 11 готовых пресетов для типовых сценариев

Релиз включает 11 протестированных пресетов конфигураций для распространённых сценариев использования:

**Для Data Science:**
- `jupyter-connect-k8s.yaml` — Jupyter + Spark Connect (K8s backend)
- `jupyter-connect-standalone.yaml` — Jupyter + Spark Connect (Standalone backend)

**Для Data Engineering:**
- `airflow-connect-k8s.yaml` — Airflow + Spark Connect (K8s backend)
- `airflow-connect-standalone.yaml` — Airflow + Spark Connect (Standalone backend)
- `airflow-k8s-submit.yaml` — Airflow с K8s submit mode
- `airflow-operator.yaml` — Airflow + Spark Operator

**Поддержка версий Spark:**
- Spark 4.1.0 (унифицированный чарт с toggle-flags)
- Spark 3.5.7 (модульная архитектура: spark-base, spark-connect, spark-standalone)

### Режимы работы backend

Spark K8s Constructor поддерживает три режима исполнения Spark-задач:

| Режим | Описание | Применение |
|-------|----------|------------|
| **k8s** | Динамические executors через Kubernetes API | Cloud-native, auto-scaling |
| **standalone** | Фиксированный кластер (master/workers) | Предсказуемые ресурсы, on-prem |
| **operator** | Spark Operator (CRD-based) | Продвинутое планирование, pod templates |

### Тестирование и качество

Релиз прошёл полное цикл тестирования на Minikube:

- **E2E тесты:** 6 сценариев, все пройдены
- **Load тесты:** 11M+ записей (NYC taxi dataset)
- **Preset валидация:** 11/11 пресетов проходят `helm template --dry-run`
- **Policy validation:** OPA/Conftest для compliance

**Обнаружены и исправлены 5 issues:**
- ISSUE-030: Helm "N/A" label validation (документирован workaround)
- ISSUE-031: Автосоздание secret s3-credentials
- ISSUE-033: RBAC permissions для ConfigMaps
- ISSUE-034: Python зависимости в Jupyter (grpcio, grpcio-status, zstandard)
- ISSUE-035: Исправлен механизм загрузки parquet данных

### Документация на русском и английском

Полная документация доступна на двух языках:

**Руководства:**
- [Spark K8s Constructor: Руководство пользователя (RU)](docs/guides/ru/spark-k8s-constructor.md)
- [Spark K8s Constructor: User Guide (EN)](docs/guides/en/spark-k8s-constructor.md)

**Quick Reference:**
- [Быстрая справка (RU)](docs/guides/ru/quick-reference.md)
- [Quick Reference (EN)](docs/guides/en/quick-reference.md)

**Рецепты (23 guides):**
- Operations: настройка event log, инициализация Hive Metastore
- Troubleshooting: S3 connection, RBAC, driver issues, dependencies
- Deployment: развёртывание для новой команды, миграция Standalone → K8s
- Integration: Airflow, MLflow, внешние Metastore, Kerberos, Prometheus

### Для кого это решение?

**Для Data Scientists:**
- Быстрый старт: 1 команда `helm install`
- Jupyter с преднастроенным Spark Connect
- Интерактивная разработка без локального Spark

**Для Data Engineers:**
- Готовые пресеты для Airflow-оркестрации
- Поддержка batch processing и ETL
- История задач через History Server

**Для Platform Operators:**
- Модульная архитектура (LEGO-подобная)
- GitOps-ready (Helm charts + Git)
- Policy-as-code (OPA/Conftest)
- RBAC и security best practices

### Метрики релиза

| Показатель | Значение |
|------------|----------|
| Версия | 0.1.0 |
| Файлов | 74 |
| Строк кода | 10,020+ |
| Пресетов | 11 |
| Рецептов | 23 |
| Test scripts | 10 |
| Языки документации | RU + EN |
| Test Coverage | ≥80% |

### Методология разработки

Проект разработан с использованием **Spec-Driven Protocol (SDP)** — методологии, которая обеспечивает:

- Атомарные workstreams с чёткими границами
- Quality gates (coverage ≥80%, CC < 10)
- Документацию как первоклассный артефакт
- Полную прослеживаемость от идеи до деплоя

**Результат:** 5 production issues обнаружены и исправлены до релиза.

### Быстрый старт

```bash
# Установка Spark Connect + Jupyter (Spark 4.1)
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
  -n spark --create-namespace

# Доступ к Jupyter
kubectl port-forward -n spark svc/jupyter 8888:8888
# Открыть http://localhost:8888
```

В Jupyter:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
df = spark.range(1000)
df.show()
```

### Контакты

- **Репозиторий:** https://github.com/fall-out-bug/spark_k8s
- **Документация:** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/README.md
- **Issues:** https://github.com/fall-out-bug/spark_k8s/issues
- **Release Notes:** https://github.com/fall-out-bug/spark_k8s/releases/tag/v0.1.0

---

### О релизе

**Версия:** 0.1.0
**Дата релиза:** 26 января 2025
**Версии Spark:** 3.5.7, 4.1.0
**Лицензия:** MIT
**Методология:** Spec-Driven Protocol (SDP)

**Полный Changelog:** https://github.com/fall-out-bug/spark_k8s/blob/v0.1.0/CHANGELOG.md

---

# # #

**Spark K8s Constructor — Apache Spark на Kubernetes, готовый к производству.**

https://github.com/fall-out-bug/spark_k8s
