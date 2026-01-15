# DataOps Platform: JupyterHub + Spark 3.5.7

Локальная сборка и тестирование JupyterHub со Spark 3.5.7 (Hadoop 3.4) в Kubernetes кластере (kubeadm single-node).

## Быстрый старт

### 1. Сборка образа

```bash
cd spark_k8s
./scripts/build-and-load-image.sh
```

Или вручную:
```bash
docker build -t jupyterhub-spark:latest -f jupyterhub/Dockerfile jupyterhub/
```

### 2. Загрузка образа в кластер

Скрипт автоматически определит runtime (containerd/CRI-O/Docker) и загрузит образ.

Или вручную (для containerd):
```bash
docker save jupyterhub-spark:latest -o jupyterhub-spark.tar
sudo ctr -n k8s.io images import jupyterhub-spark.tar
```

### 3. Развертывание

```bash
kubectl apply -f local-k8s/
```

### 4. Проверка статуса

```bash
kubectl get pods -n dataops
kubectl get svc -n dataops
```

### 5. Доступ к JupyterHub

```bash
kubectl port-forward svc/jupyterhub 8000:8000 -n dataops
```

Откройте в браузере: http://localhost:8000

**JupyterLab откроется автоматически!** Все объекты (spark, pd, mlflow, s3_client) уже готовы.

## Структура проекта

```
spark_k8s/
├── jupyterhub/              # JupyterHub образ
│   ├── Dockerfile           # Образ со Spark 3.5.7, Hadoop 3.4, DS-стеком
│   ├── jupyterhub_config.py # Конфигурация JupyterHub (JupyterLab по умолчанию)
│   ├── requirements-jupyter.txt # DS-библиотеки (pandas, plotly, sklearn, etc.)
│   ├── startup/00-spark-init.py # Автоинициализация Spark + pandas-like helpers
│   └── examples/            # Примеры notebooks
│       └── 01-quickstart-example.ipynb
├── local-k8s/               # Kubernetes манифесты
│   ├── namespace.yaml
│   ├── jupyterhub/         # JupyterHub deployment, service, RBAC
│   ├── spark/              # Spark master + worker
│   └── storage/            # MinIO для S3-совместимого хранилища
├── scripts/                 # Утилиты
│   └── build-and-load-image.sh
└── docs/                    # Документация
    └── SETUP_LOCAL_K8S.md   # Подробная инструкция
```

## Компоненты

- **JupyterHub**: Интерактивная среда разработки с предустановленным Spark
- **Spark 3.5.7**: С Hadoop 3.4 и JDBC драйверами (PostgreSQL, Oracle, Vertica, Kafka, AWS)
- **MinIO**: S3-совместимое объектное хранилище для тестирования
- **Spark Standalone**: Master + Worker для выполнения Spark задач

## Особенности

### Для Data Scientists (pandas-like UX)

- **JupyterLab по умолчанию** с расширениями (variable inspector, LSP, plotly widgets)
- **Pandas-like отображение Spark DataFrame**: `display_spark_df()` показывает данные как pandas
- **Безопасная конвертация Spark→pandas**: `to_pandas_safe()` с автоматическим лимитом строк
- **Pandas-like функции**: `head()`, `tail()` для Spark DataFrame
- **Spark pandas API**: `ps` (pyspark.pandas) для работы как с pandas
- **Все готово из коробки**: Spark, S3, MLflow инициализированы автоматически

### Data Science Stack

- **Core**: pandas, polars, numpy, scipy
- **Visualization**: seaborn, matplotlib, plotly (интерактивные графики)
- **ML**: scikit-learn, xgboost, lightgbm, catboost
- **Query**: duckdb
- **Spark 3.5.7** с Hadoop 3.4
- **JDBC драйверы**: PostgreSQL, Oracle, Vertica, Kafka, AWS

### Интеграции

- **S3/MinIO**: Чтение/запись через `read_s3_parquet()`, `write_s3_parquet()`
- **MLflow**: Автоматическая настройка tracking URI
- **JupyterLab extensions**: Variable inspector, LSP, code formatter, git, resource usage

## Быстрый старт для Data Scientists

После входа в JupyterHub (JupyterLab откроется автоматически):

```python
# Все уже готово! Просто используйте:
df = read_s3_parquet(spark, "s3a://data-lake/bronze/events")
display_spark_df(df)  # Показывает как pandas!

# Конвертируем в pandas для визуализации
df_pd = to_pandas_safe(df, max_rows=1000)
df_pd.plot()  # Используйте pandas/plotly/seaborn

# Или используйте Spark pandas API (pyspark.pandas)
# ps уже импортирован при старте!
df_ps = ps.read_parquet("s3a://data-lake/bronze/events")
df_ps.head()  # Работает как pandas, но на Spark!
```

Откройте пример: `examples/01-quickstart-example.ipynb`

## Документация

Подробные инструкции: [docs/SETUP_LOCAL_K8S.md](docs/SETUP_LOCAL_K8S.md)

## Требования

- Docker Engine
- Kubernetes кластер (kubeadm single-node)
- kubectl
- Минимум 4 CPU, 8 GB RAM

## Лицензия

Внутренний проект.

