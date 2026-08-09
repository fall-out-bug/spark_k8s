# Idea: Spark Standalone Helm Chart for Kubernetes

**Created:** 2026-01-15
**Status:** Designed (10 workstreams created)
**Author:** user/agent

---

## 1. Problem Statement

### Current State
Проект имеет Helm chart `spark-platform` с Spark Connect режимом для Data Scientists. Spark Connect использует динамические K8s executors и оптимален для интерактивной работы из Jupyter notebooks.

Существуют legacy пайплайны, которые используют классический Spark Standalone режим (master + workers) и требуют миграции на Kubernetes.

### Problem
- Legacy пайплайны несовместимы с Spark Connect API
- Нет возможности запускать классические spark-submit jobs в текущей инфраструктуре
- Отсутствует поддержка Airflow и MLflow для batch processing

### Impact
- Блокирует миграцию legacy workloads на Kubernetes
- Разделение: Spark Connect для DS (интерактивная работа), Spark Standalone для ETL/batch (Airflow)
- Унификация инфраструктуры: один Kubernetes кластер для всех Spark workloads

---

## 2. Proposed Solution

### Description
Создать отдельный Helm chart `spark-standalone` для деплоя классического Spark Standalone кластера в Kubernetes с поддержкой:
- Master + Workers архитектуры
- High Availability через S3
- Интеграции с существующей инфраструктурой (MinIO, History Server)
- Airflow и MLflow для оркестрации и трекинга

### Key Capabilities
1. **Spark Master** — координатор кластера с Web UI
2. **Spark Workers** — configurable количество (1-10)
3. **HA Master** — recovery state через S3 (не ZooKeeper)
4. **External Shuffle Service** — для стабильности при dynamic allocation
5. **Ingress** — доступ к Web UI master и workers
6. **Airflow** — оркестрация spark-submit jobs
7. **MLflow** — experiment tracking и model registry
8. **Hive Metastore** — отдельный инстанс для Standalone

---

## 3. User Stories

### Primary User: Data Engineer
- As a Data Engineer, I want to deploy Spark Standalone cluster via Helm so that I can run legacy spark-submit jobs
- As a Data Engineer, I want HA master so that jobs don't fail on master restart
- As a Data Engineer, I want Airflow integration so that I can orchestrate ETL pipelines
- As a Data Engineer, I want to scale workers so that I can handle varying workloads

### Secondary User: ML Engineer
- As an ML Engineer, I want MLflow integration so that I can track experiments on Spark
- As an ML Engineer, I want to submit training jobs via spark-submit so that I can use distributed training

### Secondary User: DevOps Engineer
- As a DevOps Engineer, I want Helm chart with configurable values so that I can deploy to k3s/minikube and OpenShift
- As a DevOps Engineer, I want Ingress resources so that I can expose Web UI securely

---

## 4. Scope

### In Scope
- Helm chart `spark-standalone` с master + workers
- HA master с S3 recovery backend
- External Shuffle Service
- Ingress для Web UI (master, workers, Airflow, MLflow)
- Отдельный Hive Metastore для Standalone
- Airflow deployment (Kubernetes Executor) + example DAGs
- Airflow PostgreSQL (опционально, для тестов)
- MLflow deployment (PostgreSQL backend, MinIO artifacts)
- MLflow PostgreSQL (опционально, для тестов)
- MinIO bucket `mlflow-artifacts`
- Интеграция с общими компонентами (MinIO, History Server)
- E2E тесты spark-submit
- Airflow DAG тесты
- MLflow experiment тесты
- Поддержка k3s/minikube (local) и OpenShift (prod)
- OpenShift SCC `restricted` совместимость
- PodSecurityStandards (PSS) для эмуляции OpenShift в локальном окружении
- Security hardening: runAsNonRoot, drop capabilities, readOnlyRootFilesystem, no privileged

### Out of Scope
- Custom Spark image (используем существующий `spark-custom:3.5.7`)
- Prometheus/Grafana мониторинг (отдельная фича)
- Доступ к реальному OpenShift (только эмуляция через PSS)

### Future Considerations
- HPA autoscaling для workers (nice-to-have)
- Валидация на реальном OpenShift кластере
- GPU workers для ML workloads

---

## 5. Success Criteria

### Acceptance Criteria
- [ ] Spark Master запускается и доступен по Service
- [ ] Spark Workers (1-10) автоматически регистрируются на Master
- [ ] HA: Master восстанавливается после рестарта через S3 state
- [ ] External Shuffle Service работает
- [ ] spark-submit успешно выполняет job из CLI
- [ ] Jupyter notebook подключается к Standalone кластеру
- [ ] Airflow Webserver + Scheduler запускаются
- [ ] Airflow Kubernetes Executor создает worker pods в том же namespace
- [ ] Airflow DAG успешно запускает spark-submit job (pod с spark-custom image)
- [ ] MLflow Tracking Server запускается с PostgreSQL backend
- [ ] MLflow сохраняет artifacts в MinIO bucket `mlflow-artifacts`
- [ ] MLflow трекает эксперименты из Spark job
- [ ] Ingress обеспечивает доступ к Web UI (Master, Airflow, MLflow)
- [ ] Chart деплоится на k3s/minikube без ошибок
- [ ] Chart деплоится с PSS `restricted` namespace без ошибок (эмуляция OpenShift)
- [ ] Все pods запускаются как non-root user
- [ ] Все pods работают с dropped capabilities и readOnlyRootFilesystem
- [ ] Общий History Server показывает логи от Standalone jobs
- [ ] Standalone и Spark Connect могут работать в одном namespace

### Metrics (if applicable)
- Worker registration time: < 30 seconds
- Master HA failover time: < 60 seconds
- spark-submit job completion: baseline Pi calculation < 2 minutes

---

## 6. Dependencies & Risks

### Dependencies
| Dependency | Type | Status |
|------------|------|--------|
| spark-custom:3.5.7 image | Hard | Ready |
| MinIO (S3 storage) | Hard | Ready |
| History Server | Soft | Ready |
| PostgreSQL (for Hive Metastore) | Hard | Ready (in chart) |
| PostgreSQL (for Airflow) | Hard | Ready (in chart for tests, external for prod) |
| PostgreSQL (for MLflow) | Hard | Ready (in chart for tests, external for prod) |
| apache/airflow image | Hard | Ready (public) |
| Kubernetes cluster (k3s/minikube/OpenShift) | Hard | Ready |

### Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| PSS эмуляция не покрывает все OpenShift особенности | Medium | Medium | Документировать известные различия, валидировать на реальном OpenShift позже |
| Spark/Airflow/MLflow images требуют root | Medium | High | Проверить base images, создать non-root варианты если нужно |
| HA S3 recovery медленный | Low | Medium | Оптимизировать checkpoint interval |
| Конфликт портов SA + SC в одном namespace | Medium | Medium | Использовать разные port ranges |
| Airflow/MLflow увеличивают complexity | Medium | Medium | Сделать опциональными (enabled: false по умолчанию) |

---

## 7. Open Questions

- [x] ~~Какой Airflow image использовать?~~ → `apache/airflow` для тестов, configurable для prod
- [x] ~~MLflow backend store?~~ → PostgreSQL
- [x] ~~MLflow artifact store?~~ → MinIO, отдельный bucket `mlflow-artifacts`
- [x] ~~Отдельный PostgreSQL для Airflow?~~ → Да, опционально в чарте для тестов, внешний в prod
- [x] ~~Airflow executor?~~ → Kubernetes Executor (tasks как pods в том же namespace)
- [x] ~~Example DAGs?~~ → Оба: Spark ETL pipeline + MLflow training job (синтетические данные)

---

## 8. Notes

### Архитектура чартов
```
charts/
├── spark-platform/      # Существующий (Spark Connect + инфра)
└── spark-standalone/    # Новый (Standalone + Airflow + MLflow)
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── master.yaml
        ├── worker.yaml
        ├── shuffle-service.yaml
        ├── hive-metastore.yaml
        ├── airflow/
        │   ├── webserver.yaml
        │   ├── scheduler.yaml
        │   ├── postgresql.yaml    # Опционально для тестов
        │   └── configmap.yaml
        ├── mlflow/
        │   ├── server.yaml
        │   └── postgresql.yaml    # Опционально для тестов
        ├── ingress.yaml
        ├── configmap.yaml
        ├── secrets.yaml
        └── rbac.yaml
```

### Конфигурация компонентов

**Airflow:**
- Image: `apache/airflow` (configurable для prod)
- Executor: Kubernetes Executor
- Worker pods: тот же namespace, image `spark-custom:3.5.7`
- PostgreSQL: опционально в чарте (enabled для тестов), внешний для prod
- Example DAGs:
  - `spark_etl_synthetic.py` — генерация синтетических данных → трансформация → запись в MinIO
  - `mlflow_training_synthetic.py` — spark-submit ML job с логированием метрик/моделей в MLflow

**MLflow:**
- Backend store: PostgreSQL (опционально в чарте или внешний)
- Artifact store: MinIO bucket `mlflow-artifacts`
- Tracking server с Web UI

**MinIO buckets:**
- `mlflow-artifacts` — MLflow artifacts (новый)
- `spark-standalone-logs` — Standalone event logs
- Существующие buckets shared с spark-platform

### Совместное использование
- MinIO: общий, buckets разделены
- History Server: общий, читает логи из разных directories
- PostgreSQL: раздельные инстансы (Hive Metastore, Airflow, MLflow)

### OpenShift Security (SCC restricted)

**PodSecurityStandards для эмуляции:**
```yaml
# Namespace label для PSS restricted
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
```

**SecurityContext для всех pods:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

**Writable directories (emptyDir для readOnlyRootFilesystem):**
- `/tmp`
- `/opt/spark/work-dir`
- `/opt/airflow/logs`
- `/home/mlflow`

### Ссылки
- [Spark Standalone Mode](https://spark.apache.org/docs/latest/spark-standalone.html)
- [Spark HA with S3](https://spark.apache.org/docs/latest/spark-standalone.html#high-availability)
- [Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [MLflow on Kubernetes](https://mlflow.org/docs/latest/tracking.html)
- [OpenShift SCC restricted](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

---

## Next Steps

1. **Review draft** — уточнить Open Questions
2. **Run `/design idea-spark-standalone-chart`** — создать workstreams
