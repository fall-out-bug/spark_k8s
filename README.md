# Spark Platform на Kubernetes

Apache Spark 3.5.7 с динамическими K8s executor-подами, Hive Metastore, S3 хранилищем (MinIO), JupyterHub (многопользовательский режим) и JupyterLab.

## Оглавление

- [Архитектура](#архитектура)
- [Компоненты](#компоненты)
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Конфигурация](#конфигурация)
- [Использование](#использование)
- [Мониторинг](#мониторинг)
- [Troubleshooting](#troubleshooting)
- [Структура проекта](#структура-проекта)

---

## Архитектура

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐        ┌──────────────────────────────────────────┐    │
│  │ JupyterLab  │───────►│     Spark Connect Server (Driver)        │    │
│  │ (PySpark    │  gRPC  │     spark.master=k8s://kubernetes.default│    │
│  │  client)    │ :15002 │                                          │    │
│  └─────────────┘        └──────────────────┬───────────────────────┘    │
│                                            │                             │
│                         K8s API: создание executor подов                 │
│                                            │                             │
│                    ┌───────────────────────┼───────────────────────┐    │
│                    ▼                       ▼                       ▼    │
│              ┌──────────┐           ┌──────────┐           ┌──────────┐ │
│              │Executor-1│           │Executor-2│           │Executor-N│ │
│              │ (K8s Pod)│           │ (K8s Pod)│           │ (K8s Pod)│ │
│              └────┬─────┘           └────┬─────┘           └────┬─────┘ │
│                   │                      │                      │       │
│                   └──────────────────────┼──────────────────────┘       │
│                                          ▼                              │
│                              ┌───────────────────┐                      │
│                              │   MinIO (S3)      │                      │
│                              │ s3a://warehouse/  │                      │
│                              │ s3a://spark-logs/ │                      │
│                              └───────────────────┘                      │
│                                          ▲                              │
│  ┌────────────────────────┐              │                              │
│  │ Spark History Server   │◄─────────────┘                              │
│  │ s3a://spark-logs/events│   читает event logs                        │
│  └────────────────────────┘                                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Принцип работы

1. **JupyterLab** подключается к Spark Connect Server через gRPC протокол (порт 15002)
2. **Spark Connect Server** выступает драйвером и использует `spark.master=k8s://...` для создания executor-подов
3. **Executor-поды** создаются динамически при выполнении задач и удаляются после завершения
4. **MinIO** предоставляет S3-совместимое хранилище для данных и логов
5. **History Server** читает event logs из S3 для отображения истории выполненных задач

### Почему не Spark Operator?

Этот проект использует **нативную интеграцию Spark с Kubernetes** (`spark.master=k8s://...`) вместо Spark Operator:

| Критерий | Native K8s | Spark Operator |
|----------|------------|----------------|
| CRD | Не требуется | Требуется установка CRD |
| OpenShift | Работает без дополнительных прав | Требует особые разрешения |
| Dynamic Allocation | Поддерживается | Ограниченная поддержка |
| Сложность | Проще | Дополнительный компонент |
| Управление executor'ами | Напрямую через K8s API | Через оператор |

---

## Компоненты

### Spark Connect Server

**Назначение:** Центральный драйвер Spark с gRPC API для подключения клиентов.

| Параметр | Значение |
|----------|----------|
| Порт gRPC | 15002 |
| Порт Spark UI | 4040 |
| Память драйвера | 2g (настраивается) |
| Режим | `spark.master=k8s://kubernetes.default.svc` |

**Особенности:**
- Создает executor-поды динамически через K8s API
- Поддерживает Dynamic Allocation (автоматическое масштабирование)
- Shuffle tracking для корректного удаления неактивных executor'ов
- Совместим с Java 17 (настроены `--add-opens` флаги)

### JupyterHub (многопользовательский режим)

**Назначение:** Многопользовательская среда Jupyter с динамическим созданием изолированных ноутбук-серверов для каждого пользователя.

| Параметр | Значение |
|----------|----------|
| Порт | 8000 (NodePort: 30888) |
| Spawner | KubeSpawner |
| Аутентификация | NativeAuthenticator |
| Admin | admin / admin123 |

**Особенности:**
- **KubeSpawner** - каждый пользователь получает отдельный pod с JupyterLab
- **Профили ресурсов** - пользователи выбирают размер ноутбука (Small/Medium/Large)
- **Автоматическое отключение** - неактивные серверы удаляются через 1 час
- **Самостоятельная регистрация** - открытая регистрация новых пользователей
- **S3 credentials** - автоматически передаются в пользовательские поды

**Профили ресурсов:**
| Профиль | CPU | RAM | Описание |
|---------|-----|-----|----------|
| Small | 1 core | 2 GB | Легкий анализ данных |
| Medium | 2 cores | 4 GB | Типичная работа (по умолчанию) |
| Large | 4 cores | 8 GB | Тяжелые вычисления |

### JupyterLab (одиночный режим)

**Назначение:** Простой однопользовательский JupyterLab (отключен по умолчанию в пользу JupyterHub).

| Параметр | Значение |
|----------|----------|
| Порт | 8888 |
| Python | 3.11 |
| PySpark | 3.5.7 |

**Предустановленные библиотеки:**
- `pyspark[connect]` - клиент Spark Connect
- `pandas`, `numpy` - работа с данными
- `pyarrow` - Arrow-формат для Spark
- `boto3` - работа с S3

### MinIO

**Назначение:** S3-совместимое объектное хранилище.

| Параметр | Значение |
|----------|----------|
| API порт | 9000 |
| Console порт | 9001 |
| Логин/Пароль | minioadmin / minioadmin |

**Предсозданные бакеты:**
| Бакет | Назначение |
|-------|------------|
| `warehouse` | Основное хранилище данных |
| `spark-logs` | Event logs Spark для History Server |
| `spark-jobs` | Артефакты задач |
| `raw-data` | Сырые данные |
| `processed-data` | Обработанные данные |
| `checkpoints` | Checkpoints для Structured Streaming |

### Spark History Server

**Назначение:** Веб-интерфейс для просмотра истории выполненных Spark задач.

| Параметр | Значение |
|----------|----------|
| Порт | 18080 |
| Log Directory | `s3a://spark-logs/events` |

---

## Требования

### Системные требования

| Компонент | Минимум | Рекомендуется |
|-----------|---------|---------------|
| Kubernetes | 1.24+ | 1.28+ |
| Helm | 3.x | 3.12+ |
| Docker | 20.10+ | 24.0+ |
| RAM кластера | 8 GB | 16+ GB |
| CPU кластера | 4 cores | 8+ cores |

### Для локальной разработки (Kind)

```bash
# Установка Kind
brew install kind

# Создание кластера
kind create cluster --name spark-cluster --config kind-config.yaml
```

Пример `kind-config.yaml`:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30888
    hostPort: 30888
    protocol: TCP
- role: worker
- role: worker
```

---

## Быстрый старт

### Shared values overlay (spark-platform + spark-standalone)

В репозитории есть два чарта:
- `charts/spark-platform` (Spark Connect + platform services)
- `charts/spark-standalone` (Spark Standalone master/workers + optional Airflow/MLflow)

Чтобы конфигурация (S3/MinIO/SA/RBAC) была одинаковой, можно использовать общий overlay:

```bash
helm install spark-platform ./charts/spark-platform -n spark -f charts/values-common.yaml
helm install spark-standalone ./charts/spark-standalone -n spark -f charts/values-common.yaml
```

### 1. Сборка Docker образов

```bash
# Spark образ с S3, JDBC драйверами и Java 17 конфигурацией
docker build -t spark-custom:3.5.7 docker/spark/

# JupyterHub (многопользовательский хаб)
docker build -t jupyterhub-spark:latest docker/jupyterhub/

# JupyterLab (single-user образ для KubeSpawner)
docker build -t jupyter-spark:latest docker/jupyter/
```

### 2. Загрузка образов в Kind (для локальной разработки)

```bash
kind load docker-image spark-custom:3.5.7 --name spark-cluster
kind load docker-image jupyterhub-spark:latest --name spark-cluster
kind load docker-image jupyter-spark:latest --name spark-cluster
```

### 3. Деплой с Helm

```bash
# Создание namespace
kubectl create namespace spark

# Установка платформы
helm install spark-platform ./charts/spark-platform -n spark

# Проверка статуса
kubectl get pods -n spark -w
```

### 4. Проверка работоспособности

```bash
# Ожидание готовности всех подов
kubectl wait --for=condition=ready pod -l app=spark-connect -n spark --timeout=120s
kubectl wait --for=condition=ready pod -l app=jupyter -n spark --timeout=120s
kubectl wait --for=condition=ready pod -l app=minio -n spark --timeout=120s
```

### 5. Доступ к сервисам

| Сервис | URL / Команда |
|--------|---------------|
| **JupyterHub** | http://localhost:30888 (admin / admin123) |
| **Spark UI** | `kubectl port-forward svc/spark-connect 4040:4040 -n spark` |
| **History Server** | `kubectl port-forward svc/spark-history-server 18080:18080 -n spark` |
| **MinIO Console** | `kubectl port-forward svc/minio 9001:9001 -n spark` |

---

## Конфигурация

### Основной файл: `charts/spark-platform/values.yaml`

#### S3 настройки

```yaml
s3:
  endpoint: "http://minio:9000"      # Endpoint MinIO
  accessKey: "minioadmin"            # Access Key
  secretKey: "minioadmin"            # Secret Key
  pathStyleAccess: true              # Path-style доступ (для MinIO)
  sslEnabled: false                  # SSL отключен для MinIO
```

#### Spark Connect Server

```yaml
sparkConnect:
  enabled: true

  image:
    repository: spark-custom
    tag: "3.5.7"
    pullPolicy: IfNotPresent

  # Ресурсы драйвера
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "8Gi"
      cpu: "4000m"

  driver:
    memory: "2g"                     # Память JVM драйвера

  # Режим работы: "local" или "k8s"
  # local: вся обработка в поде драйвера (без масштабирования)
  # k8s: динамические executor поды (рекомендуется)
  master: "k8s"

  # Конфигурация executor'ов (только для master: k8s)
  executor:
    memory: "1g"                     # Память каждого executor'а
    cores: 1                         # CPU cores на executor

  # Dynamic Allocation
  dynamicAllocation:
    enabled: true
    minExecutors: 0                  # Минимум executor'ов
    maxExecutors: 5                  # Максимум executor'ов
    initialExecutors: 0              # Начальное количество

  # Дополнительные Spark конфиги
  sparkConf: {}
```

#### JupyterHub (многопользовательский)

```yaml
jupyterhub:
  enabled: true                      # Включен по умолчанию

  image:
    repository: jupyterhub-spark
    tag: "latest"

  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

  service:
    type: NodePort
    nodePort: 30888                  # Порт для доступа

  adminPassword: "admin123"          # Пароль администратора

  # Настройки пользовательских ноутбуков
  singleuser:
    image:
      repository: jupyter-spark
      tag: "latest"
    cpu:
      limit: "2"
      guarantee: "0.5"
    memory:
      limit: "4G"
      guarantee: "1G"
    # Persistent storage для пользователей (опционально)
    storage:
      enabled: false
      size: "5Gi"
```

#### JupyterLab (одиночный)

```yaml
jupyter:
  enabled: false                     # Отключен в пользу JupyterHub

  image:
    repository: jupyter-spark
    tag: "latest"
    pullPolicy: IfNotPresent

  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

  service:
    type: NodePort
    nodePort: 30888
```

#### MinIO

```yaml
minio:
  enabled: true

  image:
    repository: quay.io/minio/minio
    tag: "latest"

  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "1Gi"
      cpu: "500m"

  persistence:
    enabled: true
    size: 10Gi                       # Размер PVC
    storageClass: ""                 # StorageClass (пустой = default)

  # Автоматически создаваемые бакеты
  buckets:
    - warehouse
    - spark-logs
    - spark-jobs
    - raw-data
    - processed-data
    - checkpoints
```

#### History Server

```yaml
historyServer:
  enabled: true

  image:
    repository: spark-custom
    tag: "3.5.7"

  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

  logDirectory: "s3a://spark-logs/events"  # Путь к event logs
```

### Переопределение значений при деплое

```bash
# Через --set
helm install spark-platform ./charts/spark-platform -n spark \
  --set sparkConnect.executor.memory=2g \
  --set sparkConnect.dynamicAllocation.maxExecutors=10

# Через файл
helm install spark-platform ./charts/spark-platform -n spark \
  -f my-values.yaml
```

---

## Использование

### Работа с JupyterHub

#### 1. Вход в систему

Откройте http://localhost:30888:
- **Администратор:** admin / admin123
- **Новый пользователь:** нажмите "Sign up" для регистрации

#### 2. Запуск ноутбука

После входа:
1. Выберите профиль ресурсов (Small / Medium / Large)
2. Нажмите "Start My Server"
3. Дождитесь создания pod'а (1-2 минуты)

#### 3. Мониторинг пользовательских подов

```bash
# Список пользовательских ноутбуков
kubectl get pods -n spark -l app=jupyterhub,component=singleuser-server

# Логи конкретного пользователя
kubectl logs jupyter-alice-- -n spark
```

#### 4. Администрирование

Доступ к админ-панели: http://localhost:30888/hub/admin
- Просмотр активных пользователей
- Остановка/запуск ноутбуков
- Управление пользователями

### Подключение из JupyterLab

После запуска ноутбука через JupyterHub создайте новый Python 3 notebook:

```python
from pyspark.sql import SparkSession

# Создание сессии через Spark Connect
spark = SparkSession.builder \
    .appName("MyApp") \
    .remote("sc://spark-connect:15002") \
    .getOrCreate()

# Проверка подключения
print(f"Spark version: {spark.version}")
```

### Работа с данными

#### Создание DataFrame

```python
# Из Python данных
data = [
    ("Alice", "Engineering", 75000),
    ("Bob", "Engineering", 80000),
    ("Charlie", "Sales", 60000),
    ("Diana", "Marketing", 65000)
]
df = spark.createDataFrame(data, ["name", "department", "salary"])
df.show()
```

#### Запись в S3 (MinIO)

```python
# Parquet формат (рекомендуется)
df.write.mode("overwrite").parquet("s3a://warehouse/employees")

# Партиционирование по колонке
df.write \
    .mode("overwrite") \
    .partitionBy("department") \
    .parquet("s3a://warehouse/employees_partitioned")

# CSV формат
df.write \
    .mode("overwrite") \
    .option("header", True) \
    .csv("s3a://warehouse/employees_csv")

# JSON формат
df.write \
    .mode("overwrite") \
    .json("s3a://warehouse/employees_json")
```

#### Чтение из S3

```python
# Parquet
df_parquet = spark.read.parquet("s3a://warehouse/employees")

# CSV
df_csv = spark.read \
    .option("header", True) \
    .option("inferSchema", True) \
    .csv("s3a://warehouse/employees_csv")

# JSON
df_json = spark.read.json("s3a://warehouse/employees_json")
```

### SQL запросы

```python
# Регистрация временной таблицы
df.createOrReplaceTempView("employees")

# SQL запрос
result = spark.sql("""
    SELECT department,
           COUNT(*) as count,
           AVG(salary) as avg_salary,
           MAX(salary) as max_salary
    FROM employees
    GROUP BY department
    ORDER BY avg_salary DESC
""")
result.show()
```

### Работа с большими данными

```python
# Пример: обработка большого датасета
df_large = spark.read.parquet("s3a://raw-data/nyc-taxi/")

# Агрегация (запустит executor'ы)
result = df_large \
    .groupBy("passenger_count") \
    .agg(
        {"trip_distance": "avg", "total_amount": "sum"}
    ) \
    .orderBy("passenger_count")

# Запись результата
result.write \
    .mode("overwrite") \
    .parquet("s3a://processed-data/taxi-summary")
```

### Pandas API on Spark

```python
import pyspark.pandas as ps

# Создание pandas-on-spark DataFrame
psdf = ps.DataFrame({
    'a': [1, 2, 3, 4, 5],
    'b': [10, 20, 30, 40, 50]
})

# Использование pandas-подобного API
psdf['c'] = psdf['a'] + psdf['b']
print(psdf.describe())

# Конвертация в Spark DataFrame
spark_df = psdf.to_spark()
```

### Завершение сессии

```python
# Важно: закрывайте сессию после работы
spark.stop()
```

---

## Мониторинг

### Просмотр executor подов

```bash
# Наблюдение за созданием/удалением executor'ов в реальном времени
kubectl get pods -n spark -w | grep spark-exec

# Список всех подов
kubectl get pods -n spark

# Детали executor пода
kubectl describe pod spark-exec-1-exec-1 -n spark
```

### Логи

```bash
# Логи Spark Connect (драйвер)
kubectl logs -f deployment/spark-connect -n spark

# Логи конкретного executor'а
kubectl logs spark-exec-1-exec-1 -n spark

# Логи Jupyter
kubectl logs -f deployment/jupyter -n spark

# Логи MinIO
kubectl logs -f deployment/minio -n spark

# Логи History Server
kubectl logs -f deployment/spark-history-server -n spark
```

### Spark UI (порт 4040)

```bash
kubectl port-forward svc/spark-connect 4040:4040 -n spark
```

Откройте http://localhost:4040 для просмотра:
- **Jobs** - выполняющиеся и завершенные задачи
- **Stages** - стадии выполнения
- **Storage** - кешированные RDD/DataFrame
- **Environment** - конфигурация Spark
- **Executors** - информация об executor'ах

### History Server (порт 18080)

```bash
kubectl port-forward svc/spark-history-server 18080:18080 -n spark
```

Откройте http://localhost:18080 для просмотра истории завершенных приложений.

### MinIO Console (порт 9001)

```bash
kubectl port-forward svc/minio 9001:9001 -n spark
```

Откройте http://localhost:9001 (логин: minioadmin / minioadmin):
- Просмотр бакетов и файлов
- Управление доступом
- Мониторинг использования

---

## Troubleshooting

### Executor поды не создаются

**Симптомы:** Задачи зависают, executor поды не появляются.

**Проверка:**
```bash
# Проверка RBAC
kubectl auth can-i create pods --as=system:serviceaccount:spark:spark -n spark

# Логи драйвера
kubectl logs deployment/spark-connect -n spark | grep -i "executor\|error"
```

**Решения:**
1. Проверьте, что RBAC создан: `kubectl get rolebinding -n spark`
2. Проверьте конфигурацию: `master: "k8s"` в values.yaml
3. Проверьте ресурсы кластера: `kubectl describe nodes`

### Java 17 ошибки в executor'ах

**Симптомы:** `IllegalAccessError: cannot access class sun.nio.ch.DirectBuffer`

**Проверка:**
```bash
kubectl logs <executor-pod> -n spark | head -50
```

**Решение:** Убедитесь, что используется образ с `spark-env.sh`:
```bash
docker build -t spark-custom:3.5.7 docker/spark/
```

Файл `docker/spark/conf/spark-env.sh` содержит необходимые `--add-opens` флаги.

### S3 ошибки подключения

**Симптомы:** `Unable to find valid certification path`, `Connection refused`

**Проверка:**
```bash
# Проверка MinIO
kubectl get pods -n spark -l app=minio
kubectl logs deployment/minio -n spark

# Тест подключения из пода
kubectl exec -it deployment/jupyter -n spark -- curl http://minio:9000/minio/health/live
```

**Решения:**
1. Проверьте endpoint: `s3.endpoint: "http://minio:9000"` (не https!)
2. Проверьте бакеты созданы: `kubectl logs job/minio-setup -n spark`
3. Перезапустите MinIO: `kubectl rollout restart deployment/minio -n spark`

### History Server не показывает задачи

**Симптомы:** Пустой список приложений в History Server.

**Проверка:**
```bash
# Проверка event logs в MinIO
kubectl exec -it deployment/minio -n spark -- mc ls local/spark-logs/events/
```

**Решения:**
1. Убедитесь, что `spark.eventLog.enabled=true` в configmap
2. Проверьте права доступа к бакету `spark-logs`
3. Перезапустите History Server: `kubectl rollout restart deployment/spark-history-server -n spark`

### Pods в состоянии Pending

**Проверка:**
```bash
kubectl describe pod <pod-name> -n spark
```

**Частые причины:**
- `Insufficient cpu/memory` - недостаточно ресурсов на нодах
- `no PersistentVolumes available` - нет доступных PV для PVC
- `ImagePullBackOff` - образ не найден

### Перезапуск компонентов

```bash
# Перезапуск отдельного компонента
kubectl rollout restart deployment/spark-connect -n spark
kubectl rollout restart deployment/jupyter -n spark
kubectl rollout restart deployment/minio -n spark

# Полный редеплой
helm uninstall spark-platform -n spark
helm install spark-platform ./charts/spark-platform -n spark
```

---

## Структура проекта

```
spark_k8s/
├── charts/
│   └── spark-platform/              # Helm chart
│       ├── Chart.yaml               # Метаданные чарта
│       ├── values.yaml              # Значения по умолчанию
│       └── templates/
│           ├── spark-connect.yaml   # Deployment + Service Spark Connect
│           ├── jupyterhub.yaml      # Deployment + Service JupyterHub
│           ├── jupyter.yaml         # Deployment + Service JupyterLab (одиночный)
│           ├── minio.yaml           # Deployment + Service + PVC MinIO
│           ├── history-server.yaml  # Deployment + Service History Server
│           ├── hive-metastore.yaml  # Deployment + Service Hive Metastore
│           ├── postgresql.yaml      # Deployment + Service PostgreSQL
│           ├── configmap.yaml       # ConfigMap со Spark конфигами
│           ├── secrets.yaml         # Secret с S3 credentials
│           ├── rbac.yaml            # ServiceAccount + Role + RoleBinding
│           └── NOTES.txt            # Инструкции после установки
│
├── docker/
│   ├── spark/                       # Spark образ
│   │   ├── Dockerfile               # Multi-stage сборка
│   │   ├── entrypoint.sh            # Точка входа (connect/history/executor/metastore)
│   │   └── conf/
│   │       ├── spark-defaults.conf  # Дефолтная конфигурация
│   │       ├── spark-env.sh         # Java 17 --add-opens флаги
│   │       └── log4j2.properties    # Настройки логирования
│   │
│   ├── jupyterhub/                  # JupyterHub образ (многопользовательский)
│   │   ├── Dockerfile
│   │   └── jupyterhub_config.py     # Конфигурация KubeSpawner
│   │
│   └── jupyter/                     # JupyterLab образ (single-user)
│       ├── Dockerfile
│       ├── spark_config.py          # Утилиты Spark Connect
│       └── notebooks/               # Примеры ноутбуков
│
├── k8s/                             # Raw K8s манифесты (опционально)
│   ├── base/                        # Базовые ресурсы
│   │   ├── namespace.yaml
│   │   ├── rbac.yaml
│   │   ├── configmap.yaml
│   │   └── secrets.yaml
│   ├── spark-connect/               # Spark Connect
│   ├── minio/                       # MinIO
│   ├── jupyterhub/                  # Jupyter
│   ├── spark-history-server/        # History Server
│   └── optional/                    # Дополнительные компоненты
│       ├── kafka/
│       └── mlflow/
│
└── README.md                        # Эта документация
```

---

## Версии компонентов

| Компонент | Версия | Примечание |
|-----------|--------|------------|
| Apache Spark | 3.5.7 | С поддержкой Spark Connect |
| Java | 17 | OpenJDK, с настроенными --add-opens |
| Python | 3.11 | В Spark и Jupyter образах |
| Scala | 2.12 | Версия Spark |
| Hadoop | 3.4.1 | С поддержкой AWS SDK v2 |
| AWS SDK | v2 (2.25.11) | Для S3A FileSystem |
| PySpark | 3.5.7 | С модулем connect |

### JDBC драйверы (включены в образ)

| База данных | Версия драйвера |
|-------------|-----------------|
| PostgreSQL | 42.7.3 |
| Oracle | 23.6.0.24.10 |
| Vertica | 24.4.0-0 |

---

## Лицензия

MIT License
