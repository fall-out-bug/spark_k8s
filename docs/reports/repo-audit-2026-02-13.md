# Комплексный аудит репозитория spark_k8s

**Дата:** 2026-02-13  
**Версия проекта:** 0.1.0  
**Product Vision:** Lego-конструктор для Apache Spark на Kubernetes/OpenShift

---

## Метрики на входе

| Метрика | Значение |
|---------|----------|
| Python-файлы (без .sdp) | 163 |
| YAML-файлы (без .sdp) | 221 |
| Shell-скрипты | 350 |
| Dockerfiles | 23 |
| Helm charts | 12 |
| Тестовых файлов (.py) | 69 |
| CI/CD workflows | 16 |
| Preset values files | 11+ |
| Recipes (docs) | 11 категорий |
| Environments | dev / staging / prod |

---

## 1. CODE QUALITY — Оценка: B+

### Сильные стороны

- **Quality gate настроен** (`quality-gate.toml`): CC < 10, файлы < 200 LOC, обязательные type hints, запрет `except: pass`
- **Техдолг трекается** (`docs/tech-debt-map.md`): все debt-тикеты с приоритетами, большинство CLOSED
- **Тестовый conftest.py** хорошо типизирован (Path, Dict, Any, List) с docstrings
- **Нет `except: pass`** в проектном коде (все найденные — в `.sdp/` submodule)
- **Pytest хорошо настроен**: strict markers, 19+ custom markers, log formatting, minversion = 7.0

### Проблемы

| # | Проблема | Серьёзность | Файлы |
|---|----------|-------------|-------|
| CQ-1 | **Тесты > 200 LOC**: 13 файлов (до 443 LOC) | High | test_runbooks.py (443), test_real_k8s_deployment.py (436), test_gpu.py (387)... |
| CQ-2 | **Python scripts > 200 LOC**: 3 файла | Medium | iceberg_examples.py (395), rightsizing_calculator.py (322), gpu_operations_notebook.py (249) |
| CQ-3 | **Нет единого linter config** (.flake8, .pylintrc, pyproject.toml) в корне | Medium | CI ссылается на `scripts/cicd/lint-python.sh` |
| CQ-4 | **Нет requirements.txt / pyproject.toml** в корне проекта | Medium | CI ссылается на несуществующий `requirements.txt` |
| CQ-5 | **Coverage не измеряется реально** — строка coverage в pytest.ini закомментирована | High | pytest.ini line 60 |
| CQ-6 | **Нет pre-commit hooks** (.pre-commit-config.yaml отсутствует) | Medium | Только hook скрипты в `hooks/` |

### Путь к A*

- [ ] Разбить 13 тестовых файлов > 200 LOC (используя test classes и вынос fixtures)
- [ ] Создать `pyproject.toml` с секциями `[tool.black]`, `[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]`
- [ ] Раскомментировать coverage в pytest.ini, настроить `--cov-fail-under=80`
- [ ] Добавить `.pre-commit-config.yaml` (black, ruff, mypy, helm-lint, shellcheck)
- [ ] Разбить `rightsizing_calculator.py` (322 LOC), `iceberg_examples.py` (395 LOC)

---

## 2. ARCHITECTURE QUALITY — Оценка: B

### Сильные стороны

- **Два подхода к charts** сознательно тестируются: модульный (3.5) vs unified (4.1) — хороший эксперимент
- **Dependency инъекция** через Helm subchart (`spark-base` как зависимость)
- **Helper templates** хорошо структурированы: GPU, Iceberg, security — каждый в своём `_*.tpl`
- **Environments overlay** (dev/staging/prod) — правильное разделение конфигов
- **OPA/Rego policies** (`policies/spark-values.rego`) — policy-as-code
- **Network policies**, RBAC, secrets management (External Secrets, Sealed Secrets, Vault) — полный набор

### Проблемы

| # | Проблема | Серьёзность | Где |
|---|----------|-------------|-----|
| AR-1 | **Дублирование шаблонов** между spark-3.5 и spark-4.1 (hive-metastore, postgresql, monitoring — идентичны) | High | charts/spark-3.5/templates/ vs charts/spark-4.1/templates/ |
| AR-2 | **values.yaml > 460 LOC** — монолитный файл конфигурации | Medium | charts/spark-4.1/values.yaml |
| AR-3 | **Дублирование hive-metastore**: и в `/templates/` и в `/templates/core/` (два hive-metastore-configmap.yaml) | High | charts/spark-4.1/templates/ |
| AR-4 | **Дублирование RBAC**: и `rbac.yaml` в корне templates, и `rbac/` директория | Medium | charts/spark-4.1/templates/ |
| AR-5 | **Дублирование KEDA**: и `keda-scaledobject.yaml` в корне, и в `autoscaling/` | Medium | charts/spark-4.1/templates/ |
| AR-6 | **Нет Helm chart tests** (`templates/tests/`) — стандартный механизм Helm для `helm test` | Medium | charts/ |
| AR-7 | **Нет JSON Schema** для values.yaml (`values.schema.json`) | Medium | charts/ |

### Путь к A*

- [ ] Вынести общие компоненты (postgresql, hive-metastore, monitoring) в `spark-base` или отдельные library charts
- [ ] Удалить дубликаты шаблонов (rbac.yaml vs rbac/, keda-scaledobject.yaml vs autoscaling/)
- [ ] Создать `values.schema.json` для обоих чартов (валидация при `helm install`)
- [ ] Добавить `templates/tests/` для `helm test` (smoke test connectivity)
- [ ] Разбить `values.yaml` на sections через `_defaults/` includes или документировать секции

---

## 3. DEVOPS PRACTICES — Оценка: B+

### Сильные стороны

- **16 CI/CD workflows** — покрытие отличное: PR validation, e2e, load tests (nightly/weekly/smoke), security scan, promotion
- **Multi-stage CI**: lint → security → unit tests → SQL validation → dry-run → build → deploy-dev → smoke
- **Trivy** для security scan Docker-образов (scheduled weekly)
- **Gitleaks** для обнаружения секретов
- **Kind cluster** в CI для e2e-тестов — правильный подход
- **Environment promotion**: dev → staging → prod с GitHub Environments
- **Docker multi-stage builds** для Spark (eclipse-temurin builder → python slim)
- **Non-root user** (UID 185) в Dockerfiles — правильная практика
- **Entrypoint с tini** — PID 1 корректно обработан
- **OpenShift compatibility** из коробки (passwd fixup в entrypoint)

### Проблемы

| # | Проблема | Серьёзность | Где |
|---|----------|-------------|-----|
| DO-1 | **Hardcoded credentials в values.yaml**: `minioadmin`/`minioadmin` в 49+ файлах, `hive123` в 5+ файлах | Critical | charts/*/values.yaml, presets/ |
| DO-2 | **security-scan.yml typo**: `runs-on: ubuntu-litted` (должно быть `ubuntu-latest`) | High | .github/workflows/security-scan.yml:76 |
| DO-3 | **security-scan.yml bug**: генерирует `trivy-report.txt`, но пытается загрузить `trivy-results.sarif` | High | .github/workflows/security-scan.yml:48 |
| DO-4 | **Нет Helm chart release pipeline** (chart-releaser, OCI registry) | Medium | .github/workflows/ |
| DO-5 | **Нет image pinning** — `alpine:3.19` в init containers без SHA digest | Medium | templates/spark-connect.yaml |
| DO-6 | **Нет `.dockerignore`** | Medium | docker/ |
| DO-7 | **docker-compose.yaml** использует `quay.io/minio/minio:latest` — непредсказуемо | Low | docker-compose.yaml |
| DO-8 | **actions/checkout@v3** в 4 workflows (устарело, v4 уже используется в других) | Low | spark-job-ci.yml |
| DO-9 | **Нет Renovate/Dependabot** для автоматического обновления зависимостей | Medium | .github/ |
| DO-10 | **Нет CODEOWNERS** | Low | .github/ |

### Путь к A*

- [ ] **CRITICAL**: Вынести все credentials в `.env.example` + документировать ExternalSecrets/Vault для prod. Заменить hardcoded на `${..}` шаблоны в values.yaml
- [ ] Исправить typo `ubuntu-litted` → `ubuntu-latest` в security-scan.yml
- [ ] Исправить несоответствие trivy-report.txt / trivy-results.sarif
- [ ] Добавить `.dockerignore` для всех Docker-контекстов
- [ ] Добавить image digest pinning для init containers
- [ ] Создать chart-releaser workflow (GitHub Pages / OCI)
- [ ] Добавить Dependabot/Renovate конфиг
- [ ] Добавить CODEOWNERS

---

## 4. APACHE SPARK PRACTICES — Оценка: A-

### Сильные стороны

- **Три backend mode** (k8s, standalone, operator) — полное покрытие enterprise use cases
- **Spark Connect** как primary interface — правильная ставка на будущее (Spark 4.x default)
- **Dynamic allocation** правильно настроен с `shuffleTracking.enabled=true`
- **Executor pod templates** через ConfigMap — гибкая настройка pod specs
- **Celeborn integration** для disaggregated shuffle — production-grade для больших workloads
- **RAPIDS/GPU support** с правильной конфигурацией (allocFraction, fallback, task.resource.gpu.amount)
- **Iceberg integration** — полная поддержка (hadoop, hive, REST catalog types)
- **Event logging в S3** — правильная практика для History Server
- **History Server** вынесен отдельно — не нагружает основной Spark Connect
- **spark.sql.catalogImplementation=hive** — правильно для enterprise SQL
- **Production values** с speculation, blacklisting, retry — зрелая конфигурация

### Проблемы

| # | Проблема | Серьёзность | Где |
|---|----------|-------------|-----|
| SP-1 | **Нет spark.sql.adaptive.enabled=true** (AQE) в default configs — это #1 для production | High | spark-defaults.conf, configmap |
| SP-2 | **spark.blacklist.enabled deprecated** в Spark 4.x (переименовано в `spark.excludeOnFailure`) | Medium | environments/prod/values.yaml |
| SP-3 | **Нет настройки spark.kubernetes.executor.deleteOnTermination** | Low | configmap |
| SP-4 | **spark.sql.shuffle.partitions=200** hardcoded — AQE coalesce решает лучше | Medium | prod values |
| SP-5 | **Нет spark.serializer=org.apache.spark.serializer.KryoSerializer** | Low | spark-defaults.conf |
| SP-6 | **Нет spark.sql.parquet.compression.codec** настройки (zstd recommended) | Low | configmap |
| SP-7 | **Нет spark.kubernetes.executor.podNamePrefix** — затрудняет поиск в логах | Low | configmap |
| SP-8 | **Нет примеров Spark Structured Streaming** для real-time scenarios | Medium | examples/ |

### Путь к A*

- [ ] Добавить AQE в default конфиг: `spark.sql.adaptive.enabled=true`, `spark.sql.adaptive.coalescePartitions.enabled=true`
- [ ] Заменить `spark.blacklist.*` на `spark.excludeOnFailure.*` для Spark 4.x
- [ ] Убрать hardcoded `shuffle.partitions=200` в пользу AQE
- [ ] Добавить KryoSerializer как рекомендацию в presets
- [ ] Добавить `spark.kubernetes.executor.podNamePrefix` для лучшей observability
- [ ] Добавить Structured Streaming пример (Kafka → Iceberg flow)

---

## 5. DATA ENGINEERING PRACTICES — Оценка: B

### Сильные стороны

- **Iceberg** как основной table format — правильный выбор для lakehouse
- **Hive Metastore** правильно интегрирован как shared catalog
- **MinIO** для S3-compatible storage — правильно для dev/test
- **Load testing framework** — отличная зрелость: baseline, comparison, regression detection, statistical analyzer
- **Data quality checks** в CI (`scripts/cicd/run-data-quality-checks.sh`)
- **SQL validation** в CI pipeline (`scripts/cicd/validate-sql.sh`, `analyze-sql-plan.sh`)
- **Troubleshooting notebooks** (s3-connection-failed, executor-oom, driver-not-starting) — отличное DX
- **Runbook validator** в тестах — executable runbooks
- **Multiple data workloads** в load tests: read, write, join, aggregate, window, postgres

### Проблемы

| # | Проблема | Серьёзность | Где |
|---|----------|-------------|-----|
| DE-1 | **Нет data lineage** инструмента (OpenLineage/Marquez) | Medium | charts/ |
| DE-2 | **Нет schema registry** (для streaming или Iceberg schema evolution tracking) | Medium | charts/ |
| DE-3 | **Нет примеров data quality** с Great Expectations / Deequ / Soda | Medium | examples/ |
| DE-4 | **Нет примеров ETL pipeline** с retry, idempotency, backfill | Medium | examples/ |
| DE-5 | **Нет Delta Lake** поддержки (альтернативный table format) | Low | charts/ |
| DE-6 | **Нет примеров partitioning strategy** для Iceberg tables | Low | examples/ |
| DE-7 | **Airflow DAGs — примеры, а не production-ready шаблоны** | Medium | docker/optional/airflow/dags/ |
| DE-8 | **Observability charts (Prometheus, Grafana, Loki, Jaeger)** не интегрированы с main chart как dependencies | Medium | charts/observability/ |

### Путь к A*

- [ ] Добавить OpenLineage integration preset (Spark listener → Marquez)
- [ ] Создать production-ready Airflow DAG templates (с retry, SLA, alerting, idempotency)
- [ ] Добавить data quality preset (Great Expectations + Spark) или Deequ integration
- [ ] Создать Iceberg best practices doc (partitioning, compaction, snapshot expiry)
- [ ] Интегрировать observability stack как optional dependency в main chart

---

## Сводная матрица

| Аспект | Текущий | Цель A* | Gap | Усилие |
|--------|---------|---------|-----|--------|
| **Code Quality** | B+ | A* | 5 задач | ~2 WS |
| **Architecture** | B | A* | 7 задач | ~3 WS |
| **DevOps** | B+ | A* | 10 задач (1 Critical) | ~3 WS |
| **Apache Spark** | A- | A* | 8 задач | ~2 WS |
| **Data Engineering** | B | A* | 8 задач | ~3 WS |

**Общий грейд: B+**  
**Целевой грейд: A***

---

## План прокачки до A* (приоритизированный)

### Wave 1 — Critical & Quick Wins (1-2 WS)

| # | Задача | Аспект | Impact |
|---|--------|--------|--------|
| 1 | Fix hardcoded credentials → template variables + docs | DevOps | Critical security |
| 2 | Fix security-scan.yml (typo + sarif bug) | DevOps | CI broken |
| 3 | Uncomment coverage, create pyproject.toml | Code | Foundation |
| 4 | Add AQE to Spark defaults | Spark | Performance +20-40% |
| 5 | Fix deprecated spark.blacklist → spark.excludeOnFailure | Spark | Forward compatibility |

### Wave 2 — Structural Improvements (2-3 WS)

| # | Задача | Аспект | Impact |
|---|--------|--------|--------|
| 6 | Extract shared templates to spark-base library chart | Architecture | DRY, maintainability |
| 7 | Remove template duplicates (rbac, keda, hive-metastore) | Architecture | Clarity |
| 8 | Create values.schema.json for Helm validation | Architecture | UX, correctness |
| 9 | Add .pre-commit-config.yaml + .dockerignore | DevOps | Developer DX |
| 10 | Split 13 test files > 200 LOC | Code | Quality gate |

### Wave 3 — Feature Completeness (3-4 WS)

| # | Задача | Аспект | Impact |
|---|--------|--------|--------|
| 11 | Add OpenLineage integration | DataEng | Lineage visibility |
| 12 | Create production Airflow DAG templates | DataEng | Production patterns |
| 13 | Add Structured Streaming example | Spark | Use case coverage |
| 14 | Integrate observability as chart dependency | DataEng | Single helm install |
| 15 | Add Helm chart tests + chart-releaser | Architecture + DevOps | Release maturity |

### Wave 4 — Polish (2-3 WS)

| # | Задача | Аспект | Impact |
|---|--------|--------|--------|
| 16 | Add Dependabot/Renovate + CODEOWNERS | DevOps | Maintenance |
| 17 | Add data quality examples (Great Expectations / Deequ) | DataEng | DQ patterns |
| 18 | Add Iceberg best practices doc (partitioning, compaction) | DataEng | Knowledge |
| 19 | Pin all image tags with SHA digests | DevOps | Reproducibility |
| 20 | Add KryoSerializer, zstd compression, podNamePrefix to presets | Spark | Performance |

---

## Ожидаемый результат после A*

После выполнения 4 волн (примерно 10-12 WS):

- **Code Quality A***: 100% файлов < 200 LOC, coverage ≥80% enforced, unified linting
- **Architecture A***: Zero duplication, schema-validated Helm, library charts
- **DevOps A***: Zero hardcoded secrets, 100% CI green, chart release pipeline, image pinning
- **Spark A***: AQE enabled, modern configs, streaming support, all 3 backends battle-tested
- **Data Engineering A***: Lineage, DQ, production DAGs, observability-in-a-box

**Итого: Зрелая, enterprise-grade платформа для Spark на K8s.**
